import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:poly_bool_arcs/poly_bool_arcs.dart';

void main() => runApp(const PlaygroundApp());

class PlaygroundApp extends StatelessWidget {
  const PlaygroundApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'poly_bool_arcs Playground',
      theme: ThemeData(useMaterial3: true),
      home: const PlaygroundPage(),
    );
  }
}

class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});
  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

/// Identifies a single vertex within a polygon's region. A selection
/// implicitly refers to both this vertex and the incoming segment
/// (from the previous vertex to this one).
class Selection {
  final int regionIndex;
  final int vertexIndex;
  const Selection(this.regionIndex, this.vertexIndex);
}

enum BoolOp {
  union('union'),
  intersect('intersect'),
  difference('difference'),
  xor('xor');

  final String label;
  const BoolOp(this.label);
}

/// Initial polygons: two non-overlapping axis-aligned rectangles
/// (all line segments). Winding CCW in screen coords (y-down) so the
/// library treats them as filled shapes.
ArcPolygon _initialPolygonA() => ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(80, 80)),
        ArcVertex(point: Coordinate(240, 80)),
        ArcVertex(point: Coordinate(240, 200)),
        ArcVertex(point: Coordinate(80, 200)),
      ]),
    ]);

ArcPolygon _initialPolygonB() => ArcPolygon(regions: [
      ArcRegion([
        ArcVertex(point: Coordinate(320, 240)),
        ArcVertex(point: Coordinate(520, 240)),
        ArcVertex(point: Coordinate(520, 380)),
        ArcVertex(point: Coordinate(320, 380)),
      ]),
    ]);

/// Paints one or more polygons onto a canvas. For each region, walks the
/// vertex list, drawing LineSegment edges and Arc edges (via
/// Canvas.arcToPoint). Also draws a small square at each vertex.
class PolygonPainter extends CustomPainter {
  final List<({ArcPolygon polygon, Color color})> polygons;
  final Selection? selection;
  final bool selectionOnFirst;

  const PolygonPainter({
    required this.polygons,
    this.selection,
    this.selectionOnFirst = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int pi = 0; pi < polygons.length; pi++) {
      final p = polygons[pi];
      final stroke = Paint()
        ..color = p.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      _drawPolygon(canvas, p.polygon, stroke);
      _drawVertexHandles(
          canvas, p.polygon, p.color, _isSelectedOnThisPolygon(pi));
    }
    _drawSelectedSegmentOverlay(canvas);
  }

  bool _isSelectedOnThisPolygon(int polygonIndex) {
    if (selection == null) return false;
    return (polygonIndex == 0) == selectionOnFirst;
  }

