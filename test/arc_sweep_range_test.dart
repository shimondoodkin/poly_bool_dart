/// Regression test for the arc-sweep-range bug.
///
/// See docs/superpowers/specs/2026-04-17-poly-bool-arcs-sweep-fix-design.md
/// in the tile-calculator-app repo for the full context.
import 'dart:math' as math;

import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

import 'helpers/arc_sweep_assertions.dart';

void main() {
  test('union: rect-with-right-arc vs rect-overlapping-arc', () {
    // Polygon A: rectangle (0,0)-(100,100) with the right side replaced
    // by a clockwise semicircle bulging right. Arc sweep: right half of
    // the circle (angles -pi/2 through pi/2 clockwise).
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

    // Polygon B: rectangle overlapping A's arc region on the right.
    final b = ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(120, 25)),
        ArcVertex(point: Coordinate(200, 25)),
        ArcVertex(point: Coordinate(200, 75)),
        ArcVertex(point: Coordinate(120, 75)),
      ]),
    ]);

    expectArcSweepWithinInputs(
      result: PolyBoolArcs.union(a, b),
      inputCircles: [
        InputCircle(
          center: Coordinate(100, 50),
          radius: 50,
          sweeps: [
            SweepWindow(
              startAngle: -math.pi / 2,
              endAngle: math.pi / 2,
              clockwise: true,
            ),
          ],
        ),
      ],
    );
  });
}
