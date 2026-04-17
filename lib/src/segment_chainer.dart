import 'dart:math' as math;

import 'arc_data.dart';
import 'coordinate.dart';
import 'epsilon.dart';
import 'types.dart';

/// Chains segments back into closed regions, preserving arc metadata.
class SegmentChainer {
  final Epsilon eps;

  SegmentChainer(this.eps);

  /// Chain segments into closed regions.
  /// Returns a list of ArcRegion, each being a closed contour.
  List<ArcRegion> chain(SegmentList segments) {
    final chains = <_Chain>[];
    final regions = <ArcRegion>[];

    for (final seg in segments.segments) {
      final pt1 = seg.start;
      final pt2 = seg.end;

      if (eps.pointsSame(pt1, pt2)) continue;

      _ChainMatch? firstMatch;
      _ChainMatch? secondMatch;

      for (int i = 0; i < chains.length; i++) {
        final chain = chains[i];
        final head = chain.head;
        final tail = chain.tail;

        if (eps.pointsSame(head, pt1)) {
          final m = _ChainMatch(index: i, matchesHead: true, matchesPt1: true);
          if (firstMatch == null) {
            firstMatch = m;
          } else {
            secondMatch = m;
            break;
          }
        } else if (eps.pointsSame(head, pt2)) {
          final m =
              _ChainMatch(index: i, matchesHead: true, matchesPt1: false);
          if (firstMatch == null) {
            firstMatch = m;
          } else {
            secondMatch = m;
            break;
          }
        } else if (eps.pointsSame(tail, pt1)) {
          final m =
              _ChainMatch(index: i, matchesHead: false, matchesPt1: true);
          if (firstMatch == null) {
            firstMatch = m;
          } else {
            secondMatch = m;
            break;
          }
        } else if (eps.pointsSame(tail, pt2)) {
          final m =
              _ChainMatch(index: i, matchesHead: false, matchesPt1: false);
          if (firstMatch == null) {
            firstMatch = m;
          } else {
            secondMatch = m;
            break;
          }
        }
      }

      if (firstMatch == null) {
        // No match — start a new chain
        chains.add(_Chain.fromSegment(pt1, pt2, seg.arc));
        continue;
      }

      if (secondMatch == null) {
        // Matched one chain — extend it
        final chain = chains[firstMatch.index];
        final pt = firstMatch.matchesPt1 ? pt2 : pt1;
        final addToHead = firstMatch.matchesHead;

        // Determine arc data: edge from pt1->pt2, so arc is for that direction
        ArcData? arcData = seg.arc;
        // If we matched pt2 (not pt1), we're adding pt1, meaning we traverse
        // the edge backwards, so reverse the arc
        if (!firstMatch.matchesPt1 && arcData != null) {
          arcData = arcData.reversed();
        }

        if (eps.pointsSame(addToHead ? chain.tail : chain.head, pt)) {
          // Closing the loop
          // Add the final edge's arc data
          if (addToHead) {
            chain.prependPoint(pt, arcData);
          } else {
            chain.appendPoint(pt, arcData);
          }

          // Build the region
          regions.add(chain.toArcRegion());
          chains.removeAt(firstMatch.index);
        } else {
          if (addToHead) {
            chain.prependPoint(pt, arcData);
          } else {
            chain.appendPoint(pt, arcData);
          }
        }
        continue;
      }

      // Matched two chains — combine them
      final F = firstMatch.index;
      final S = secondMatch.index;

      // Determine arc for the connecting segment
      ArcData? arcData = seg.arc;
      if (!firstMatch.matchesPt1 && arcData != null) {
        arcData = arcData.reversed();
      }

      final chainF = chains[F];
      final chainS = chains[S];

      if (firstMatch.matchesHead) {
        if (secondMatch.matchesHead) {
          chainS.reverse();
          chainS.appendArcToChain(chainF, arcData);
          chains.removeAt(F);
        } else {
          chainS.appendArcToChain(chainF, arcData);
          chains.removeAt(F);
        }
      } else {
        if (secondMatch.matchesHead) {
          chainF.appendArcToChain(chainS, arcData);
          chains.removeAt(S);
        } else {
          chainS.reverse();
          chainF.appendArcToChain(chainS, arcData);
          chains.removeAt(S);
        }
      }
    }

    return regions;
  }
}

class _ChainMatch {
  final int index;
  final bool matchesHead;
  final bool matchesPt1;

  _ChainMatch({
    required this.index,
    required this.matchesHead,
    required this.matchesPt1,
  });
}

/// Internal chain structure that tracks points and arc data for edges.
class _Chain {
  // Points and arcs stored as parallel lists.
  // points[i] is a vertex, arcs[i] is the arc data for edge from points[i] to points[i+1].
  // arcs.length == points.length - 1 (or 0 if only 1 point).
  final List<Coordinate> points;
  final List<ArcData?> arcs;

  _Chain(this.points, this.arcs);

  factory _Chain.fromSegment(Coordinate p1, Coordinate p2, ArcData? arc) {
    return _Chain([p1, p2], [arc]);
  }

  Coordinate get head => points.first;
  Coordinate get tail => points.last;

  void appendPoint(Coordinate pt, ArcData? arcToNew) {
    arcs.add(arcToNew);
    points.add(pt);
  }

  void prependPoint(Coordinate pt, ArcData? arcFromNew) {
    // arcFromNew describes the edge from pt -> current head
    arcs.insert(0, arcFromNew);
    points.insert(0, pt);
  }

  void reverse() {
    final revPoints = points.reversed.toList();
    final revArcs = arcs.reversed.map((a) => a?.reversed()).toList();
    points.clear();
    points.addAll(revPoints);
    arcs.clear();
    arcs.addAll(revArcs);
  }

  /// Append another chain to the end of this one, with a connecting arc.
  void appendArcToChain(_Chain other, ArcData? connectingArc) {
    arcs.add(connectingArc);
    // Include all points of other — the first point is the destination
    // of the connecting arc, not a duplicate of our tail.
    for (int i = 0; i < other.points.length; i++) {
      points.add(other.points[i]);
    }
    for (int i = 0; i < other.arcs.length; i++) {
      arcs.add(other.arcs[i]);
    }
  }

  ArcRegion toArcRegion() {
    // The chain is closed: first point == last point (or close enough).
    // Build ArcVertex list — exclude the duplicate closing point.
    final n = points.length - 1; // last point is same as first
    final vertices = <ArcVertex>[];
    for (int i = 0; i < n; i++) {
      final arcToNext = i < arcs.length ? arcs[i] : null;
      if (arcToNext != null) {
        final start = points[i];
        final end = points[i + 1];
        final arc = arcToNext;
        assert(() {
          final cx = arc.center.x, cy = arc.center.y, r = arc.radius;
          final dStart = math.sqrt((start.x - cx) * (start.x - cx) +
              (start.y - cy) * (start.y - cy));
          final dEnd = math.sqrt((end.x - cx) * (end.x - cx) +
              (end.y - cy) * (end.y - cy));
          const tol = 1e-6;
          if ((dStart - r).abs() > tol || (dEnd - r).abs() > tol) {
            // ignore: avoid_print
            print('ASSERTION FAIL: arc emission has endpoint off the circle. '
                'start=(${start.x}, ${start.y}), end=(${end.x}, ${end.y}), '
                'center=($cx, $cy), r=$r, dStart=$dStart, dEnd=$dEnd');
            return false;
          }
          return true;
        }(), 'arc emission endpoints must lie on the arc circle');
      }
      vertices.add(ArcVertex(point: points[i], arcToNext: arcToNext));
    }
    return ArcRegion(vertices);
  }
}

