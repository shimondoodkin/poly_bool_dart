import 'package:poly_bool_arcs/poly_bool_arcs.dart';

void main() {
  // Create two rectangles
  final rect1 = ArcPolygon(regions: [
    ArcRegion([
      ArcVertex(point: Coordinate(0, 0)),
      ArcVertex(point: Coordinate(10, 0)),
      ArcVertex(point: Coordinate(10, 10)),
      ArcVertex(point: Coordinate(0, 10)),
    ]),
  ]);

  final rect2 = ArcPolygon(regions: [
    ArcRegion([
      ArcVertex(point: Coordinate(5, 5)),
      ArcVertex(point: Coordinate(15, 5)),
      ArcVertex(point: Coordinate(15, 15)),
      ArcVertex(point: Coordinate(5, 15)),
    ]),
  ]);

  final result = PolyBoolArcs.union(rect1, rect2);
  print('Union has ${result.regions.length} region(s)');
  for (final region in result.regions) {
    print('  Region with ${region.vertices.length} vertices:');
    for (final v in region.vertices) {
      print('    ${v.point}');
    }
  }
}
