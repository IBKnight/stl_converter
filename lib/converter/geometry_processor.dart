import 'package:vector_math/vector_math.dart';
import 'stl_parser.dart' as stl;

class MeshData {
  final List<Vector3> positions;
  final List<Vector3> normals;
  final List<int> indices;

  MeshData({
    required this.positions,
    required this.normals,
    required this.indices,
  });
}

class GeometryProcessor {
  /// Угол в градусах: всё ниже будет сглажено.
  static const double smoothAngleThresholdDeg = 45.0;

  static MeshData process(List<stl.Triangle> triangles, {bool recalculateNormals = true}) {
    final vertexMap = <_VertexKey, int>{};
    final positions = <Vector3>[];
    final normals = <Vector3>[];
    final indices = <int>[];

    final angleThreshold = radians(smoothAngleThresholdDeg);
    final epsilon = 1e-6;

    int _findOrAddVertex(Vector3 position, Vector3 normal) {
      for (var i = 0; i < positions.length; i++) {
        if ((positions[i] - position).length < epsilon &&
            normals[i].angleTo(normal).abs() < angleThreshold) {
          return i;
        }
      }
      positions.add(position);
      normals.add(normal.clone());
      return positions.length - 1;
    }

    for (final tri in triangles) {
      final faceNormal = recalculateNormals
          ? _calculateFaceNormal(tri.v1, tri.v2, tri.v3)
          : tri.normal.normalized();

      final i1 = _findOrAddVertex(tri.v1, faceNormal);
      final i2 = _findOrAddVertex(tri.v2, faceNormal);
      final i3 = _findOrAddVertex(tri.v3, faceNormal);

      indices.addAll([i1, i2, i3]);

      if (recalculateNormals) {
        normals[i1] += faceNormal;
        normals[i2] += faceNormal;
        normals[i3] += faceNormal;
      }
    }

    if (recalculateNormals) {
      for (int i = 0; i < normals.length; i++) {
        normals[i].normalize();
      }
    }

    return MeshData(
      positions: positions,
      normals: normals,
      indices: indices,
    );
  }

  static Vector3 _calculateFaceNormal(Vector3 v1, Vector3 v2, Vector3 v3) {
    final edge1 = v2 - v1;
    final edge2 = v3 - v1;
    return edge1.cross(edge2).normalized();
  }
}

class _VertexKey {
  final Vector3 position;
  final Vector3 normal;

  _VertexKey(this.position, this.normal);

  @override
  bool operator ==(Object other) {
    if (other is! _VertexKey) return false;
    return (position - other.position).length < 1e-6 &&
           normal.angleTo(other.normal).abs() < radians(1.0);
  }

  @override
  int get hashCode => position.hashCode ^ normal.hashCode;
}
