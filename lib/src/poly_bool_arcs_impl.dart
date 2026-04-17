import 'dart:math' as math;

import 'coordinate.dart';
import 'epsilon.dart';
import 'geometry.dart';
import 'intersecter.dart';
import 'point_in_polygon.dart';
import 'segment_chainer.dart';
import 'segment_fill.dart';
import 'segment_selector.dart';
import 'types.dart';

typedef _Selector = SegmentList Function(CombinedSegmentLists);

/// Main API for polygon boolean operations with arc support.
class PolyBoolArcs {
  static Epsilon _eps = const Epsilon();

  /// Set the epsilon tolerance for all operations.
  static void setEpsilon(double eps) {
    _eps = Epsilon(eps: eps);
  }

  /// Get the current epsilon.
  static Epsilon get epsilon => _eps;

  static ArcPolygon union(ArcPolygon a, ArcPolygon b) =>
      _operate(a, b, _selectUnion);

  static ArcPolygon intersect(ArcPolygon a, ArcPolygon b) =>
      _operate(a, b, _selectIntersect);

  static ArcPolygon difference(ArcPolygon a, ArcPolygon b) =>
      _operate(a, b, _selectDifference);

  static ArcPolygon xor(ArcPolygon a, ArcPolygon b) =>
      _operate(a, b, _selectXor);

  static ArcPolygon _operate(
      ArcPolygon poly1, ArcPolygon poly2, _Selector selector) {
    final seg1 = _segments(poly1);
    final seg2 = _segments(poly2);
    final combined = _combine(seg1, seg2);

    // Correct fills for arc segments that may have incorrect sweep-line fills
    _correctArcFills(combined.combined, seg1, seg2, poly1, poly2);

    final selected = selector(combined);
    final regions = SegmentChainer(_eps).chain(selected);
    return ArcPolygon(regions: regions, inverted: selected.inverted);
  }

  static SegmentList _segments(ArcPolygon poly) {
    final i = Intersecter(true, _eps);

    for (final region in poly.regions) {
      final hasArcs = region.vertices.any((v) => v.arcToNext != null);

      if (hasArcs) {
        i.addArcRegion(region.vertices);
      } else {
        i.addRegion(region.vertices.map((v) => v.point).toList());
      }
    }

    var result = i.calculate(inverted: poly.inverted);
    result.inverted = poly.inverted;
    return result;
  }

  static CombinedSegmentLists _combine(
      SegmentList segments1, SegmentList segments2) {
    final i = Intersecter(false, _eps);
    return CombinedSegmentLists(
      combined: i.calculateCombined(
          segments1, segments1.inverted, segments2, segments2.inverted),
      inverted1: segments1.inverted,
      inverted2: segments2.inverted,
    );
  }

  /// Correct fills for all segments by sampling points on either side and
  /// testing containment in the original polygons.
  static void _correctArcFills(
    SegmentList combined,
    SegmentList seg1,
    SegmentList seg2,
    ArcPolygon poly1,
    ArcPolygon poly2,
  ) {
    final geo = Geometry(_eps);
    final offset = 1e-6;

    for (final seg in combined.segments) {
      if (seg.otherFill == null) continue;

      final midPoint = _segmentMidpoint(seg, geo);

      // Sample two points on opposite sides of the segment
      // Use a perpendicular offset from the midpoint
      final perp = _perpendicular(seg, midPoint, geo);

      final side1 = Coordinate(
          midPoint.x + perp.x * offset, midPoint.y + perp.y * offset);
      final side2 = Coordinate(
          midPoint.x - perp.x * offset, midPoint.y - perp.y * offset);

      final side1InPoly1 = _isInsideOriginalPolygon(side1, poly1);
      final side2InPoly1 = _isInsideOriginalPolygon(side2, poly1);
      final side1InPoly2 = _isInsideOriginalPolygon(side1, poly2);
      final side2InPoly2 = _isInsideOriginalPolygon(side2, poly2);

      // Determine which side is "above" in the sweep sense.
      // In the sweep, "above" = to the left of direction of travel (start→end).
      // The perpendicular we computed points to the left = "above" side = side1.
      seg.myFill = SegmentFill(above: side1InPoly1, below: side2InPoly1);
      seg.otherFill = SegmentFill(above: side1InPoly2, below: side2InPoly2);
    }
  }

