import 'dart:math' as math;

import 'arc_data.dart';
import 'coordinate.dart';
import 'epsilon.dart';
import 'geometry.dart';
import 'linked_list.dart';
import 'segment_fill.dart';
import 'types.dart';

/// The sweep-line intersecter. Processes segments, finds intersections,
/// splits segments, and computes fill flags.
class Intersecter {
  final bool selfIntersection;
  final Epsilon eps;
  final Geometry geo;
  final EventLinkedList eventRoot = EventLinkedList();
  final StatusLinkedList statusRoot = StatusLinkedList();

  Intersecter(this.selfIntersection, this.eps) : geo = Geometry(eps);

  Segment segmentNew(Coordinate start, Coordinate end, {ArcData? arc}) {
    return Segment(start: start, end: end, myFill: SegmentFill(), arc: arc);
  }

  Segment segmentCopy(Coordinate start, Coordinate end, Segment seg) {
    return Segment(
      start: start,
      end: end,
      myFill: seg.myFill.copy(),
      arc: seg.arc,
    );
  }

  EventNode eventAddSegment(Segment seg, bool primary) {
    final evStart =
        EventNode(isStart: true, pt: seg.start, seg: seg, primary: primary);
    final evEnd =
        EventNode(isStart: false, pt: seg.end, seg: seg, primary: primary);

    evStart.other = evEnd;
    evEnd.other = evStart;

    eventRoot.insertBefore(evStart, eps);
    eventRoot.insertBefore(evEnd, eps);

    return evStart;
  }

  void eventUpdateEnd(EventNode ev, Coordinate end) {
    // The other node might already be unlinked if it was processed
    if (ev.other.list != null) {
      ev.other.unlink();
    }
    ev.seg.end = end;
    ev.other.pt = end;
    eventRoot.insertBefore(ev.other, eps);
  }

  EventNode eventDivide(EventNode ev, Coordinate pt) {
    final ns = segmentCopy(pt, ev.seg.end, ev.seg);
    eventUpdateEnd(ev, pt);
    return eventAddSegment(ns, ev.primary);
  }

  /// Add a region of coordinates (line-only polygon).
  void addRegion(List<Coordinate> region) {
    if (!selfIntersection) {
      throw Exception('addRegion is only for selfIntersection mode');
    }
    if (region.length < 2) return;

    // Close the polygon if needed
    final regionCopy = List<Coordinate>.from(region);
    if (!eps.pointsSame(regionCopy.last, regionCopy.first)) {
      regionCopy.add(regionCopy.first);
    }

    for (int i = 0; i < regionCopy.length - 1; i++) {
      final pt1 = regionCopy[i];
      final pt2 = regionCopy[i + 1];

      final forward = eps.pointsCompare(pt1, pt2);
      if (forward == 0) continue;

      eventAddSegment(
        segmentNew(forward < 0 ? pt1 : pt2, forward < 0 ? pt2 : pt1),
        true,
      );
    }
  }

  /// Add a region with arc support.
  void addArcRegion(List<ArcVertex> vertices) {
    if (!selfIntersection) {
      throw Exception('addArcRegion is only for selfIntersection mode');
    }
    if (vertices.length < 2) return;

    for (int i = 0; i < vertices.length; i++) {
      final v1 = vertices[i];
      final v2 = vertices[(i + 1) % vertices.length];
      final pt1 = v1.point;
      final pt2 = v2.point;
      final arc = v1.arcToNext;

      if (arc == null) {
        // Line segment
        final forward = eps.pointsCompare(pt1, pt2);
        if (forward == 0) continue;
        eventAddSegment(
          segmentNew(forward < 0 ? pt1 : pt2, forward < 0 ? pt2 : pt1),
          true,
        );
      } else {
        // Snap both endpoints to the arc's circle before ingest. User-
        // supplied polygons often have small floating-point drift between
        // the declared circle (center, radius) and the actual vertex
        // positions. Downstream math (sub-arc splitting, intersections)
        // uses the declared circle, so we must project endpoints onto it
        // to keep the internal representation self-consistent.
        final snap1 = _snapToArcCircle(pt1, arc.center, arc.radius);
        final snap2 = _snapToArcCircle(pt2, arc.center, arc.radius);
        // Arc segment — split at y-extremes for sweep-line correctness
        _addArcSubSegments(snap1, snap2, arc);
      }
    }
  }

