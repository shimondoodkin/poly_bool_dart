import 'dart:collection';
import 'dart:math' as math;

import 'coordinate.dart';
import 'epsilon.dart';
import 'types.dart';

/// Event node in the sweep-line event queue.
final class EventNode extends LinkedListEntry<EventNode> {
  final bool isStart;
  Coordinate pt;
  final Segment seg;
  final bool primary;
  late EventNode other;
  StatusNode? status;

  EventNode({
    required this.isStart,
    required this.pt,
    required this.seg,
    required this.primary,
  });

  int compareTo(EventNode p2, Epsilon eps) {
    final comp = eps.pointsCompare(pt, p2.pt);
    if (comp != 0) return comp;

    // For segments with same start and end: lines are equal, arcs may differ
    if (eps.pointsSame(other.pt, p2.other.pt)) {
      // If both are lines with same endpoints, they're truly equal
      if (seg.isLine && p2.seg.isLine) return 0;
      // If one or both are arcs, compare by y at midpoint
      final midX = (pt.x + other.pt.x) / 2;
      final xCheck = midX == pt.x ? pt.x + eps.eps * 1000 : midX;
      final y1 = _segmentYAtX(seg, xCheck, eps);
      final y2 = _segmentYAtX(p2.seg, xCheck, eps);
      if (y1 != null && y2 != null && (y1 - y2).abs() > eps.eps) {
        return y1 > y2 ? 1 : -1;
      }
      return 0;
    }

    if (isStart != p2.isStart) return isStart ? 1 : -1;

    // For line segments, use the original comparison
    if (seg.isLine && p2.seg.isLine) {
      return eps.pointAboveOrOnLine(
              other.pt,
              p2.isStart ? p2.pt : p2.other.pt,
              p2.isStart ? p2.other.pt : p2.pt)
          ? 1
          : -1;
    }

    // For arcs, compare based on y-values slightly after the shared x
    final x = pt.x + eps.eps * 1000;
    final y1 = _segmentYAtX(seg, x, eps);
    final y2 = _segmentYAtX(p2.seg, x, eps);
    if (y1 != null && y2 != null) {
      if ((y1 - y2).abs() < eps.eps) return 0;
      return y1 > y2 ? 1 : -1;
    }

    return 0;
  }
}

/// Status node in the sweep-line status structure.
final class StatusNode extends LinkedListEntry<StatusNode> {
  final EventNode ev;

  StatusNode({required this.ev});

  int compareTo(StatusNode other, Epsilon eps) {
    final seg1 = ev.seg;
    final seg2 = other.ev.seg;

    // For two line segments, use the original poly_bool_dart comparison
    if (seg1.isLine && seg2.isLine) {
      final a1 = seg1.start;
      final a2 = seg1.end;
      final b1 = seg2.start;
      final b2 = seg2.end;

      if (eps.pointsCollinear(a1, b1, b2)) {
        if (eps.pointsCollinear(a2, b1, b2)) return 1;
        return eps.pointAboveOrOnLine(a2, b1, b2) ? 1 : -1;
      }
      return eps.pointAboveOrOnLine(a1, b1, b2) ? 1 : -1;
    }

    // For arcs or mixed, compare y-values at the start of the NEW segment
    // (which is this node — seg1). The sweep processes events left-to-right,
    // so at insertion time the relevant x is seg1.start.x.
    final x0 = seg1.start.x;

    // Try at the insertion x and slightly to the right
    for (final xTest in [x0, x0 + eps.eps * 1000]) {
      final y1 = _segmentYAtX(seg1, xTest, eps);
      final y2 = _segmentYAtX(seg2, xTest, eps);

      if (y1 != null && y2 != null && (y1 - y2).abs() > eps.eps * 10) {
        return y1 > y2 ? 1 : -1;
      }
    }

    return 1;
  }
}

/// Get the y-coordinate of a segment at a given x.
/// For line segments, interpolate. For arcs, solve the circle equation.
double? _segmentYAtX(Segment seg, double x, Epsilon eps) {
  if (seg.isLine) {
    final dx = seg.end.x - seg.start.x;
    if (dx.abs() < eps.eps) {
      // Vertical line
      return seg.start.y;
    }
    final t = (x - seg.start.x) / dx;
    return seg.start.y + t * (seg.end.y - seg.start.y);
  }

  // Arc segment
  final arc = seg.arc!;
  final dx = x - arc.center.x;
  if (dx.abs() > arc.radius + eps.eps) return null;

  var disc = arc.radius * arc.radius - dx * dx;
  if (disc < 0) disc = 0;
  final sqrtDisc = math.sqrt(disc);

  // Two possible y values
  final y1 = arc.center.y + sqrtDisc;
  final y2 = arc.center.y - sqrtDisc;

  // Determine which y is on the arc (using angular range)
  // For the upper arc (CCW going up from right to left), y1 is correct
  // For the lower arc, y2 is correct
  // We determine this by checking which y matches the arc's direction

  // Check the midpoint of the arc to determine which side
  final startAngle =
      math.atan2(seg.start.y - arc.center.y, seg.start.x - arc.center.x);
  final endAngle =
      math.atan2(seg.end.y - arc.center.y, seg.end.x - arc.center.x);

  // Compute a mid-angle
  double midAngle;
  if (arc.clockwise) {
    // CW: go from start to end by decreasing angle
    var diff = startAngle - endAngle;
    if (diff < 0) diff += 2 * math.pi;
    midAngle = startAngle - diff / 2;
  } else {
    // CCW: go from start to end by increasing angle
    var diff = endAngle - startAngle;
    if (diff < 0) diff += 2 * math.pi;
    midAngle = startAngle + diff / 2;
  }

  final midY = arc.center.y + arc.radius * math.sin(midAngle);

  // Pick the y that's on the same side as the mid-point
  if ((midY - arc.center.y) >= 0) {
    return y1; // upper arc
  } else {
    return y2; // lower arc
  }
}

/// Transition info returned by status list lookup.
class Transition {
  final EventNode? above;
  final EventNode? below;
  final StatusNode Function() insert;

  Transition({this.above, this.below, required this.insert});
}

/// Event queue — sorted doubly-linked list using dart:collection LinkedList.
final class EventLinkedList extends LinkedList<EventNode> {
  EventNode? get head => isEmpty ? null : first;

  void insertBefore(EventNode node, Epsilon eps) {
    if (isEmpty) {
      add(node);
      return;
    }
    try {
      final ev = firstWhere((e) => node.compareTo(e, eps) < 0);
      ev.insertBefore(node);
    } catch (_) {
      add(node);
    }
  }
}

/// Status structure — sorted doubly-linked list.
final class StatusLinkedList extends LinkedList<StatusNode> {
  StatusNode? get head => isEmpty ? null : first;

  Transition findTransition(EventNode ev, Epsilon eps) {
    final newNode = StatusNode(ev: ev);

    if (isEmpty) {
      return Transition(insert: () {
        add(newNode);
        return newNode;
      });
    }

    StatusNode? here;
    try {
      here = firstWhere((s) => newNode.compareTo(s, eps) > 0);
    } catch (_) {}

    StatusNode? prev = (here == null) ? last : here.previous;

    return Transition(
      above: prev?.ev,
      below: here?.ev,
      insert: here != null
          ? () {
              here!.insertBefore(newNode);
              return newNode;
            }
          : () {
              add(newNode);
              return newNode;
            },
    );
  }
}
