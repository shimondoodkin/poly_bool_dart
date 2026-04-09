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
      expect(geo.angleInArcRange(math.pi / 4, 0, math.pi / 2, false), true);
      expect(geo.angleInArcRange(math.pi, 0, math.pi / 2, false), false);
    });

    test('CW arc from pi/2 to 0', () {
      expect(geo.angleInArcRange(math.pi / 4, math.pi / 2, 0, true), true);
      expect(geo.angleInArcRange(math.pi, math.pi / 2, 0, true), false);
    });

    test('CCW arc wrapping around', () {
      // From 3pi/4 to -3pi/4 CCW — this wraps around through pi
      expect(
          geo.angleInArcRange(
              math.pi, 3 * math.pi / 4, -3 * math.pi / 4, false),
          true);
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
      // Arc from (1,0) to (0,1) CCW — covers 0 to pi/2
      final filtered = geo.filterToArcRange(
        points,
        arc,
        Coordinate(1, 0),
        Coordinate(0, 1),
      );
      expect(filtered.length, 2); // (1,0) and (0,1)
    });
  });

  group('pointOnArc', () {
    test('point on arc', () {
      final arc = ArcData(
        center: Coordinate(0, 0),
        radius: 1.0,
        clockwise: false,
      );
      // Point at 45 degrees on unit circle
      final pt = Coordinate(math.cos(math.pi / 4), math.sin(math.pi / 4));
      expect(
        geo.pointOnArc(pt, Coordinate(1, 0), Coordinate(0, 1), arc),
        true,
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
      // Upper semicircle from (1,0) to (-1,0) CCW
      final arc = ArcData(
        center: Coordinate(0, 0),
        radius: 1.0,
        clockwise: false,
      );
      // Ray from (-2, 0.5) going right should hit the arc
      final count = geo.rayArcIntersections(
        Coordinate(-2, 0.5),
        Coordinate(1, 0),
        Coordinate(-1, 0),
        arc,
      );
      expect(count, greaterThan(0));
    });
  });
}
