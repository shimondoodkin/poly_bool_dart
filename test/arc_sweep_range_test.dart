/// Regression test for the arc-sweep-range bug.
///
/// Symptom: when a boolean operation produces arc segments in the result,
/// the library can emit arcs whose endpoints lie on the underlying circle
/// but OUTSIDE the original input arc's defined sweep range. Rendering
/// code that honours the arc metadata (center + radius + clockwise) then
/// draws an arc on a part of the circle that was never part of any input
/// boundary — "it treated the full circle as the boundary, not the arc."
///
/// Minimal reproducer:
///   A = rectangle (0,0)-(100,100) with the right side replaced by a
///       clockwise semicircle bulging to the right: endpoints (100,0) and
///       (100,100), center (100,50), radius 50. The arc's defined sweep
///       covers the RIGHT half of the circle only — i.e., every point on
///       the arc has x >= 100.
///   B = rectangle (120,25)-(200,75), whose left edge crosses A's arc.
///
/// For union(A, B), every arc in the result that sits on A's circle must
/// stay within A's sweep (x >= 100). Any arc endpoint with x < 100 is
/// evidence that the library emitted geometry outside the input arc's
/// range — i.e., treated the full circle as a boundary.
import 'dart:math' as math;

import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

void main() {
  test('union: result arcs stay within input arc sweep range', () {
    final a = ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(0, 0)),
        ArcVertex(
          point: Coordinate(100, 0),
          arcToNext: ArcData(
            center: Coordinate(100, 50),
            radius: 50,
            clockwise: true,
          ),
        ),
        ArcVertex(point: Coordinate(100, 100)),
        ArcVertex(point: Coordinate(0, 100)),
      ]),
    ]);

    final b = ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(120, 25)),
        ArcVertex(point: Coordinate(200, 25)),
        ArcVertex(point: Coordinate(200, 75)),
        ArcVertex(point: Coordinate(120, 75)),
      ]),
    ]);

    final result = PolyBoolArcs.union(a, b);

    const circleTol = 0.01; // cm of radius tolerance
    const sweepTol = 0.01;  // cm of x-coordinate tolerance

    for (int ri = 0; ri < result.regions.length; ri++) {
      final region = result.regions[ri];
      for (int i = 0; i < region.vertices.length; i++) {
        final v = region.vertices[i];
        final arc = v.arcToNext;
        if (arc == null) continue;
        final next = region.vertices[(i + 1) % region.vertices.length];

        // The only circle in the input is A's: center (100,50), r=50.
        // Any arc on a different circle is a synthesis bug.
        expect(arc.center.x, closeTo(100, circleTol),
            reason: 'region $ri edge $i: arc center.x does not match '
                'any input circle');
        expect(arc.center.y, closeTo(50, circleTol),
            reason: 'region $ri edge $i: arc center.y does not match '
                'any input circle');
        expect(arc.radius, closeTo(50, circleTol),
            reason: 'region $ri edge $i: arc radius does not match '
                'any input circle');

        // Both endpoints must be ON the circle (within tolerance).
        final distA = math.sqrt(
            math.pow(v.point.x - arc.center.x, 2).toDouble() +
                math.pow(v.point.y - arc.center.y, 2).toDouble());
        final distB = math.sqrt(
            math.pow(next.point.x - arc.center.x, 2).toDouble() +
                math.pow(next.point.y - arc.center.y, 2).toDouble());
        expect(distA, closeTo(50, circleTol),
            reason: 'region $ri edge $i: arc start (${v.point.x}, '
                '${v.point.y}) is not on the circle (distance=$distA)');
        expect(distB, closeTo(50, circleTol),
            reason: 'region $ri edge $i: arc end (${next.point.x}, '
                '${next.point.y}) is not on the circle (distance=$distB)');

        // Input sweep for A's arc is the RIGHT half of the circle:
        // endpoints (100,0) and (100,100), clockwise through (150,50).
        // Every point on the input arc has x >= 100.
        // Therefore every arc endpoint in the result that sits on this
        // circle must also have x >= 100.
        expect(v.point.x, greaterThanOrEqualTo(100 - sweepTol),
            reason: 'region $ri edge $i: arc start (${v.point.x}, '
                '${v.point.y}) has x < 100 — outside A\'s sweep. The '
                'library emitted an arc on a part of the circle that '
                'was never part of A\'s boundary.');
        expect(next.point.x, greaterThanOrEqualTo(100 - sweepTol),
            reason: 'region $ri edge $i: arc end (${next.point.x}, '
                '${next.point.y}) has x < 100 — outside A\'s sweep.');
      }
    }
  });
}
