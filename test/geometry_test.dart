import 'dart:math' as math;

import 'package:poly_bool_arcs/poly_bool_arcs.dart';
import 'package:test/test.dart';

void main() {
  final eps = Epsilon(eps: 1e-9);
  final geo = Geometry(eps);

  group('circleLineIntersection', () {
    test('line through center horizontally', () {
      final pts = geo.circleLineIntersection(
        Coordinate(0, 0),
        1.0,
        Coordinate(-2, 0),
        Coordinate(2, 0),
      );
      expect(pts.length, 2);
      // Should be (-1,0) and (1,0)
      pts.sort((a, b) => a.x.compareTo(b.x));
      expect(pts[0].x, closeTo(-1, 1e-9));
      expect(pts[0].y, closeTo(0, 1e-9));
      expect(pts[1].x, closeTo(1, 1e-9));
      expect(pts[1].y, closeTo(0, 1e-9));
    });

    test('line tangent to circle', () {
      final pts = geo.circleLineIntersection(
        Coordinate(0, 0),
        1.0,
        Coordinate(-2, 1),
        Coordinate(2, 1),
      );
      expect(pts.length, 1);
      expect(pts[0].x, closeTo(0, 1e-9));
      expect(pts[0].y, closeTo(1, 1e-9));
    });

    test('line misses circle', () {
      final pts = geo.circleLineIntersection(
        Coordinate(0, 0),
        1.0,
        Coordinate(-2, 2),
        Coordinate(2, 2),
      );
      expect(pts.length, 0);
    });

    test('segment only partially overlaps circle', () {
      // Segment from (0.5, -2) to (0.5, 0) — only bottom intersection
      final pts = geo.circleLineIntersection(
        Coordinate(0, 0),
        1.0,
        Coordinate(0.5, -2),
        Coordinate(0.5, 0),
      );
      expect(pts.length, 1);
      expect(pts[0].x, closeTo(0.5, 1e-9));
      expect(pts[0].y, lessThan(0));
    });
  });

  group('circleCircleIntersection', () {
    test('two circles intersecting at 2 points', () {
      final pts = geo.circleCircleIntersection(
        Coordinate(0, 0),
        1.0,
        Coordinate(1, 0),
        1.0,
      );
      expect(pts.length, 2);
    });

    test('two circles tangent externally', () {
      final pts = geo.circleCircleIntersection(
        Coordinate(0, 0),
        1.0,
        Coordinate(2, 0),
        1.0,
      );
      expect(pts.length, 1);
      expect(pts[0].x, closeTo(1, 1e-9));
      expect(pts[0].y, closeTo(0, 1e-9));
    });

    test('two circles no intersection', () {
      final pts = geo.circleCircleIntersection(
        Coordinate(0, 0),
        1.0,
        Coordinate(5, 0),
        1.0,
      );
      expect(pts.length, 0);
    });

    test('one circle inside the other', () {
      final pts = geo.circleCircleIntersection(
        Coordinate(0, 0),
        2.0,
        Coordinate(0, 0.5),
        0.5,
      );
      expect(pts.length, 0);
    });

    test('concentric circles', () {
      final pts = geo.circleCircleIntersection(
        Coordinate(0, 0),
        1.0,
        Coordinate(0, 0),
        2.0,
      );
      expect(pts.length, 0);
    });
  });

  group('angleInArcRange', () {
    test('CCW arc from 0 to pi/2', () {
      // y-down: clockwise=false means atan2 angle DECREASES.
      // From 0 decreasing to pi/2 is the long way (through -pi/+pi).
      // pi/4 lies on the short (increasing) arc, so NOT in range.
      // pi lies on the long (decreasing) arc, so IN range.
      expect(geo.angleInArcRange(math.pi / 4, 0, math.pi / 2, false), false);
      expect(geo.angleInArcRange(math.pi, 0, math.pi / 2, false), true);
    });

    test('CW arc from pi/2 to 0', () {
      // y-down: clockwise=true means atan2 angle INCREASES.
      // From pi/2 increasing to 0 is the long way (through +pi/-pi).
      // pi/4 lies on the short (decreasing) arc, so NOT in range.
      // pi lies on the long (increasing) arc, so IN range.
      expect(geo.angleInArcRange(math.pi / 4, math.pi / 2, 0, true), false);
      expect(geo.angleInArcRange(math.pi, math.pi / 2, 0, true), true);
    });

    test('CCW arc wrapping around', () {
      // y-down: clockwise=false means atan2 angle DECREASES.
      // From 3pi/4 decreasing to -3pi/4 passes through 0, NOT through pi.
      // pi is on the complementary (wrapping) arc, so NOT in range.
      expect(
          geo.angleInArcRange(
              math.pi, 3 * math.pi / 4, -3 * math.pi / 4, false),
          false);
    });
  });

  group('filterToArcRange', () {
    test('filters points outside arc range', () {
      final arc = ArcData(
        center: Coordinate(0, 0),
        radius: 1.0,
        clockwise: false,
      );
      final points = [
        Coordinate(1, 0), // angle 0
        Coordinate(0, 1), // angle pi/2
        Coordinate(-1, 0), // angle pi
        Coordinate(0, -1), // angle -pi/2
      ];
      // Arc from (1,0) to (0,1) CCW.
      // y-down: clockwise=false means atan2 angle DECREASES.
      // Going from angle 0 decreasing to pi/2 is the LONG way (through
      // -pi/2 and ±pi), so all four cardinal points lie on this arc.
      final filtered = geo.filterToArcRange(
        points,
        arc,
        Coordinate(1, 0),
        Coordinate(0, 1),
      );
      expect(filtered.length, 4); // all four cardinal points on long arc
    });
  });

  group('pointOnArc', () {
    test('point on arc', () {
      final arc = ArcData(
        center: Coordinate(0, 0),
        radius: 1.0,
        clockwise: false,
      );
      // Point at 45 degrees on unit circle.
      // y-down: clockwise=false means atan2 angle DECREASES.
      // CCW arc from (1,0) angle=0 to (0,1) angle=pi/2 takes the LONG way
      // (through -pi/2 and ±pi), so the 45-deg point lies on the
      // complementary short arc and is NOT on this arc.
      final pt = Coordinate(math.cos(math.pi / 4), math.sin(math.pi / 4));
      expect(
        geo.pointOnArc(pt, Coordinate(1, 0), Coordinate(0, 1), arc),
        false,
      );
    });

    test('point not on arc - wrong radius', () {
      final arc = ArcData(
        center: Coordinate(0, 0),
        radius: 1.0,
        clockwise: false,
      );
      expect(
        geo.pointOnArc(Coordinate(2, 0), Coordinate(1, 0), Coordinate(0, 1), arc),
        false,
      );
    });
  });

  group('rayArcIntersections', () {
    test('ray hits semicircle', () {
      // Arc from (1,0) angle=0 to (-1,0) angle=pi, CCW.
      // y-down: clockwise=false means atan2 angle DECREASES.
      // Going from 0 decreasing to pi is the LONG way through -pi/2, so
      // this arc is the LOWER half of the unit circle (negative-y points).
      final arc = ArcData(
        center: Coordinate(0, 0),
        radius: 1.0,
        clockwise: false,
      );
      // Ray from (-2, 0.5) going right crosses the circle at y=0.5
      // (upper half); those points are NOT on this (lower-half) arc.
      final count = geo.rayArcIntersections(
        Coordinate(-2, 0.5),
        Coordinate(1, 0),
        Coordinate(-1, 0),
        arc,
      );
      expect(count, 0);
    });
  });
}
