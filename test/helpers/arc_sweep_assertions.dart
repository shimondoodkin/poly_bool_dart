/// Test helpers for asserting that every arc in a result polygon stays
/// within its input arc's defined sweep range.
///
/// Usage:
///   expectArcSweepWithinInputs(
///     result: PolyBoolArcs.union(a, b),
///     inputCircles: [
///       (center: Coordinate(100, 50), radius: 50,
///        sweeps: [(startAngle: -pi/2, endAngle: pi/2, clockwise: true)]),
///     ],
///     tolerance: 0.01,
///   );
import 'dart:math' as math;

import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

/// Description of a valid sweep window on a specific circle.
class SweepWindow {
  /// Start angle in radians (atan2 convention).
  final double startAngle;

  /// End angle in radians (atan2 convention).
  final double endAngle;

  /// Direction of travel from startAngle to endAngle.
  final bool clockwise;

  const SweepWindow({
    required this.startAngle,
    required this.endAngle,
    required this.clockwise,
  });
}

/// Description of an input circle plus all sweep windows that were part
/// of some input polygon's boundary on that circle.
class InputCircle {
  final Coordinate center;
  final double radius;
  final List<SweepWindow> sweeps;
  const InputCircle({
    required this.center,
    required this.radius,
    required this.sweeps,
  });
}

/// Assert that every arc in [result] is anchored on one of [inputCircles]
/// and has both endpoints within at least one of that circle's sweep
/// windows.
void expectArcSweepWithinInputs({
  required ArcPolygon result,
  required List<InputCircle> inputCircles,
  double tolerance = 0.01,
}) {
  for (int ri = 0; ri < result.regions.length; ri++) {
    final region = result.regions[ri];
    for (int i = 0; i < region.vertices.length; i++) {
      final v = region.vertices[i];
      final arc = v.arcToNext;
      if (arc == null) continue;
      final next = region.vertices[(i + 1) % region.vertices.length];

      final circle = _findMatchingCircle(arc, inputCircles, tolerance);
      expect(circle, isNotNull,
          reason: 'region $ri edge $i: arc on circle '
              'center=(${arc.center.x}, ${arc.center.y}) r=${arc.radius} '
              'does not match any input circle');

      // Endpoints must be on the circle.
      final distA = _distance(v.point, arc.center);
      final distB = _distance(next.point, arc.center);
      expect(distA, closeTo(arc.radius, tolerance),
          reason: 'region $ri edge $i: arc start '
              '(${v.point.x}, ${v.point.y}) not on circle');
      expect(distB, closeTo(arc.radius, tolerance),
          reason: 'region $ri edge $i: arc end '
              '(${next.point.x}, ${next.point.y}) not on circle');

      // Both endpoints must lie within at least one sweep window on
      // this circle.
      final aAngle = math.atan2(v.point.y - arc.center.y,
          v.point.x - arc.center.x);
      final bAngle = math.atan2(next.point.y - arc.center.y,
          next.point.x - arc.center.x);
      final angleTol = tolerance / arc.radius;
      final aInSweep = circle!.sweeps.any(
          (w) => _angleInSweep(aAngle, w, angleTol));
      final bInSweep = circle.sweeps.any(
          (w) => _angleInSweep(bAngle, w, angleTol));
      expect(aInSweep, isTrue,
          reason: 'region $ri edge $i: arc start '
              '(${v.point.x}, ${v.point.y}) angle=$aAngle is outside '
              'every input sweep on circle center=(${arc.center.x}, '
              '${arc.center.y})');
      expect(bInSweep, isTrue,
          reason: 'region $ri edge $i: arc end '
              '(${next.point.x}, ${next.point.y}) angle=$bAngle is '
              'outside every input sweep on circle center='
              '(${arc.center.x}, ${arc.center.y})');
    }
  }
}

InputCircle? _findMatchingCircle(
    ArcData arc, List<InputCircle> inputCircles, double tol) {
  for (final c in inputCircles) {
    if ((arc.center.x - c.center.x).abs() < tol &&
        (arc.center.y - c.center.y).abs() < tol &&
        (arc.radius - c.radius).abs() < tol) {
      return c;
    }
  }
  return null;
}

double _distance(Coordinate p, Coordinate q) {
  final dx = p.x - q.x;
  final dy = p.y - q.y;
  return math.sqrt(dx * dx + dy * dy);
}

/// True when [angle] lies on the sweep from [w.startAngle] to
/// [w.endAngle] traveling in [w.clockwise] direction. Clockwise means
/// angle increases (y-down convention matches `ArcData.clockwise`).
bool _angleInSweep(double angle, SweepWindow w, double tol) {
  double norm(double a) {
    while (a < -math.pi) {
      a += 2 * math.pi;
    }
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    return a;
  }

  final s = norm(w.startAngle);
  final e = norm(w.endAngle);
  final a = norm(angle);
  double delta(double from, double to) {
    double d = to - from;
    if (w.clockwise) {
      while (d <= 0) {
        d += 2 * math.pi;
      }
    } else {
      while (d >= 0) {
        d -= 2 * math.pi;
      }
    }
    return d;
  }

  final totalSweep = delta(s, e).abs();
  final fromStart = delta(s, a).abs();
  return fromStart <= totalSweep + tol;
}
