/// Regression: arc endpoints slightly off the declared circle must not
/// destabilise the library. Without ingest snapping, this input drove
/// the Flutter Web playground into a browser-tab crash.
import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

void main() {
  test('tolerates arc vertex drift of ~0.005 units from declared circle', () {
    // Endpoint (219.2, 70.4) is 60.005 from center (218.4, 130.4), but
    // the arc is declared r=60.01.
    final a = ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(59.20, 70.40)),
        ArcVertex(
            point: Coordinate(219.20, 70.40),
            arcToNext: ArcData(
                center: Coordinate(218.40, 130.40),
                radius: 60.01,
                clockwise: true)),
        ArcVertex(point: Coordinate(219.20, 190.40)),
        ArcVertex(point: Coordinate(59.20, 190.40)),
      ]),
    ]);
    final b = ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(264.00, 150.40)),
        ArcVertex(point: Coordinate(462.40, 152.00)),
        ArcVertex(point: Coordinate(448.80, 272.00)),
        ArcVertex(
            point: Coordinate(254.40, 260.00),
            arcToNext: ArcData(
                center: Coordinate(256.37, 204.95),
                radius: 55.08,
                clockwise: true)),
      ]),
    ]);
    // Each op must return without throwing and within a reasonable time.
    for (final opName in ['union', 'intersect', 'difference', 'xor']) {
      final sw = Stopwatch()..start();
      final r = switch (opName) {
        'union' => PolyBoolArcs.union(a, b),
        'intersect' => PolyBoolArcs.intersect(a, b),
        'difference' => PolyBoolArcs.difference(a, b),
        'xor' => PolyBoolArcs.xor(a, b),
        _ => throw StateError('unreachable'),
      };
      sw.stop();
      // 200ms is generous for this small input; in practice <20ms.
      expect(sw.elapsedMilliseconds, lessThan(200),
          reason: '$opName took ${sw.elapsedMilliseconds}ms');
      // Also assert it returned a valid polygon (possibly empty).
      expect(r.regions, isNotNull);
    }
  });
}
