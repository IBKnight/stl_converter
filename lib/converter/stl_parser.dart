import 'dart:io';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';

class Triangle {
  final Vector3 normal;
  final Vector3 v1;
  final Vector3 v2;
  final Vector3 v3;

  Triangle(this.normal, this.v1, this.v2, this.v3);
}

class StlParser {
  static Future<List<Triangle>> parse(File file) async {
    final bytes = await file.readAsBytes();
    final isAscii = _isAscii(bytes);

    return isAscii ? _parseAscii(String.fromCharCodes(bytes)) : _parseBinary(bytes);
  }

  static bool _isAscii(Uint8List bytes) {
    final header = String.fromCharCodes(bytes.take(80).toList()).toLowerCase();
    return header.contains('solid');
  }

  static List<Triangle> _parseAscii(String content) {
    final triangleRegex = RegExp(
      r'facet normal\s+([-\d\.eE]+)\s+([-\d\.eE]+)\s+([-\d\.eE]+)\s+outer loop\s+vertex\s+([-\d\.eE]+)\s+([-\d\.eE]+)\s+([-\d\.eE]+)\s+vertex\s+([-\d\.eE]+)\s+([-\d\.eE]+)\s+([-\d\.eE]+)\s+vertex\s+([-\d\.eE]+)\s+([-\d\.eE]+)\s+([-\d\.eE]+)\s+endloop\s+endfacet',
      multiLine: true,
    );

    final triangles = <Triangle>[];

    for (final match in triangleRegex.allMatches(content)) {
      final normal = Vector3(
        double.parse(match.group(1)!),
        double.parse(match.group(2)!),
        double.parse(match.group(3)!),
      );

      final v1 = Vector3(
        double.parse(match.group(4)!),
        double.parse(match.group(5)!),
        double.parse(match.group(6)!),
      );

      final v2 = Vector3(
        double.parse(match.group(7)!),
        double.parse(match.group(8)!),
        double.parse(match.group(9)!),
      );

      final v3 = Vector3(
        double.parse(match.group(10)!),
        double.parse(match.group(11)!),
        double.parse(match.group(12)!),
      );

      triangles.add(Triangle(normal, v1, v2, v3));
    }

    return triangles;
  }

  static List<Triangle> _parseBinary(Uint8List bytes) {
    final triangles = <Triangle>[];
    final count = ByteData.sublistView(bytes, 80, 84).getUint32(0, Endian.little);
    var offset = 84;

    for (var i = 0; i < count; i++) {
      final normal = _readVector3(bytes, offset);
      final v1 = _readVector3(bytes, offset + 12);
      final v2 = _readVector3(bytes, offset + 24);
      final v3 = _readVector3(bytes, offset + 36);

      triangles.add(Triangle(normal, v1, v2, v3));
      offset += 50; // 12*4 bytes + 2 bytes attribute byte count
    }

    return triangles;
  }

  static Vector3 _readVector3(Uint8List bytes, int offset) {
    final data = ByteData.sublistView(bytes, offset, offset + 12);
    return Vector3(
      data.getFloat32(0, Endian.little),
      data.getFloat32(4, Endian.little),
      data.getFloat32(8, Endian.little),
    );
  }
}
