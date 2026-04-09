import 'dart:math' as math;

/// A 2D point/coordinate.
class Coordinate {
  final double x;
  final double y;

  const Coordinate(this.x, this.y);

  Coordinate operator +(Coordinate other) =>
      Coordinate(x + other.x, y + other.y);
  Coordinate operator -(Coordinate other) =>
      Coordinate(x - other.x, y - other.y);
  Coordinate operator *(double s) => Coordinate(x * s, y * s);

  double dot(Coordinate other) => x * other.x + y * other.y;
  double cross(Coordinate other) => x * other.y - y * other.x;
  double get lengthSquared => x * x + y * y;
  double get length => math.sqrt(lengthSquared);

  @override
  String toString() => '($x, $y)';

  @override
  bool operator ==(Object other) =>
      other is Coordinate && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}
