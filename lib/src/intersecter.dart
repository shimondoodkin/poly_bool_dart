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
        // Arc segment — split at y-extremes for sweep-line correctness
        _addArcSubSegments(pt1, pt2, arc);
      }
    }
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

      // ignore: avoid_print
      print('[TRACE subArc EMIT] swapped=$swapped '
          'origCW=${arc.clockwise} subArcCW=${subArc.clockwise} '
          'start=(${start.x}, ${start.y}) end=(${end.x}, ${end.y}) '
          'center=(${arc.center.x}, ${arc.center.y}) r=${arc.radius}');

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

    // Sort by sweep order
    final sorted = List<Coordinate>.from(points);
    sorted.sort((a, b) => eps.pointsCompare(a, b));

    for (final pt in sorted) {
      final atArcStart = eps.pointsSame(pt, arcEv.seg.start);
      final atArcEnd = eps.pointsSame(pt, arcEv.seg.end);
      final atLineStart = eps.pointsSame(pt, lineEv.seg.start);
      final atLineEnd = eps.pointsSame(pt, lineEv.seg.end);

      // Split the line if the point is strictly inside it
      if (!atLineStart && !atLineEnd &&
          eps.pointBetween(pt, lineEv.seg.start, lineEv.seg.end)) {
        eventDivide(lineEv, pt);
      }

      // Split the arc if the point is strictly inside it
      if (!atArcStart && !atArcEnd) {
        eventDivide(arcEv, pt);
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

    final sorted = List<Coordinate>.from(points);
    sorted.sort((a, b) => eps.pointsCompare(a, b));

    for (final pt in sorted) {
      if (!eps.pointsSame(pt, ev1.seg.start) &&
          !eps.pointsSame(pt, ev1.seg.end)) {
        eventDivide(ev1, pt);
      }
      if (!eps.pointsSame(pt, ev2.seg.start) &&
          !eps.pointsSame(pt, ev2.seg.end)) {
        eventDivide(ev2, pt);
      }
    }
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
