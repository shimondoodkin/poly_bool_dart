import 'dart:math' as math;

import 'arc_data.dart';
import 'coordinate.dart';
import 'epsilon.dart';

/// Core geometry functions for arc and line intersection computations.
class Geometry {
  final Epsilon eps;

  const Geometry(this.eps);

  // ---- Angle utilities ----

  /// Angle from center to point, in [-pi, pi].
  double angleOf(Coordinate center, Coordinate point) {
    return math.atan2(point.y - center.y, point.x - center.x);
  }

  /// Normalize angle to [-pi, pi].
  double normalizeAngle(double a) {
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a <= -math.pi) {
      a += 2 * math.pi;
    }
    return a;
  }

  /// Is [angle] within the angular range of an arc from [startAngle] to
  /// [endAngle] going in [clockwise] direction?
  bool angleInArcRange(
      double angle, double startAngle, double endAngle, bool clockwise) {
    // Normalize all angles
    angle = normalizeAngle(angle);
    startAngle = normalizeAngle(startAngle);
    endAngle = normalizeAngle(endAngle);

    if (clockwise) {
      // Clockwise: angles decrease from start to end
      // (in standard math coords where y-up, clockwise means decreasing angle)
      if (startAngle >= endAngle) {
        // Simple case: no wrap-around
        return angle <= startAngle + eps.eps && angle >= endAngle - eps.eps;
      } else {
        // Wrap-around: goes from start, decreasing, past -pi, to end
        return angle <= startAngle + eps.eps || angle >= endAngle - eps.eps;
      }
    } else {
      // Counter-clockwise: angles increase from start to end
      if (endAngle >= startAngle) {
        return angle >= startAngle - eps.eps && angle <= endAngle + eps.eps;
      } else {
        return angle >= startAngle - eps.eps || angle <= endAngle + eps.eps;
      }
    }
  }

  /// Check if a point lies on an arc segment (within epsilon).
  bool pointOnArc(Coordinate point, Coordinate arcStart, Coordinate arcEnd,
      ArcData arc) {
    // Check distance from center equals radius
    final dx = point.x - arc.center.x;
    final dy = point.y - arc.center.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if ((dist - arc.radius).abs() > eps.eps * 10) return false;

    // Check angular range
    final startAngle = angleOf(arc.center, arcStart);
    final endAngle = angleOf(arc.center, arcEnd);
    final pointAngle = angleOf(arc.center, point);

    return angleInArcRange(pointAngle, startAngle, endAngle, arc.clockwise);
  }

  // ---- Intersection functions ----

  /// Circle-line intersection. Returns 0, 1, or 2 intersection points.
  /// The circle is defined by [center] and [radius].
  /// The line segment goes from [lineA] to [lineB].
  /// If [segmentOnly] is true, filter to points on the segment.
  List<Coordinate> circleLineIntersection(
    Coordinate center,
    double radius,
    Coordinate lineA,
    Coordinate lineB, {
    bool segmentOnly = true,
  }) {
    final dx = lineB.x - lineA.x;
    final dy = lineB.y - lineA.y;
    final fx = lineA.x - center.x;
    final fy = lineA.y - center.y;

    final a = dx * dx + dy * dy;
    if (a < eps.eps * eps.eps) return []; // degenerate line

    final b = 2 * (fx * dx + fy * dy);
    final c = fx * fx + fy * fy - radius * radius;

    var discriminant = b * b - 4 * a * c;
    if (discriminant < -eps.eps) return [];

    if (discriminant < 0) discriminant = 0;

    final results = <Coordinate>[];
    final sqrtD = math.sqrt(discriminant);

    for (final sign in [-1.0, 1.0]) {
      final t = (-b + sign * sqrtD) / (2 * a);
      if (!segmentOnly || (t >= -eps.eps && t <= 1.0 + eps.eps)) {
        final pt = Coordinate(lineA.x + t * dx, lineA.y + t * dy);
        // Avoid duplicates for tangent case
        if (results.isEmpty || !eps.pointsSame(results.last, pt)) {
          results.add(pt);
        }
      }
    }

    return results;
  }

  /// Circle-circle intersection. Returns 0, 1, or 2 intersection points.
  List<Coordinate> circleCircleIntersection(
    Coordinate c1,
    double r1,
    Coordinate c2,
    double r2,
  ) {
    final dx = c2.x - c1.x;
    final dy = c2.y - c1.y;
    final d = math.sqrt(dx * dx + dy * dy);

    // Too far apart or one inside the other
    if (d > r1 + r2 + eps.eps) return [];
    if (d < (r1 - r2).abs() - eps.eps) return [];
    if (d < eps.eps) return []; // concentric

    final a = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
    var h2 = r1 * r1 - a * a;
    if (h2 < 0) h2 = 0;
    final h = math.sqrt(h2);

    final px = c1.x + a * dx / d;
    final py = c1.y + a * dy / d;

    if (h < eps.eps) {
      // Tangent — one intersection point
      return [Coordinate(px, py)];
    }

    return [
      Coordinate(px + h * dy / d, py - h * dx / d),
      Coordinate(px - h * dy / d, py + h * dx / d),
    ];
  }

  /// Filter intersection points to those within an arc's angular range.
  List<Coordinate> filterToArcRange(
    List<Coordinate> points,
    ArcData arc,
    Coordinate arcStart,
    Coordinate arcEnd,
  ) {
    if (points.isEmpty) return points;

    final startAngle = angleOf(arc.center, arcStart);
    final endAngle = angleOf(arc.center, arcEnd);

    return points.where((pt) {
      final ptAngle = angleOf(arc.center, pt);
      return angleInArcRange(ptAngle, startAngle, endAngle, arc.clockwise);
    }).toList();
  }

  /// Find intersection points between a line segment and an arc segment.
  /// Returns points that lie on both the line segment and the arc.
  List<Coordinate> lineArcIntersection(
    Coordinate lineStart,
    Coordinate lineEnd,
    Coordinate arcStart,
    Coordinate arcEnd,
    ArcData arc,
  ) {
    // Find circle-line intersections
    var points = circleLineIntersection(
      arc.center,
      arc.radius,
      lineStart,
      lineEnd,
      segmentOnly: true,
    );

    // Filter to points within the arc's angular range
    points = filterToArcRange(points, arc, arcStart, arcEnd);

    return points;
  }

  /// Find intersection points between two arc segments.
  List<Coordinate> arcArcIntersection(
    Coordinate arc1Start,
    Coordinate arc1End,
    ArcData arc1,
    Coordinate arc2Start,
    Coordinate arc2End,
    ArcData arc2,
  ) {
    var points = circleCircleIntersection(
      arc1.center,
      arc1.radius,
      arc2.center,
      arc2.radius,
    );

    // Filter by both arcs' angular ranges
    points = filterToArcRange(points, arc1, arc1Start, arc1End);
    points = filterToArcRange(points, arc2, arc2Start, arc2End);

    return points;
  }

  /// Count ray-arc intersections for point-in-polygon testing.
  /// Ray goes from [origin] in the +x direction.
  /// Returns the number of crossings (for winding number computation).
  int rayArcIntersections(
    Coordinate origin,
    Coordinate arcStart,
    Coordinate arcEnd,
    ArcData arc,
  ) {
    // Intersect horizontal ray (y = origin.y, x >= origin.x) with the arc's circle
    final dy = origin.y - arc.center.y;
    if (dy.abs() > arc.radius + eps.eps) return 0;

    var discr = arc.radius * arc.radius - dy * dy;
    if (discr < 0) discr = 0;
    final sqrtD = math.sqrt(discr);

    final x1 = arc.center.x + sqrtD;
    final x2 = arc.center.x - sqrtD;

    int count = 0;
    final startAngle = angleOf(arc.center, arcStart);
    final endAngle = angleOf(arc.center, arcEnd);

    for (final x in [x1, x2]) {
      if (x < origin.x - eps.eps) continue; // behind ray

      final pt = Coordinate(x, origin.y);
      final ptAngle = angleOf(arc.center, pt);

      if (angleInArcRange(ptAngle, startAngle, endAngle, arc.clockwise)) {
        // Determine crossing direction: is the arc going up or down at this point?
        // For winding number, we need to know if crossing is upward or downward.
        count++;
      }
    }

    return count;
  }

  /// Compute a sub-arc's ArcData when splitting an arc at a point.
  /// The sub-arc inherits center, radius, and clockwise from the parent arc.
  ArcData subArc(ArcData parentArc) {
    return ArcData(
      center: parentArc.center,
      radius: parentArc.radius,
      clockwise: parentArc.clockwise,
    );
  }
}