  static Coordinate _segmentMidpoint(Segment seg, Geometry geo) {
    if (seg.isArc) {
      final arc = seg.arc!;
      final startAngle = geo.angleOf(arc.center, seg.start);
      final endAngle = geo.angleOf(arc.center, seg.end);

      double midAngle;
      // y-down: clockwise=true means atan2 angle increases
      if (arc.clockwise) {
        var diff = endAngle - startAngle;
        if (diff < 0) diff += 2 * math.pi;
        midAngle = startAngle + diff / 2;
      } else {
        var diff = startAngle - endAngle;
        if (diff < 0) diff += 2 * math.pi;
        midAngle = startAngle - diff / 2;
      }

      return Coordinate(
        arc.center.x + arc.radius * math.cos(midAngle),
        arc.center.y + arc.radius * math.sin(midAngle),
      );
    } else {
      return Coordinate(
        (seg.start.x + seg.end.x) / 2,
        (seg.start.y + seg.end.y) / 2,
      );
    }
  }

  /// Compute the "above" normal for sweep-line purposes.
  /// In the sweep-line, segments go from left (lower x) to right (higher x).
  /// "above" means the left side of the directed segment (higher y for
  /// left-to-right horizontal segments).
  static Coordinate _perpendicular(
      Segment seg, Coordinate atPoint, Geometry geo) {
    if (seg.isLine) {
      final dx = seg.end.x - seg.start.x;
      final dy = seg.end.y - seg.start.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1e-15) return Coordinate(0, 1);
      // Left normal of direction (dx, dy) is (-dy, dx)
      return Coordinate(-dy / len, dx / len);
    } else {
      // For arc: the tangent at the point, then take left normal
      final arc = seg.arc!;
      final dx = atPoint.x - arc.center.x;
      final dy = atPoint.y - arc.center.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1e-15) return Coordinate(0, 1);

      // Tangent direction on the arc at this point.
      // y-down: clockwise=true means atan2 angle increases, so the tangent
      // is the derivative of (cos a, sin a), i.e. (-sin a, cos a) = (-dy, dx)/r.
      // clockwise=false (y-down CCW, angle decreasing): tangent is (dy, -dx)/r.
      double tx, ty;
      if (arc.clockwise) {
        tx = -dy / len;
        ty = dx / len;
      } else {
        tx = dy / len;
        ty = -dx / len;
      }

      // But segments are stored with start.x <= end.x. If the tangent points
      // in the -x direction, we need to flip it.
      // The segment goes from start to end (left to right in x).
      // Check if the tangent aligns with the segment direction.
      final segDx = seg.end.x - seg.start.x;
      if (segDx * tx < 0) {
        // Tangent points opposite to segment direction — flip
        tx = -tx;
        ty = -ty;
      }

      // Left normal of tangent (tx, ty) is (-ty, tx)
      final tLen = math.sqrt(tx * tx + ty * ty);
      return Coordinate(-ty / tLen, tx / tLen);
    }
  }

  static bool _isInsideOriginalPolygon(Coordinate point, ArcPolygon poly) {
    final pip = PointInPolygon(_eps);
    bool inside = poly.inverted;

    for (final region in poly.regions) {
      if (pip.isInsidePolygon(point, region.vertices)) {
        inside = !inside;
      }
    }

    return inside;
  }

  static SegmentList _selectUnion(CombinedSegmentLists combined) {
    var result = SegmentSelector.union(combined.combined);
    result.inverted = combined.inverted1 || combined.inverted2;
    return result;
  }

  static SegmentList _selectIntersect(CombinedSegmentLists combined) {
    var result = SegmentSelector.intersect(combined.combined);
    result.inverted = combined.inverted1 && combined.inverted2;
    return result;
  }

  static SegmentList _selectDifference(CombinedSegmentLists combined) {
    var result = SegmentSelector.difference(combined.combined);
    result.inverted = combined.inverted1 && !combined.inverted2;
    return result;
  }

  static SegmentList _selectXor(CombinedSegmentLists combined) {
    var result = SegmentSelector.xor(combined.combined);
    result.inverted = combined.inverted1 != combined.inverted2;
    return result;
  }
}
