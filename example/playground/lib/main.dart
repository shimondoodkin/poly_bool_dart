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

class _PlaygroundPageState extends State<PlaygroundPage> {
  late ArcPolygon _a = _initialPolygonA();
  late ArcPolygon _b = _initialPolygonB();
  BoolOp _op = BoolOp.intersect;

  /// Selection in the input canvas. null = nothing selected.
  Selection? _inputSelection;
  bool _inputSelectionOnA = true; // which polygon the selection belongs to

  /// Selection in the result canvas (read-only). null = nothing selected.
  Selection? _resultSelection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('poly_bool_arcs Playground')),
      body: Center(
        child: Text(
          'A has ${_a.regions[0].vertices.length} verts · '
          'B has ${_b.regions[0].vertices.length} verts · op=$_op',
        ),
      ),
    );
  }
}
