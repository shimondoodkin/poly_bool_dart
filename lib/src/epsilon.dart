import 'dart:math' as math;

import 'coordinate.dart';
import 'types.dart';

/// Numerical comparison functions with configurable epsilon tolerance.
class Epsilon {
  final double eps;

  const Epsilon({this.eps = 1e-9});

  /// Is [pt] above or on the line from [left] to [right]?
  bool pointAboveOrOnLine(Coordinate pt, Coordinate left, Coordinate right) {
    final ABx = right.x - left.x;
    final ABy = right.y - left.y;
    final AB = math.sqrt(ABx * ABx + ABy * ABy);
    return ABx * (pt.y - left.y) - ABy * (pt.x - left.x) >= -eps * AB;
  }

  /// Is [p] strictly between [left] and [right] on their line?
  /// Returns false if p equals left or right.
  bool pointBetween(Coordinate p, Coordinate left, Coordinate right) {
    if (pointsSame(p, left) || pointsSame(p, right)) return false;
    final d_py_ly = p.y - left.y;
    final d_rx_lx = right.x - left.x;
    final d_px_lx = p.x - left.x;
    final d_ry_ly = right.y - left.y;

    final dot = d_px_lx * d_rx_lx + d_py_ly * d_ry_ly;
    if (dot < 0) return false;
    final sqlen = d_rx_lx * d_rx_lx + d_ry_ly * d_ry_ly;
    return dot <= sqlen;
  }

  bool pointsSameX(Coordinate p1, Coordinate p2) =>
      (p1.x - p2.x).abs() < eps;

  bool pointsSameY(Coordinate p1, Coordinate p2) =>
      (p1.y - p2.y).abs() < eps;

  bool pointsSame(Coordinate p1, Coordinate p2) =>
      pointsSameX(p1, p2) && pointsSameY(p1, p2);

  /// Compare points for sweep-line ordering: first by x, then by y.
  /// Returns -1 if p1 < p2, 1 if p1 > p2, 0 if same.
  int pointsCompare(Coordinate p1, Coordinate p2) {
    if (pointsSameX(p1, p2)) {
      return pointsSameY(p1, p2) ? 0 : (p1.y < p2.y ? -1 : 1);
    }
    return p1.x < p2.x ? -1 : 1;
  }

  /// Are three points collinear?
  bool pointsCollinear(Coordinate pt1, Coordinate pt2, Coordinate pt3) {
    final dx1 = pt1.x - pt2.x;
    final dy1 = pt1.y - pt2.y;
    final dx2 = pt2.x - pt3.x;
    final dy2 = pt2.y - pt3.y;
    final n1 = math.sqrt(dx1 * dx1 + dy1 * dy1);
    final n2 = math.sqrt(dx2 * dx2 + dy2 * dy2);
    return (dx1 * dy2 - dx2 * dy1).abs() <= eps * (n1 + n2);
  }

  /// Line-line intersection. Returns null if segments are parallel/coincident.
  Intersection? linesIntersect(Segment a, Segment b) {
    final a0 = a.start;
    final a1 = a.end;
    final b0 = b.start;
    final b1 = b.end;

    final adx = a1.x - a0.x;
    final ady = a1.y - a0.y;
    final bdx = b1.x - b0.x;
    final bdy = b1.y - b0.y;

    final axb = adx * bdy - ady * bdx;
    final n1 = math.sqrt(adx * adx + ady * ady);
    final n2 = math.sqrt(bdx * bdx + bdy * bdy);
    if (axb.abs() <= eps * (n1 + n2)) {
      return null;
    }

    final dx = a0.x - b0.x;
    final dy = a0.y - b0.y;

    final A = (bdx * dy - bdy * dx) / axb;
    final B = (adx * dy - ady * dx) / axb;

    final pt = Coordinate(a0.x + A * adx, a0.y + A * ady);
    final intersection = Intersection(alongA: 0, alongB: 0, pt: pt);

    if (pointsSame(pt, a0)) {
      intersection.alongA = -1;
    } else if (pointsSame(pt, a1)) {
      intersection.alongA = 1;
    } else if (A < 0) {
      intersection.alongA = -2;
    } else if (A > 1) {
      intersection.alongA = 2;
    }

    if (pointsSame(pt, b0)) {
      intersection.alongB = -1;
    } else if (pointsSame(pt, b1)) {
      intersection.alongB = 1;
    } else if (B < 0) {
      intersection.alongB = -2;
    } else if (B > 1) {
      intersection.alongB = 2;
    }

    return intersection;
  }
}
