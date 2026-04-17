/// Edge-case coverage for the arc-sweep-range invariant.
import 'dart:math' as math;

import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

import 'helpers/arc_sweep_assertions.dart';

ArcPolygon rect(double x1, double y1, double x2, double y2) =>
    ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(x1, y1)),
        ArcVertex(point: Coordinate(x2, y1)),
        ArcVertex(point: Coordinate(x2, y2)),
        ArcVertex(point: Coordinate(x1, y2)),
      ]),
    ]);

({ArcPolygon poly, InputCircle circle}) rectWithRightSemicircle(
    double x1, double y1, double x2, double y2) {
  final cx = x2;
  final cy = (y1 + y2) / 2;
  final r = (y2 - y1) / 2;
  return (
    poly: ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(x1, y1)),
        ArcVertex(
          point: Coordinate(x2, y1),
          arcToNext: ArcData(
            center: Coordinate(cx, cy),
            radius: r,
            clockwise: true,
          ),
        ),
        ArcVertex(point: Coordinate(x2, y2)),
        ArcVertex(point: Coordinate(x1, y2)),
      ]),
    ]),
    circle: InputCircle(
      center: Coordinate(cx, cy),
      radius: r,
      sweeps: [
        SweepWindow(
          startAngle: -math.pi / 2,
          endAngle: math.pi / 2,
          clockwise: true,
        ),
      ],
    ),
  );
}

void main() {
  test('arc fully inside the other polygon — union', () {
    final a = rectWithRightSemicircle(0, 0, 100, 100);
    // B contains A's arc region entirely on its right side.
    final result = PolyBoolArcs.union(a.poly, rect(-50, -50, 300, 200));
    expectArcSweepWithinInputs(
        result: result, inputCircles: [a.circle]);
  });

  test('arc fully outside the other polygon — union', () {
    final a = rectWithRightSemicircle(0, 0, 100, 100);
    // B is far away and does not touch A.
    final result = PolyBoolArcs.union(a.poly, rect(500, 500, 600, 600));
    expectArcSweepWithinInputs(
        result: result, inputCircles: [a.circle]);
  });

  test("arc tangent to other polygon's edge — union", () {
    final a = rectWithRightSemicircle(0, 0, 100, 100);
    // B's left edge is exactly tangent to A's arc at (150, 50).
    final result = PolyBoolArcs.union(a.poly, rect(150, 25, 250, 75));
    expectArcSweepWithinInputs(
        result: result, inputCircles: [a.circle]);
  });

  test("arc endpoints coincide with the other polygon's vertices", () {
    final a = rectWithRightSemicircle(0, 0, 100, 100);
    // B has a vertex at (100, 0) — the arc's start.
    final result = PolyBoolArcs.union(
      a.poly,
      rect(100, 0, 200, 100),
    );
    expectArcSweepWithinInputs(
        result: result, inputCircles: [a.circle]);
  });

  test('longer-than-semicircle arc (sweep > pi)', () {
    // A: 270-degree arc from (100, -50) clockwise to (0, -50), with a
    // single closing chord. Exercises the y-extreme split in
    // _addArcSubSegments.
    final a = ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(
          point: Coordinate(100, -50),
          arcToNext: ArcData(
            center: Coordinate(50, -50),
            radius: 50,
            clockwise: true,
          ),
        ),
        ArcVertex(point: Coordinate(0, -50)),
      ]),
    ]);
    final aCircle = InputCircle(
      center: Coordinate(50, -50),
      radius: 50,
      sweeps: [
        // Clockwise from angle 0 all the way to angle pi (long sweep
        // 270 degrees passing through pi/2 and pi).
        SweepWindow(
          startAngle: 0,
          endAngle: math.pi,
          clockwise: true,
        ),
      ],
    );
    final b = rect(30, -100, 150, 50);
    final result = PolyBoolArcs.union(a, b);
    expectArcSweepWithinInputs(
        result: result, inputCircles: [aCircle]);
  });
}