  /// Project [p] onto the circle at [center] with [radius]. If [p] is at
  /// the center (degenerate), returns (center.x + radius, center.y).
  Coordinate _snapToArcCircle(Coordinate p, Coordinate center, double radius) {
    final dx = p.x - center.x;
    final dy = p.y - center.y;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1e-18) {
      return Coordinate(center.x + radius, center.y);
    }
    final scale = radius / math.sqrt(len2);
    // If already on the circle within a very tight tolerance, return as-is
    // to avoid microscopic perturbation.
    if ((scale - 1.0).abs() < 1e-12) return p;
    return Coordinate(center.x + dx * scale, center.y + dy * scale);
  }

  /// Split an arc at its y-extreme points (top/bottom of circle) and at
  /// x-extreme points, then add each sub-arc as a segment.
  /// This ensures each sub-arc is y-monotone, making the sweep-line
  /// status ordering correct.
  void _addArcSubSegments(Coordinate pt1, Coordinate pt2, ArcData arc) {
    // Find the extreme points of the arc that lie between pt1 and pt2
    final c = arc.center;
    final r = arc.radius;

    // The 4 extreme points of the circle: top, bottom, left, right
    final extremes = <Coordinate>[
      Coordinate(c.x, c.y + r), // top (angle pi/2)
      Coordinate(c.x, c.y - r), // bottom (angle -pi/2)
      Coordinate(c.x - r, c.y), // left (angle pi)
      Coordinate(c.x + r, c.y), // right (angle 0)
    ];

    final startAngle = geo.angleOf(c, pt1);
    final endAngle = geo.angleOf(c, pt2);

    // Filter to extremes that lie on the arc between pt1 and pt2
    final splitPoints = <Coordinate>[];
    for (final ext in extremes) {
      final extAngle = geo.angleOf(c, ext);
      final inRange =
          geo.angleInArcRange(extAngle, startAngle, endAngle, arc.clockwise);
      if (inRange) {
        // Check it's not at the endpoints
        if (!eps.pointsSame(ext, pt1) && !eps.pointsSame(ext, pt2)) {
          splitPoints.add(ext);
        }
      }
    }

    // Build the list of points along the arc: pt1, splitPoints..., pt2
    // Sort split points by angle along the arc
    splitPoints.sort((a, b) {
      final aa = geo.angleOf(c, a);
      final ab = geo.angleOf(c, b);
      // Sort by angular distance from startAngle in the arc direction.
      // y-down: clockwise=true means atan2 angle increases.
      double distA, distB;
      if (arc.clockwise) {
        distA = aa - startAngle;
        if (distA < 0) distA += 2 * math.pi;
        distB = ab - startAngle;
        if (distB < 0) distB += 2 * math.pi;
      } else {
        distA = startAngle - aa;
        if (distA < 0) distA += 2 * math.pi;
        distB = startAngle - ab;
        if (distB < 0) distB += 2 * math.pi;
      }
      return distA.compareTo(distB);
    });

    // Create sub-arcs
    final allPoints = [pt1, ...splitPoints, pt2];
    for (int i = 0; i < allPoints.length - 1; i++) {
      final p1 = allPoints[i];
      final p2 = allPoints[i + 1];

      final forward = eps.pointsCompare(p1, p2);
      if (forward == 0) continue;

      final swapped = forward > 0;
      final start = swapped ? p2 : p1;
      final end = swapped ? p1 : p2;

      ArcData subArc = arc;
      if (swapped) {
        subArc = arc.reversed();
      }

      eventAddSegment(segmentNew(start, end, arc: subArc), true);
    }
  }

  EventNode? checkIntersection(EventNode ev1, EventNode ev2) {
    final seg1 = ev1.seg;
    final seg2 = ev2.seg;

    if (seg1.isLine && seg2.isLine) {
      return _checkLineLineIntersection(ev1, ev2);
    } else if (seg1.isArc && seg2.isLine) {
      _checkArcLineIntersection(ev1, ev2);
      return null;
    } else if (seg1.isLine && seg2.isArc) {
      _checkArcLineIntersection(ev2, ev1);
      return null;
    } else {
      _checkArcArcIntersection(ev1, ev2);
      return null;
    }
  }

  EventNode? _checkLineLineIntersection(EventNode ev1, EventNode ev2) {
    final seg1 = ev1.seg;
    final seg2 = ev2.seg;
    final a1 = seg1.start;
    final a2 = seg1.end;
    final b1 = seg2.start;
    final b2 = seg2.end;

    final intersect = eps.linesIntersect(seg1, seg2);

    if (intersect == null) {
      // Parallel or coincident
      if (!eps.pointsCollinear(a1, a2, b1)) return null;
      if (eps.pointsSame(a1, b2) || eps.pointsSame(a2, b1)) return null;

      final a1EqB1 = eps.pointsSame(a1, b1);
      final a2EqB2 = eps.pointsSame(a2, b2);

      if (a1EqB1 && a2EqB2) return ev2;

      final a1Between = !a1EqB1 && eps.pointBetween(a1, b1, b2);
      final a2Between = !a2EqB2 && eps.pointBetween(a2, b1, b2);

      if (a1EqB1) {
        if (a2Between) {
          eventDivide(ev2, a2);
        } else {
          eventDivide(ev1, b2);
        }
        return ev2;
      } else if (a1Between) {
        if (!a2EqB2) {
          if (a2Between) {
            eventDivide(ev2, a2);
          } else {
            eventDivide(ev1, b2);
          }
        }
        eventDivide(ev2, a1);
      }
    } else {
      if (intersect.alongA == 0) {
        if (intersect.alongB == -1) {
          eventDivide(ev1, b1);
        } else if (intersect.alongB == 0) {
          eventDivide(ev1, intersect.pt);
        } else if (intersect.alongB == 1) {
          eventDivide(ev1, b2);
        }
      }

      if (intersect.alongB == 0) {
        if (intersect.alongA == -1) {
          eventDivide(ev2, a1);
        } else if (intersect.alongA == 0) {
          eventDivide(ev2, intersect.pt);
        } else if (intersect.alongA == 1) {
          eventDivide(ev2, a2);
        }
      }
    }

    return null;
  }

  void _checkArcLineIntersection(EventNode arcEv, EventNode lineEv) {
    final arcSeg = arcEv.seg;
    final lineSeg = lineEv.seg;

    final points = geo.lineArcIntersection(
      lineSeg.start,
      lineSeg.end,
      arcSeg.start,
      arcSeg.end,
      arcSeg.arc!,
    );

    if (points.isEmpty) return;

    // Deduplicate near-identical points
    final unique = <Coordinate>[];
    for (final pt in points) {
      if (unique.every((u) => !eps.pointsSame(u, pt))) {
        unique.add(pt);
      }
    }

    // Sort by sweep order
    final sorted = List<Coordinate>.from(unique);
    sorted.sort((a, b) => eps.pointsCompare(a, b));

    // See _checkArcArcIntersection for the rationale: we must keep pointing
    // `curArc`/`curLine` at the right-hand piece after each split, because
    // `eventDivide(ev, pt)` shortens `ev` to [start, pt] and returns a new
    // event covering [pt, old_end]. Subsequent points lie on the new event.
    EventNode curArc = arcEv;
    EventNode curLine = lineEv;
    for (final pt in sorted) {
      // Line side
      if (!eps.pointsSame(pt, curLine.seg.start) &&
          !eps.pointsSame(pt, curLine.seg.end) &&
          eps.pointBetween(pt, curLine.seg.start, curLine.seg.end)) {
        curLine = eventDivide(curLine, pt);
      }

      // Arc side
      if (!eps.pointsSame(pt, curArc.seg.start) &&
          !eps.pointsSame(pt, curArc.seg.end) &&
          _ptBetweenArcEndpoints(pt, curArc.seg.start, curArc.seg.end)) {
        curArc = eventDivide(curArc, pt);
      }
    }
  }

  void _checkArcArcIntersection(EventNode ev1, EventNode ev2) {
    final seg1 = ev1.seg;
    final seg2 = ev2.seg;

    final points = geo.arcArcIntersection(
      seg1.start,
      seg1.end,
      seg1.arc!,
      seg2.start,
      seg2.end,
      seg2.arc!,
    );

    if (points.isEmpty) return;

    // Deduplicate near-identical points (circleCircle can return two copies of
    // the same tangent-ish point with tiny fp drift).
    final unique = <Coordinate>[];
    for (final pt in points) {
      if (unique.every((u) => !eps.pointsSame(u, pt))) {
        unique.add(pt);
      }
    }

    final sorted = List<Coordinate>.from(unique);
    sorted.sort((a, b) => eps.pointsCompare(a, b));

    // IMPORTANT: after `eventDivide(ev, pt)`, ev's segment is shortened to
    // [start, pt] and a new event covers [pt, old_end]. A subsequent interior
    // intersection lies on the NEW event, not on the shortened `ev`. We must
    // walk forward along the chain, re-pointing `ev1`/`ev2` at the right-hand
    // piece after each split. Otherwise a later `eventDivide` call on the
    // original `ev` uses `eventUpdateEnd`, which REPLACES the (already
    // shortened) end with the later point and thereby EXTENDS the segment
    // past its earlier split — producing an infinite loop as the same
    // intersection keeps recurring.
    EventNode cur1 = ev1;
    EventNode cur2 = ev2;
    for (final pt in sorted) {
      // ev1 side
      if (!eps.pointsSame(pt, cur1.seg.start) &&
          !eps.pointsSame(pt, cur1.seg.end) &&
          _ptBetweenArcEndpoints(pt, cur1.seg.start, cur1.seg.end)) {
        cur1 = eventDivide(cur1, pt);
      }
      // ev2 side
      if (!eps.pointsSame(pt, cur2.seg.start) &&
          !eps.pointsSame(pt, cur2.seg.end) &&
          _ptBetweenArcEndpoints(pt, cur2.seg.start, cur2.seg.end)) {
        cur2 = eventDivide(cur2, pt);
      }
    }
  }

  /// True when [pt] lies strictly in the sweep-order interval
  /// (start, end) — used as a cheap guard to avoid dividing at the
  /// current segment endpoints (or outside them entirely).
  bool _ptBetweenArcEndpoints(
      Coordinate pt, Coordinate start, Coordinate end) {
    final cs = eps.pointsCompare(pt, start);
    final ce = eps.pointsCompare(pt, end);
    return cs > 0 && ce < 0;
  }

  EventNode? checkBothIntersections(
      EventNode ev, EventNode? above, EventNode? below) {
    if (above != null) {
      final eve = checkIntersection(ev, above);
      if (eve != null) return eve;
    }
    if (below != null) {
      return checkIntersection(ev, below);
    }
    return null;
  }

  SegmentList calculate({bool inverted = false}) {
    if (!selfIntersection) {
      throw Exception('calculate() is only for selfIntersection mode');
    }
    return _calculateInternal(inverted, false);
  }

  SegmentList calculateCombined(
    SegmentList segments1,
    bool inverted1,
    SegmentList segments2,
    bool inverted2,
  ) {
    if (selfIntersection) {
      throw Exception(
          'calculateCombined() is only for non-selfIntersection mode');
    }

    for (final seg in segments1.segments) {
      eventAddSegment(seg, true);
    }
    for (final seg in segments2.segments) {
      eventAddSegment(seg, false);
    }

    return _calculateInternal(inverted1, inverted2);
  }

  SegmentList _calculateInternal(
      bool primaryPolyInverted, bool secondaryPolyInverted) {
    final segments = SegmentList();

    while (!eventRoot.isEmpty) {
      final ev = eventRoot.first;

      if (ev.isStart) {
        final surrounding = statusRoot.findTransition(ev, eps);
        final above = surrounding.above;
        final below = surrounding.below;

        final eve = checkBothIntersections(ev, above, below);
        if (eve != null) {
          if (selfIntersection) {
            bool toggle = true;
            if (ev.seg.myFill.below != null) {
              toggle = ev.seg.myFill.above != ev.seg.myFill.below;
            }
            if (toggle) {
              eve.seg.myFill.above = !eve.seg.myFill.above;
            }
          } else {
            eve.seg.otherFill = ev.seg.myFill;
          }

          ev.other.unlink();
          ev.unlink();
        }

        if (eventRoot.isEmpty || eventRoot.first != ev) {
          continue;
        }

        // Calculate fill flags
        if (selfIntersection) {
          bool toggle = true;
          if (ev.seg.myFill.below != null) {
            toggle = ev.seg.myFill.above != ev.seg.myFill.below;
          }

          if (below == null) {
            ev.seg.myFill.below = primaryPolyInverted;
          } else {
            ev.seg.myFill.below = below.seg.myFill.above;
          }

          if (toggle) {
            ev.seg.myFill.above =
                !(ev.seg.myFill.below ?? !ev.seg.myFill.above);
          } else {
            ev.seg.myFill.above = ev.seg.myFill.below ?? ev.seg.myFill.above;
          }
        } else {
          if (ev.seg.otherFill == null) {
            bool inside = false;
            if (below == null) {
              inside =
                  ev.primary ? secondaryPolyInverted : primaryPolyInverted;
            } else {
              if (ev.primary == below.primary) {
                inside = below.seg.otherFill!.above;
              } else {
                inside = below.seg.myFill.above;
              }
            }
            ev.seg.otherFill = SegmentFill(above: inside, below: inside);
          }
        }

        ev.other.status = surrounding.insert();
      } else {
        final st = ev.status;
        if (st == null) {
          // Zero-length segment — skip it
          ev.unlink();
          continue;
        }

        if (st.previous != null && st.next != null) {
          checkIntersection(st.previous!.ev, st.next!.ev);
        }

        st.unlink();

        if (!ev.primary) {
          final s = ev.seg.myFill;
          ev.seg.myFill = ev.seg.otherFill!;
          ev.seg.otherFill = s;
        }

        segments.add(ev.seg);
      }

      ev.unlink();
    }

    return segments;
  }
}
