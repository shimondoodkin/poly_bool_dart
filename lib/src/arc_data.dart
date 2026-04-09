import 'coordinate.dart';

/// Arc metadata for a segment. When present on a segment, the edge
/// from start to end follows a circular arc through this center/radius
/// instead of a straight line.
class ArcData {
  final Coordinate center;
  final double radius;
  final bool clockwise;

  const ArcData({
    required this.center,
    required this.radius,
    required this.clockwise,
  });

  /// Returns a copy with the direction reversed.
  ArcData reversed() => ArcData(
        center: center,
        radius: radius,
        clockwise: !clockwise,
      );

  @override
  String toString() =>
      'ArcData(center: $center, r: $radius, cw: $clockwise)';

  @override
  bool operator ==(Object other) =>
      other is ArcData &&
      center == other.center &&
      radius == other.radius &&
      clockwise == other.clockwise;

  @override
  int get hashCode => Object.hash(center, radius, clockwise);
}
