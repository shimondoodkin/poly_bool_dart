/// Full matrix of arc-sweep-range assertions for the `union` operation
/// across shape combinations. Intersect / difference / xor follow in
/// separate groups once union passes.
import 'dart:math' as math;

import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

import 'helpers/arc_sweep_assertions.dart';

/// Axis-aligned rectangle as an ArcPolygon.
ArcPolygon rect(double x1, double y1, double x2, double y2) =>
    ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(x1, y1)),
        ArcVertex(point: Coordinate(x2, y1)),
        ArcVertex(point: Coordinate(x2, y2)),
        ArcVertex(point: Coordinate(x1, y2)),
      ]),
    ]);

/// Rectangle with the right side replaced by a clockwise semicircle
/// bulging to the right. Arc center sits on the x=x2 edge midpoint.
/// Returns both the polygon and the InputCircle description for assertions.
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
  group('union', () {
    test('rect vs rect (no arcs in, no arcs out)', () {
      final result = PolyBoolArcs.union(
        rect(0, 0, 100, 100),
        rect(50, 50, 150, 150),
      );
      expectArcSweepWithinInputs(
          result: result, inputCircles: const []);
    });

    test('arc-rect vs rect (the minimal repro)', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final result = PolyBoolArcs.union(a.poly, rect(120, 25, 200, 75));
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle],
      );
    });

    test('arc vs arc (two semicircles overlapping)', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final b = rectWithRightSemicircle(60, 0, 160, 100);
      final result = PolyBoolArcs.union(a.poly, b.poly);
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle, b.circle],
      );
    });

    test('arc-rect vs arc-rect (non-overlapping arcs)', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final b = rectWithRightSemicircle(300, 0, 400, 100);
      final result = PolyBoolArcs.union(a.poly, b.poly);
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle, b.circle],
      );
    });
  });

  group('intersect', () {
    test('rect vs rect', () {
      final result = PolyBoolArcs.intersect(
        rect(0, 0, 100, 100),
        rect(50, 50, 150, 150),
      );
      expectArcSweepWithinInputs(
          result: result, inputCircles: const []);
    });

    test('arc-rect vs rect', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final result = PolyBoolArcs.intersect(a.poly, rect(80, 25, 200, 75));
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle],
      );
    });

    test('arc vs arc', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final b = rectWithRightSemicircle(60, 0, 160, 100);
      final result = PolyBoolArcs.intersect(a.poly, b.poly);
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle, b.circle],
      );
    });

    test('arc-rect vs arc-rect non-overlapping (empty result)', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final b = rectWithRightSemicircle(300, 0, 400, 100);
      final result = PolyBoolArcs.intersect(a.poly, b.poly);
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle, b.circle],
      );
    });
  });

  group('difference', () {
    test('rect vs rect', () {
      final result = PolyBoolArcs.difference(
        rect(0, 0, 100, 100),
        rect(50, 50, 150, 150),
      );
      expectArcSweepWithinInputs(
          result: result, inputCircles: const []);
    });

    test('arc-rect vs rect (cut the arc region)', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final result = PolyBoolArcs.difference(a.poly, rect(120, 25, 200, 75));
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle],
      );
    });

    test('arc vs arc', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final b = rectWithRightSemicircle(60, 0, 160, 100);
      final result = PolyBoolArcs.difference(a.poly, b.poly);
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle, b.circle],
      );
    });

    test('arc-rect vs arc-rect non-overlapping', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final b = rectWithRightSemicircle(300, 0, 400, 100);
      final result = PolyBoolArcs.difference(a.poly, b.poly);
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle, b.circle],
      );
    });

    test("arc-pentagon crossing rect's right edge — cw flag preserved", () {
      // Playground-captured case: a pentagon whose first edge is a
      // clockwise arc crosses the right edge of a rectangle. The
      // difference operation must preserve the arc's clockwise flag so
      // the resulting arc sweeps the SHORT way (within the input sweep)
      // rather than the long way around the circle.
      //
      // The arc endpoints are parameterized as exact points on the
      // circle at (243.6, 172.5) radius 20 — the literal playground
      // values (224.8, 179.2) and (250.0, 153.6) are slightly off the
      // circle (distance 19.96 vs 20), which would trigger the chainer
      // endpoint-on-circle assertion. Using cos/sin keeps them exact
      // while preserving the ~160.4° and ~288.8° angular positions.
      final arcCenter = Coordinate(243.6, 172.5);
      const arcRadius = 20.0;
      final startAngle = math.atan2(179.2 - 172.5, 224.8 - 243.6);
      final endAngle = math.atan2(153.6 - 172.5, 250.0 - 243.6);
      final arcStart = Coordinate(
        arcCenter.x + arcRadius * math.cos(startAngle),
        arcCenter.y + arcRadius * math.sin(startAngle),
      );
      final arcEnd = Coordinate(
        arcCenter.x + arcRadius * math.cos(endAngle),
        arcCenter.y + arcRadius * math.sin(endAngle),
      );

      final a = ArcPolygon(regions: [
        ArcRegion([
          ArcVertex(point: Coordinate(80.0, 80.0)),
          ArcVertex(point: Coordinate(240.0, 80.0)),
          ArcVertex(point: Coordinate(240.0, 200.0)),
          ArcVertex(point: Coordinate(80.0, 200.0)),
        ]),
      ]);
      final b = ArcPolygon(regions: [
        ArcRegion([
          ArcVertex(
            point: arcStart,
            arcToNext: ArcData(
              center: arcCenter,
              radius: arcRadius,
              clockwise: true,
            ),
          ),
          ArcVertex(point: arcEnd),
          ArcVertex(point: Coordinate(430.0, 133.6)),
          ArcVertex(point: Coordinate(430.0, 273.6)),
          ArcVertex(point: Coordinate(230.0, 273.6)),
        ]),
      ]);
      final result = PolyBoolArcs.difference(a, b);

      // Sweep window for the input arc: from ~160.4° to ~-71.2°
      // (288.8°), going clockwise (short way, ~128°).
      final inputCircle = InputCircle(
        center: arcCenter,
        radius: arcRadius,
        sweeps: [
          SweepWindow(
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true,
          ),
        ],
      );

      // The shared helper now performs an arc-midpoint check as well,
      // which catches the cw-flag regression this test was written for:
      // a flipped flag pushes the midpoint to the complementary
      // (long-way) side of the circle even though both endpoints remain
      // in-sweep.
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [inputCircle],
      );
    });
  });

  group('xor', () {
    test('rect vs rect', () {
      final result = PolyBoolArcs.xor(
        rect(0, 0, 100, 100),
        rect(50, 50, 150, 150),
      );
      expectArcSweepWithinInputs(
          result: result, inputCircles: const []);
    });

    test('arc-rect vs rect', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final result = PolyBoolArcs.xor(a.poly, rect(120, 25, 200, 75));
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle],
      );
    });

    test('arc vs arc', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final b = rectWithRightSemicircle(60, 0, 160, 100);
      final result = PolyBoolArcs.xor(a.poly, b.poly);
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle, b.circle],
      );
    });

    test('arc-rect vs arc-rect non-overlapping', () {
      final a = rectWithRightSemicircle(0, 0, 100, 100);
      final b = rectWithRightSemicircle(300, 0, 400, 100);
      final result = PolyBoolArcs.xor(a.poly, b.poly);
      expectArcSweepWithinInputs(
        result: result,
        inputCircles: [a.circle, b.circle],
      );
    });
  });
}
