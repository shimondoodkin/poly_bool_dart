import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

/// Create a circle polygon approximated by two semicircular arcs.
ArcPolygon makeCircle(double cx, double cy, double r) {
  // Circle as two arcs: top half and bottom half
  // Right point (cx+r, cy) -> Left point (cx-r, cy) via top (CCW)
  // Left point (cx-r, cy) -> Right point (cx+r, cy) via bottom (CCW)
  final right = Coordinate(cx + r, cy);
  final left = Coordinate(cx - r, cy);
  final center = Coordinate(cx, cy);

  return ArcPolygon(regions: [
    ArcRegion([
      ArcVertex(
        point: right,
        arcToNext: ArcData(center: center, radius: r, clockwise: false),
      ),
      ArcVertex(
        point: left,
        arcToNext: ArcData(center: center, radius: r, clockwise: false),
      ),
    ]),
  ]);
}

/// Create a rectangular ArcPolygon.
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

bool hasArcEdges(ArcPolygon p) {
  for (final r in p.regions) {
    for (final v in r.vertices) {
      if (v.arcToNext != null) return true;
    }
  }
  return false;
}

bool hasLineEdges(ArcPolygon p) {
  for (final r in p.regions) {
    for (final v in r.vertices) {
      if (v.arcToNext == null) return true;
    }
  }
  return false;
}

void main() {
  group('Circle-circle operations', () {
    test('two overlapping circles union', () {
      final c1 = makeCircle(0, 0, 5);
      final c2 = makeCircle(4, 0, 5);
      final result = PolyBoolArcs.union(c1, c2);
      expect(result.regions.length, 1);
      expect(hasArcEdges(result), true);
    });

    test('two overlapping circles intersection (lens shape)', () {
      final c1 = makeCircle(0, 0, 5);
      final c2 = makeCircle(4, 0, 5);
      final result = PolyBoolArcs.intersect(c1, c2);
      expect(result.regions.length, 1);
      expect(hasArcEdges(result), true);
    });

    test('circle difference circle (crescent)', () {
      final c1 = makeCircle(0, 0, 5);
      final c2 = makeCircle(3, 0, 5);
      final result = PolyBoolArcs.difference(c1, c2);
      expect(result.regions.length, 1);
      expect(hasArcEdges(result), true);
    });

    test('non-overlapping circles union gives 2 regions', () {
      final c1 = makeCircle(0, 0, 2);
      final c2 = makeCircle(10, 0, 2);
      final result = PolyBoolArcs.union(c1, c2);
      expect(result.regions.length, 2);
    });

    test('non-overlapping circles intersection is empty', () {
      final c1 = makeCircle(0, 0, 2);
      final c2 = makeCircle(10, 0, 2);
      final result = PolyBoolArcs.intersect(c1, c2);
      expect(result.regions.length, 0);
    });
  });

  group('Rectangle-circle operations', () {
    test('rect union circle — circle contains rect', () {
      // Circle fully contains rect — union should be just the circle
      final rect = makeRect(-2, -2, 2, 2);
      final circle = makeCircle(0, 0, 5);
      final result = PolyBoolArcs.union(rect, circle);
      expect(result.regions.length, 1);
      expect(hasArcEdges(result), true);
    });

    test('rect union circle — partial overlap', () {
      // Circle centered at edge of rect, partially overlapping
      final rect = makeRect(0, 0, 10, 10);
      final circle = makeCircle(10, 5, 3);
      final result = PolyBoolArcs.union(rect, circle);
      expect(result.regions.length, 1);
      // Should have both line and arc edges
      expect(hasArcEdges(result), true);
      expect(hasLineEdges(result), true);
    });

    test('rect intersect circle where circle is larger', () {
      final rect = makeRect(-3, -3, 3, 3);
      final circle = makeCircle(0, 0, 10);
      final result = PolyBoolArcs.intersect(rect, circle);
      // Circle fully contains rect, so intersection is the rect
      expect(result.regions.length, 1);
      expect(result.regions[0].vertices.length, 4);
    });

    test('rect intersect circle partial overlap', () {
      // Rect from 0..10 x 0..10, circle at (5,5) r=3
      // Circle is inside the rect
      final rect = makeRect(0, 0, 10, 10);
      final circle = makeCircle(5, 5, 3);
      final result = PolyBoolArcs.intersect(rect, circle);
      // Circle is fully inside rect, so intersection is the circle
      expect(result.regions.length, 1);
      expect(hasArcEdges(result), true);
    });

    test('rect difference circle (rect with circular hole)', () {
      // Big rect with a small circle inside
      final rect = makeRect(0, 0, 10, 10);
      final circle = makeCircle(5, 5, 2);
      final result = PolyBoolArcs.difference(rect, circle);
      // Should give rect with a hole
      expect(result.regions.length, 2);
    });
  });
}
