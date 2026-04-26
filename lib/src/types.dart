import 'arc_data.dart';
import 'coordinate.dart';
import 'segment_fill.dart';

/// A segment (edge) in the polygon — either a straight line or a circular arc.
class Segment {
  Coordinate start;
  Coordinate end;
  SegmentFill myFill;
  SegmentFill? otherFill;

  /// When non-null, this segment is a circular arc from [start] to [end].
  /// When null, it is a straight line segment.
  ArcData? arc;

  /// Opaque caller-supplied provenance tag. Threaded through boolean ops
  /// so downstream consumers can trace which input edge produced an output
  /// edge. Null when no provenance was supplied (the common case).
  Object? userData;

  Segment({
    required this.start,
    required this.end,
    required this.myFill,
    this.otherFill,
    this.arc,
    this.userData,
  });

  bool get isArc => arc != null;
  bool get isLine => arc == null;

  @override
  String toString() {
    final type = arc != null ? 'Arc' : 'Line';
    return '$type($start -> $end)';
  }
}

/// A list of segments with an inverted flag.
class SegmentList {
  final List<Segment> _segments = [];
  bool inverted = false;

  int get length => _segments.length;
  bool get isEmpty => _segments.isEmpty;
  bool get isNotEmpty => _segments.isNotEmpty;

  void add(Segment seg) => _segments.add(seg);
  Segment operator [](int index) => _segments[index];
  Iterator<Segment> get iterator => _segments.iterator;

  Iterable<Segment> get segments => _segments;
}

/// Combined segment lists from two polygons, for the boolean operation phase.
class CombinedSegmentLists {
  final SegmentList combined;
  final bool inverted1;
  final bool inverted2;

  CombinedSegmentLists({
    required this.combined,
    this.inverted1 = false,
    this.inverted2 = false,
  });
}

/// Intersection result between two segments.
class Intersection {
  /// The intersection point.
  final Coordinate pt;

  /// Where along segment A the intersection lies:
  /// -2 = before start, -1 = at start, 0 = between, 1 = at end, 2 = after end
  double? alongA;

  /// Where along segment B the intersection lies (same encoding).
  double? alongB;

  Intersection({required this.pt, this.alongA, this.alongB});
}

// --- Input/Output polygon types ---

/// A vertex in an arc-aware polygon. The edge from this vertex to the next
/// vertex is an arc if [arcToNext] is non-null, otherwise a straight line.
class ArcVertex {
  final Coordinate point;
  final ArcData? arcToNext;

  /// Opaque caller-supplied provenance tag. When set on input vertices it is
  /// threaded through boolean ops and appears on output vertices that derive
  /// from the same input edge. Null when no provenance was supplied.
  final Object? userData;

  const ArcVertex({required this.point, this.arcToNext, this.userData});

  @override
  String toString() => 'ArcVertex($point, arc: $arcToNext)';
}

/// A single closed region (contour) of an arc polygon.
class ArcRegion {
  final List<ArcVertex> vertices;

  const ArcRegion(this.vertices);
}

/// A polygon with zero or more regions, supporting arc edges.
class ArcPolygon {
  final List<ArcRegion> regions;
  final bool inverted;

  const ArcPolygon({required this.regions, this.inverted = false});
}
