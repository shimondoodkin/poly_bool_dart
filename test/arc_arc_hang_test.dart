import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

/// Regression test for a hang triggered when two polygons each carry an arc
/// whose underlying circles cross at two points, but whose sub-arcs (after
/// y-extreme splitting) share floating-point-close start/end coordinates.
///
/// Before the fix, `_checkArcArcIntersection` iterated over both intersection
/// points and called `eventDivide` twice on the same event. The second call
/// saw an `ev.seg.end` that had already been replaced by the first divide,
/// so the near-endpoint check failed and `eventUpdateEnd` extended the
/// segment back past its split — causing the same crossing to recur and the
/// sweep-line loop to spin forever.
void main() {
  final a = ArcPolygon(regions: [
    ArcRegion([
      ArcVertex(point: Coordinate(80.00, 80.00)),
      ArcVertex(
          point: Coordinate(240.00, 80.00),
          arcToNext: ArcData(
              center: Coordinate(270.00, 140.00),
              radius: 67.08,
              clockwise: true)),
      ArcVertex(point: Coordinate(240.00, 200.00)),
      ArcVertex(point: Coordinate(80.00, 200.00)),
    ]),
  ]);
  final b = ArcPolygon(regions: [
    ArcRegion([
      ArcVertex(point: Coordinate(342.40, 149.60)),
      ArcVertex(point: Coordinate(542.40, 149.60)),
      ArcVertex(point: Coordinate(542.40, 289.60)),
      ArcVertex(
          point: Coordinate(342.40, 289.60),
          arcToNext: ArcData(
              center: Coordinate(348.00, 219.60),
              radius: 70.22,
              clockwise: true)),
    ]),
  ]);

  const budget = Duration(milliseconds: 500);

  test('intersect of two arc polygons with crossing circles completes', () {
    final sw = Stopwatch()..start();
    PolyBoolArcs.intersect(a, b);
    sw.stop();
    expect(sw.elapsed, lessThan(budget),
        reason: 'intersect took ${sw.elapsedMilliseconds}ms');
  });

  test('union of two arc polygons with crossing circles completes', () {
    final sw = Stopwatch()..start();
    PolyBoolArcs.union(a, b);
    sw.stop();
    expect(sw.elapsed, lessThan(budget),
        reason: 'union took ${sw.elapsedMilliseconds}ms');
  });

  test('difference of two arc polygons with crossing circles completes', () {
    final sw = Stopwatch()..start();
    PolyBoolArcs.difference(a, b);
    sw.stop();
    expect(sw.elapsed, lessThan(budget),
        reason: 'difference took ${sw.elapsedMilliseconds}ms');
  });

  test('xor of two arc polygons with crossing circles completes', () {
    final sw = Stopwatch()..start();
    PolyBoolArcs.xor(a, b);
    sw.stop();
    expect(sw.elapsed, lessThan(budget),
        reason: 'xor took ${sw.elapsedMilliseconds}ms');
  });
}