  void _drawPolygon(Canvas canvas, ArcPolygon poly, Paint paint) {
    for (final region in poly.regions) {
      final verts = region.vertices;
      if (verts.isEmpty) continue;
      final path = ui.Path()..moveTo(verts[0].point.x, verts[0].point.y);
      for (int i = 0; i < verts.length; i++) {
        final v = verts[i];
        final next = verts[(i + 1) % verts.length];
        final arc = v.arcToNext;
        if (arc == null) {
          path.lineTo(next.point.x, next.point.y);
        } else {
          path.arcToPoint(
            Offset(next.point.x, next.point.y),
            radius: Radius.circular(arc.radius),
            clockwise: arc.clockwise,
            largeArc: _isLargeArc(v.point, next.point, arc),
          );
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  bool _isLargeArc(Coordinate a, Coordinate b, ArcData arc) {
    final a1 = math.atan2(a.y - arc.center.y, a.x - arc.center.x);
    final a2 = math.atan2(b.y - arc.center.y, b.x - arc.center.x);
    double delta = a2 - a1;
    if (arc.clockwise) {
      while (delta <= 0) delta += 2 * math.pi;
    } else {
      while (delta >= 0) delta -= 2 * math.pi;
    }
    return delta.abs() > math.pi;
  }

  void _drawVertexHandles(
      Canvas canvas, ArcPolygon poly, Color color, bool selectionHere) {
    for (int ri = 0; ri < poly.regions.length; ri++) {
      final verts = poly.regions[ri].vertices;
      for (int vi = 0; vi < verts.length; vi++) {
        final isSelectedVertex = selectionHere &&
            selection != null &&
            selection!.regionIndex == ri &&
            selection!.vertexIndex == vi;
        final prevIndex = (vi - 1 + verts.length) % verts.length;
        final isPreviousVertex = selectionHere &&
            selection != null &&
            selection!.regionIndex == ri &&
            selection!.vertexIndex == prevIndex;
        _drawHandle(canvas, verts[vi].point, color,
            filled: isSelectedVertex, highlighted: isPreviousVertex);
      }
    }
  }

  void _drawHandle(Canvas canvas, Coordinate c, Color color,
      {required bool filled, required bool highlighted}) {
    const size = 8.0;
    final rect = Rect.fromCenter(
        center: Offset(c.x, c.y), width: size, height: size);
    if (filled) {
      canvas.drawRect(rect, Paint()..color = color);
    } else {
      canvas.drawRect(
          rect,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = highlighted ? 2.5 : 1.5);
    }
  }

  void _drawSelectedSegmentOverlay(Canvas canvas) {
    if (selection == null || polygons.isEmpty) return;
    final poly = selectionOnFirst ? polygons.first : polygons.last;
    final verts = poly.polygon.regions[selection!.regionIndex].vertices;
    final selVi = selection!.vertexIndex;
    final prevVi = (selVi - 1 + verts.length) % verts.length;
    final v0 = verts[prevVi];
    final v1 = verts[selVi];
    final stroke = Paint()
      ..color = poly.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    final arc = v0.arcToNext;
    final path = ui.Path()..moveTo(v0.point.x, v0.point.y);
    if (arc == null) {
      path.lineTo(v1.point.x, v1.point.y);
    } else {
      path.arcToPoint(
        Offset(v1.point.x, v1.point.y),
        radius: Radius.circular(arc.radius),
        clockwise: arc.clockwise,
        largeArc: _isLargeArc(v0.point, v1.point, arc),
      );
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant PolygonPainter old) =>
      old.polygons != polygons ||
      old.selection != selection ||
      old.selectionOnFirst != selectionOnFirst;
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  late ArcPolygon _a = _initialPolygonA();
  late ArcPolygon _b = _initialPolygonB();
  BoolOp _op = BoolOp.intersect;

  /// Selection in the input canvas. null = nothing selected.
  Selection? _inputSelection;
  bool _inputSelectionOnA = true; // which polygon the selection belongs to

  /// Selection in the result canvas (read-only). null = nothing selected.
  Selection? _resultSelection;

  static const double _vertexHitRadius = 10.0;

  /// Returns the selection for the vertex nearest to [tap] within hit
  /// radius, searching A then B. Returns null if no vertex is close.
  ({bool onA, Selection sel})? _hitTestVertex(Offset tap) {
    ({bool onA, Selection sel})? best;
    double bestD = _vertexHitRadius;
    void test(ArcPolygon p, bool onA) {
      for (int ri = 0; ri < p.regions.length; ri++) {
        final verts = p.regions[ri].vertices;
        for (int vi = 0; vi < verts.length; vi++) {
          final d = (tap - Offset(verts[vi].point.x, verts[vi].point.y))
              .distance;
          if (d < bestD) {
            bestD = d;
            best = (onA: onA, sel: Selection(ri, vi));
          }
        }
      }
    }
    test(_a, true);
    test(_b, false);
    return best;
  }

  ArcPolygon _withMovedVertex(ArcPolygon p, Selection s, Offset newPos) {
    final regions = List<ArcRegion>.of(p.regions);
    final verts = List<ArcVertex>.of(regions[s.regionIndex].vertices);
    final old = verts[s.vertexIndex];
    verts[s.vertexIndex] =
        ArcVertex(point: Coordinate(newPos.dx, newPos.dy), arcToNext: old.arcToNext);
    regions[s.regionIndex] = ArcRegion(verts);
    return ArcPolygon(regions: regions, inverted: p.inverted);
  }

  bool _draggingVertex = false;

  /// Winding-number test using the polygon's sampled vertex list. Ignores
  /// arc curvature; good enough for hit-testing an interior grab point.
  bool _pointInPolygon(ArcPolygon p, Offset pt) {
    for (final region in p.regions) {
      final verts = region.vertices;
      if (verts.length < 3) continue;
      int inside = 0;
      for (int i = 0; i < verts.length; i++) {
        final a = verts[i].point;
        final b = verts[(i + 1) % verts.length].point;
        final intersects =
            ((a.y > pt.dy) != (b.y > pt.dy)) &&
                (pt.dx < (b.x - a.x) * (pt.dy - a.y) / (b.y - a.y) + a.x);
        if (intersects) inside = 1 - inside;
      }
      if (inside == 1) return true;
    }
    return false;
  }

  ArcPolygon _translatePolygon(ArcPolygon p, Offset delta) {
    final regions = p.regions.map((r) {
      final verts = r.vertices.map((v) {
        final np = Coordinate(v.point.x + delta.dx, v.point.y + delta.dy);
        final na = v.arcToNext == null
            ? null
            : ArcData(
                center: Coordinate(v.arcToNext!.center.x + delta.dx,
                    v.arcToNext!.center.y + delta.dy),
                radius: v.arcToNext!.radius,
                clockwise: v.arcToNext!.clockwise);
        return ArcVertex(point: np, arcToNext: na);
      }).toList();
      return ArcRegion(verts);
    }).toList();
    return ArcPolygon(regions: regions, inverted: p.inverted);
  }

  bool _draggingPolygonA = false;
  bool _draggingPolygonB = false;
  Offset _lastDragPos = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('poly_bool_arcs Playground')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Input', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SizedBox(
              width: 600,
              height: 400,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: GestureDetector(
                  onTapDown: (d) {
                    final hit = _hitTestVertex(d.localPosition);
                    if (hit == null) return;
                    setState(() {
                      _inputSelection = hit.sel;
                      _inputSelectionOnA = hit.onA;
                    });
                  },
                  onPanStart: (d) {
                    final vhit = _hitTestVertex(d.localPosition);
                    if (vhit != null) {
                      setState(() {
                        _inputSelection = vhit.sel;
                        _inputSelectionOnA = vhit.onA;
                      });
                      _draggingVertex = true;
                      _draggingPolygonA = false;
                      _draggingPolygonB = false;
                      return;
                    }
                    if (_pointInPolygon(_a, d.localPosition)) {
                      _draggingPolygonA = true;
                      _draggingPolygonB = false;
                      _draggingVertex = false;
                      _lastDragPos = d.localPosition;
                      return;
                    }
                    if (_pointInPolygon(_b, d.localPosition)) {
                      _draggingPolygonB = true;
                      _draggingPolygonA = false;
                      _draggingVertex = false;
                      _lastDragPos = d.localPosition;
                      return;
                    }
                    _draggingVertex = false;
                    _draggingPolygonA = false;
                    _draggingPolygonB = false;
                  },
                  onPanUpdate: (d) {
                    if (_draggingVertex && _inputSelection != null) {
                      setState(() {
                        if (_inputSelectionOnA) {
                          _a = _withMovedVertex(_a, _inputSelection!, d.localPosition);
                        } else {
                          _b = _withMovedVertex(_b, _inputSelection!, d.localPosition);
                        }
                      });
                    } else if (_draggingPolygonA) {
                      final delta = d.localPosition - _lastDragPos;
                      setState(() => _a = _translatePolygon(_a, delta));
                      _lastDragPos = d.localPosition;
                    } else if (_draggingPolygonB) {
                      final delta = d.localPosition - _lastDragPos;
                      setState(() => _b = _translatePolygon(_b, delta));
                      _lastDragPos = d.localPosition;
                    }
                  },
                  onPanEnd: (_) {
                    _draggingVertex = false;
                    _draggingPolygonA = false;
                    _draggingPolygonB = false;
                  },
                  child: CustomPaint(
                    painter: PolygonPainter(
                      polygons: [
                        (polygon: _a, color: Colors.blue.shade700),
                        (polygon: _b, color: Colors.orange.shade800),
                      ],
                      selection: _inputSelection,
                      selectionOnFirst: _inputSelectionOnA,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
