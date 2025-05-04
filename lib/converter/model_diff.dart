import 'package:vector_math/vector_math.dart';
import 'stl_parser.dart' as stl;

class DiffResult {
  final List<stl.Triangle> unchanged;
  final List<stl.Triangle> added;

  DiffResult({
    required this.unchanged,
    required this.added,
  });
}

class ModelDiffer {
  /// Сравнивает старую и новую модель, возвращая отличающиеся треугольники
  static DiffResult compareModels(List<stl.Triangle> oldModel, List<stl.Triangle> newModel, {double tolerance = 1e-6}) {
    final oldHashes = <_TriangleHash>{};
    final unchanged = <stl.Triangle>[];
    final added = <stl.Triangle>[];

    for (final tri in oldModel) {
      oldHashes.add(_TriangleHash.fromTriangle(tri, tolerance));
    }

    for (final tri in newModel) {
      final hash = _TriangleHash.fromTriangle(tri, tolerance);
      if (oldHashes.contains(hash)) {
        unchanged.add(tri);
      } else {
        added.add(tri);
      }
    }

    return DiffResult(unchanged: unchanged, added: added);
  }
}

class _TriangleHash {
  final List<Vector3> sortedVertices;

  _TriangleHash(this.sortedVertices);

  factory _TriangleHash.fromTriangle(stl.Triangle tri, double epsilon) {
    final verts = [tri.v1, tri.v2, tri.v3];

    // Округление координат до заданного допуска
    final rounded = verts.map((v) {
      return Vector3(
        (v.x / epsilon).roundToDouble(),
        (v.y / epsilon).roundToDouble(),
        (v.z / epsilon).roundToDouble(),
      );
    }).toList();

    // Сортируем вершины, чтобы порядок не влиял
    rounded.sort((a, b) {
      final cmpX = a.x.compareTo(b.x);
      if (cmpX != 0) return cmpX;
      final cmpY = a.y.compareTo(b.y);
      if (cmpY != 0) return cmpY;
      return a.z.compareTo(b.z);
    });

    return _TriangleHash(rounded);
  }

  @override
  bool operator ==(Object other) {
    if (other is! _TriangleHash) return false;
    for (int i = 0; i < 3; i++) {
      if ((sortedVertices[i] - other.sortedVertices[i]).length > 1e-5) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return sortedVertices.fold(0, (prev, v) =>
        prev ^ v.x.hashCode ^ v.y.hashCode ^ v.z.hashCode);
  }
}
