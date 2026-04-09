/// Polygon boolean operations with circular arc support.
///
/// Provides union, intersection, difference, and XOR operations
/// on polygons whose edges can be straight line segments or circular arcs.
library;

export 'src/arc_data.dart';
export 'src/coordinate.dart';
export 'src/epsilon.dart' show Epsilon;
export 'src/geometry.dart' show Geometry;
export 'src/poly_bool_arcs_impl.dart' show PolyBoolArcs;
export 'src/types.dart'
    show ArcVertex, ArcRegion, ArcPolygon, Segment, Intersection;
