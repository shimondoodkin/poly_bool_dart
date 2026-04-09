import 'dart:math' as math;

import 'arc_data.dart';
import 'coordinate.dart';
import 'epsilon.dart';
import 'geometry.dart';
import 'types.dart';

/// Point-in-polygon test that handles both line and arc edges.
/// Uses ray-casting (horizontal ray to the right) with even-odd rule.
class PointInPolygon {
  final Epsilon eps;
  final Geometry geo;

  PointInPolygon(this.eps) : geo = Geometry(eps);

  /// Test if a point is inside a polygon defined as a list of ArcVertex.
  bool isInsidePolygon(Coordinate point, List<ArcVertex> vertices) {
    int crossings = 0;
    final n = vertices.length;

    for (int i = 0; i < n; i++) {
      final v1 = vertices[i];
      final v2 = vertices[(i + 1) % n];

      if (v1.arcToNext == null) {
        crossings += _rayLineCrossing(point, v1.point, v2.point);
      } else {
        crossings +=
            _rayArcCrossing(point, v1.point, v2.point, v1.arcToNext!);
      }
    }

    return (crossings % 2) == 1;
  }

  int _rayLineCrossing(Coordinate origin, Coordinate a, Coordinate b) {
    if ((a.y <= origin.y) == (b.y <= origin.y)) return 0;
    final t = (origin.y - a.y) / (b.y - a.y);
    final x = a.x + t * (b.x - a.x);
    return x > origin.x - eps.eps ? 1 : 0;
  }

  /// Count ray crossings with an arc edge by splitting it into y-monotone
  /// sub-arcs and using the line-like half-open interval test on each.
  int _rayArcCrossing(
      Coordinate origin, Coordinate arcStart, Coordinate arcEnd, ArcData arc) {
    // Split the arc at its y-extremes to get y-monotone sub-arcs
    final subArcs = _splitAtYExtremes(arcStart, arcEnd, arc);

    int count = 0;
    for (final sub in subArcs) {
      count += _rayMonotoneArcCrossing(origin, sub.start, sub.end, arc);
    }
    return count;
  }

  /// For a y-monotone arc (y goes strictly from start.y to end.y),
  /// use the same crossing convention as for lines.
  int _rayMonotoneArcCrossing(
      Coordinate origin, Coordinate start, Coordinate end, ArcData arc) {
    // Same half-open interval test as for lines
    if ((start.y <= origin.y) == (end.y <= origin.y)) return 0;

    // The arc crosses y=origin.y somewhere between start and end.
    // Find the x-coordinate of that crossing.
    final c = arc.center;
    final r = arc.radius;
    final dy = origin.y - c.y;

    if (dy.abs() > r + eps.eps) return 0;

    var disc = r * r - dy * dy;
    if (disc < 0) disc = 0;
    final sqrtD = math.sqrt(disc);

    final x1 = c.x + sqrtD;
    final x2 = c.x - sqrtD;

    // Determine which x is the correct one for this sub-arc
    // by checking which is closer to the sub-arc's x-range
    final minX = math.min(start.x, end.x);
    final maxX = math.max(start.x, end.x);

    // Try both and pick the one in range
    for (final x in [x1, x2]) {
      // Allow some tolerance for endpoints
      if (x >= minX - eps.eps * 100 && x <= maxX + eps.eps * 100) {
        // Verify this point is actually on the arc
        final pt = Coordinate(x, origin.y);
        if (geo.pointOnArc(pt, start, end, arc) ||
            eps.pointsSame(pt, start) ||
            eps.pointsSame(pt, end)) {
          return x > origin.x - eps.eps ? 1 : 0;
        }
      }
    }

    // If neither x is in the sub-arc's range, try both and pick the closer one
    // This handles cases where the arc bulges
    for (final x in [x1, x2]) {
      if (x >= origin.x - eps.eps) {
        final pt = Coordinate(x, origin.y);
        if (geo.pointOnArc(pt, start, end, arc)) {
          return 1;
        }
      }
    }

    return 0;
  }

  /// Split an arc at its y-extreme points into y-monotone sub-arcs.
  /// Returns list of (start, end) coordinate pairs.
  List<_SubArc> _splitAtYExtremes(
      Coordinate arcStart, Coordinate arcEnd, ArcData arc) {
    final c = arc.center;
    final r = arc.radius;

    // Y-extremes of a circle occur at angles pi/2 (top) and -pi/2 (bottom)
    final topPt = Coordinate(c.x, c.y + r);
    final bottomPt = Coordinate(c.x, c.y - r);

    final startAngle = geo.angleOf(c, arcStart);
    final endAngle = geo.angleOf(c, arcEnd);

    final splitPoints = <Coordinate>[];

    for (final ext in [topPt, bottomPt]) {
      final extAngle = geo.angleOf(c, ext);
      if (geo.angleInArcRange(extAngle, startAngle, endAngle, arc.clockwise)) {
        if (!eps.pointsSame(ext, arcStart) && !eps.pointsSame(ext, arcEnd)) {
          splitPoints.add(ext);
        }
      }
    }

    // Sort split points by angular distance from start
    splitPoints.sort((a, b) {
      final aa = geo.angleOf(c, a);
      final ab = geo.angleOf(c, b);
      double distA, distB;
      if (arc.clockwise) {
        distA = startAngle - aa;
        if (distA < 0) distA += 2 * math.pi;
        distB = startAngle - ab;
        if (distB < 0) distB += 2 * math.pi;
      } else {
        distA = aa - startAngle;
        if (distA < 0) distA += 2 * math.pi;
        distB = ab - startAngle;
        if (distB < 0) distB += 2 * math.pi;
      }
      return distA.compareTo(distB);
    });

    final allPoints = [arcStart, ...splitPoints, arcEnd];
    final subArcs = <_SubArc>[];
    for (int i = 0; i < allPoints.length - 1; i++) {
      subArcs.add(_SubArc(allPoints[i], allPoints[i + 1]));
    }
    return subArcs;
  }
}

class _SubArc {
  final Coordinate start;
  final Coordinate end;
  _SubArc(this.start, this.end);
}
