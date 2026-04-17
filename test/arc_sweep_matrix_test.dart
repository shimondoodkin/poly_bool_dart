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
