/// Fill status for a segment — tracks whether the region above and below
/// this segment is filled (inside the polygon).
class SegmentFill {
  bool above;

  /// null means "not yet determined" during the sweep.
  bool? below;

  SegmentFill({this.above = false, this.below});

  SegmentFill copy() => SegmentFill(above: above, below: below);

  @override
  String toString() => 'Fill(above: $above, below: $below)';
}
