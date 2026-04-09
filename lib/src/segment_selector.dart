import 'segment_fill.dart';
import 'types.dart';

/// Filters segments based on boolean operation selection tables.
class SegmentSelector {
  static SegmentList select(SegmentList segments, List<int> selection) {
    final result = SegmentList();
    for (final seg in segments.segments) {
      final myFill = seg.myFill;
      final otherFill = seg.otherFill;
      final index = (myFill.above ? 8 : 0) +
          ((myFill.below ?? false) ? 4 : 0) +
          ((otherFill?.above ?? false) ? 2 : 0) +
          ((otherFill?.below ?? false) ? 1 : 0);

      if (selection[index] != 0) {
        result.add(Segment(
          start: seg.start,
          end: seg.end,
          myFill: SegmentFill(
            above: selection[index] == 1,
            below: selection[index] == 2,
          ),
          arc: seg.arc,
        ));
      }
    }
    return result;
  }

  // Union: primary | secondary
  static const unionTable = [
    0, 2, 1, 0, //
    2, 2, 0, 0, //
    1, 0, 1, 0, //
    0, 0, 0, 0, //
  ];

  // Intersection: primary & secondary
  static const intersectTable = [
    0, 0, 0, 0, //
    0, 2, 0, 2, //
    0, 0, 1, 1, //
    0, 2, 1, 0, //
  ];

  // Difference: primary - secondary
  static const differenceTable = [
    0, 0, 0, 0, //
    2, 0, 2, 0, //
    1, 1, 0, 0, //
    0, 1, 2, 0, //
  ];

  // Reverse difference: secondary - primary
  static const differenceRevTable = [
    0, 2, 1, 0, //
    0, 0, 1, 1, //
    0, 2, 0, 2, //
    0, 0, 0, 0, //
  ];

  // XOR: primary ^ secondary
  static const xorTable = [
    0, 2, 1, 0, //
    2, 0, 0, 1, //
    1, 0, 0, 2, //
    0, 1, 2, 0, //
  ];

  static SegmentList union(SegmentList segments) =>
      select(segments, unionTable);

  static SegmentList intersect(SegmentList segments) =>
      select(segments, intersectTable);

  static SegmentList difference(SegmentList segments) =>
      select(segments, differenceTable);

  static SegmentList differenceRev(SegmentList segments) =>
      select(segments, differenceRevTable);

  static SegmentList xor(SegmentList segments) =>
      select(segments, xorTable);
}
