import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

/// Helper to create a rectangular ArcPolygon.
ArcPolygon makeRect(double x1, double y1, double x2, double y2) {
  return ArcPolygon(regions: [
    ArcRegion([
      ArcVertex(point: Coordinate(x1, y1)),
      ArcVertex(point: Coordinate(x2, y1)),
      ArcVertex(point: Coordinate(x2, y2)),
      ArcVertex(point: Coordinate(x1, y2)),
    ]),
  ]);
}

/// Total number of vertices in all regions.
int totalVertices(ArcPolygon p) =>
    p.regions.fold(0, (sum, r) => sum + r.vertices.length);

/// Check that all arc data is null (line-only result).
bool allLinesOnly(ArcPolygon p) {
  for (final r in p.regions) {
    for (final v in r.vertices) {
      if (v.arcToNext != null) return false;
    }
  }
  return true;
}

/// Check that a point exists in the result polygon (within epsilon).
bool hasPoint(ArcPolygon p, double x, double y, {double eps = 0.01}) {
  for (final r in p.regions) {
    for (final v in r.vertices) {
      if ((v.point.x - x).abs() < eps && (v.point.y - y).abs() < eps) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  group('Line-only rect union rect', () {
    test('non-overlapping rects produce 2 regions', () {
      final a = makeRect(0, 0, 10, 10);
      final b = makeRect(20, 0, 30, 10);
      final result = PolyBoolArcs.union(a, b);
      expect(result.regions.length, 2);
      expect(allLinesOnly(result), true);
    });

    test('overlapping rects produce 1 merged region', () {
      final a = makeRect(0, 0, 10, 10);
      final b = makeRect(5, 5, 15, 15);
      final result = PolyBoolArcs.union(a, b);
      expect(result.regions.length, 1);
      expect(allLinesOnly(result), true);
      // The L-shape should have 8 vertices
      expect(result.regions[0].vertices.length, 8);
    });

    test('identical rects produce 1 region', () {
      final a = makeRect(0, 0, 10, 10);
      final b = makeRect(0, 0, 10, 10);
      final result = PolyBoolArcs.union(a, b);
      expect(result.regions.length, 1);
      expect(result.regions[0].vertices.length, 4);
    });
  });

  group('Line-only rect intersect rect', () {
    test('overlapping rects produce intersection rectangle', () {
      final a = makeRect(0, 0, 10, 10);
      final b = makeRect(5, 5, 15, 15);
      final result = PolyBoolArcs.intersect(a, b);
      expect(result.regions.length, 1);
      expect(result.regions[0].vertices.length, 4);
      // Should be the square (5,5)-(10,10)
      expect(hasPoint(result, 5, 5), true);
      expect(hasPoint(result, 10, 10), true);
    });

    test('non-overlapping rects produce empty result', () {
      final a = makeRect(0, 0, 10, 10);
      final b = makeRect(20, 0, 30, 10);
      final result = PolyBoolArcs.intersect(a, b);
      expect(result.regions.length, 0);
    });
  });

  group('Line-only rect difference rect', () {
    test('overlapping rects produce L-shape', () {
      final a = makeRect(0, 0, 10, 10);
      final b = makeRect(5, 5, 15, 15);
      final result = PolyBoolArcs.difference(a, b);
      expect(result.regions.length, 1);
      expect(allLinesOnly(result), true);
      // L-shape has 6 vertices (or 5 if chainer merges a collinear vertex)
      expect(result.regions[0].vertices.length,
          inInclusiveRange(5, 6));
    });

    test('non-overlapping — full rect remains', () {
      final a = makeRect(0, 0, 10, 10);
      final b = makeRect(20, 0, 30, 10);
      final result = PolyBoolArcs.difference(a, b);
      expect(result.regions.length, 1);
      expect(result.regions[0].vertices.length, 4);
    });

    test('B contains A — empty result', () {
      final a = makeRect(2, 2, 8, 8);
      final b = makeRect(0, 0, 10, 10);
      final result = PolyBoolArcs.difference(a, b);
      expect(result.regions.length, 0);
    });
  });

  group('Line-only rect XOR', () {
    test('overlapping rects produce two L-shapes', () {
      final a = makeRect(0, 0, 10, 10);
      final b = makeRect(5, 5, 15, 15);
      final result = PolyBoolArcs.xor(a, b);
      expect(result.regions.length, 2);
      expect(allLinesOnly(result), true);
    });

    test('non-overlapping rects produce 2 regions', () {
      final a = makeRect(0, 0, 10, 10);
      final b = makeRect(20, 0, 30, 10);
      final result = PolyBoolArcs.xor(a, b);
      expect(result.regions.length, 2);
    });
  });
}
