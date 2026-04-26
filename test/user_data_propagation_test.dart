import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

void main() {
  group('userData propagation', () {
    test('userData is preserved on output ArcVertex through identity op (no clip)', () {
      final region = ArcRegion([
        ArcVertex(point: Coordinate(0, 0), userData: 'A'),
        ArcVertex(point: Coordinate(10, 0), userData: 'B'),
        ArcVertex(point: Coordinate(10, 10), userData: 'C'),
        ArcVertex(point: Coordinate(0, 10), userData: 'D'),
      ]);
      final p = ArcPolygon(regions: [region]);
      // Union with self == self.
      final out = PolyBoolArcs.union(p, p);
      final datas = [for (final r in out.regions) ...r.vertices]
          .map((v) => v.userData)
          .toSet();
      // At minimum, the original userData should appear somewhere in the output.
      expect(datas.intersection({'A', 'B', 'C', 'D'}).isNotEmpty, true,
          reason: 'union(p, p) should preserve at least some original userData');
    });

    test('userData survives an intersect that does NOT split source segments', () {
      // Square A fully contains square B. Intersect == B.
      // userData on B's vertices should survive.
      final a = ArcPolygon(regions: [
        ArcRegion([
          ArcVertex(point: Coordinate(0, 0)),
          ArcVertex(point: Coordinate(20, 0)),
          ArcVertex(point: Coordinate(20, 20)),
          ArcVertex(point: Coordinate(0, 20)),
        ])
      ]);
      final b = ArcPolygon(regions: [
        ArcRegion([
          ArcVertex(point: Coordinate(5, 5), userData: 'b1'),
          ArcVertex(point: Coordinate(15, 5), userData: 'b2'),
          ArcVertex(point: Coordinate(15, 15), userData: 'b3'),
          ArcVertex(point: Coordinate(5, 15), userData: 'b4'),
        ])
      ]);
      final out = PolyBoolArcs.intersect(a, b);
      final datas = [for (final r in out.regions) ...r.vertices]
          .map((v) => v.userData)
          .toSet();
      expect(datas.intersection({'b1', 'b2', 'b3', 'b4'}).isNotEmpty, true,
          reason: 'intersect should preserve userData on uncut B vertices');
    });

    test('userData propagates through a split (segment cut by intersection)', () {
      // Two crossing strips; the horizontal one has tagged vertices.
      // After difference, surviving pieces should still carry the tag.
      final tagged = ArcPolygon(regions: [
        ArcRegion([
          ArcVertex(point: Coordinate(0, 4), userData: 'X'),
          ArcVertex(point: Coordinate(20, 4), userData: 'X'),
          ArcVertex(point: Coordinate(20, 6), userData: 'X'),
          ArcVertex(point: Coordinate(0, 6), userData: 'X'),
        ])
      ]);
      final cutter = ArcPolygon(regions: [
        ArcRegion([
          ArcVertex(point: Coordinate(8, 0)),
          ArcVertex(point: Coordinate(12, 0)),
          ArcVertex(point: Coordinate(12, 10)),
          ArcVertex(point: Coordinate(8, 10)),
        ])
      ]);
      final out = PolyBoolArcs.difference(tagged, cutter);
      final datas = [for (final r in out.regions) ...r.vertices]
          .map((v) => v.userData)
          .toSet();
      // The "X" tag should appear at least once on surviving vertices.
      expect(datas.contains('X'), true,
          reason: 'difference should preserve userData on surviving X-tagged vertices');
    });

    test('output without userData input still works (backwards compat)', () {
      final a = ArcPolygon(regions: [
        ArcRegion([
          ArcVertex(point: Coordinate(0, 0)),
          ArcVertex(point: Coordinate(10, 0)),
          ArcVertex(point: Coordinate(10, 10)),
          ArcVertex(point: Coordinate(0, 10)),
        ])
      ]);
      final out = PolyBoolArcs.union(a, a);
      final datas = [for (final r in out.regions) ...r.vertices]
          .map((v) => v.userData)
          .toList();
      expect(datas.every((d) => d == null), true,
          reason: 'no userData in -> no userData out (no spurious values)');
    });
  });
}
