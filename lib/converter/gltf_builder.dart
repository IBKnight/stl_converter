import 'dart:convert';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';

import 'geometry_processor.dart';

class GltfAsset {
  final Map<String, dynamic> json;
  final Uint8List? binary;
  final bool isGlb;

  GltfAsset({
    required this.json,
    required this.binary,
    this.isGlb = false,
  });
}

class GltfBuilder {
  static GltfAsset build(MeshData mesh, {bool asGlb = false}) {
    final positions = _vec3ListToFloat32List(mesh.positions);
    final normals = _vec3ListToFloat32List(mesh.normals);
    final indices = Uint16List.fromList(mesh.indices);

    final positionOffset = 0;
    final normalOffset = positionOffset + positions.lengthInBytes;
    final indexOffset = _alignTo4(normalOffset + normals.lengthInBytes);
    final totalLength = _alignTo4(indexOffset + indices.lengthInBytes);

    final bufferData = Uint8List(totalLength);
    bufferData.setRange(positionOffset, positionOffset + positions.lengthInBytes, positions.buffer.asUint8List());
    bufferData.setRange(normalOffset, normalOffset + normals.lengthInBytes, normals.buffer.asUint8List());
    bufferData.setRange(indexOffset, indexOffset + indices.lengthInBytes, indices.buffer.asUint8List());

    final json = {
      "asset": {"version": "2.0"},
      "buffers": [
        {
          "byteLength": totalLength,
          if (!asGlb)
            "uri": "model.bin"
        }
      ],
      "bufferViews": [
        {
          "buffer": 0,
          "byteOffset": positionOffset,
          "byteLength": positions.lengthInBytes,
          "target": 34962
        },
        {
          "buffer": 0,
          "byteOffset": normalOffset,
          "byteLength": normals.lengthInBytes,
          "target": 34962
        },
        {
          "buffer": 0,
          "byteOffset": indexOffset,
          "byteLength": indices.lengthInBytes,
          "target": 34963
        }
      ],
      "accessors": [
        {
          "bufferView": 0,
          "componentType": 5126,
          "count": mesh.positions.length,
          "type": "VEC3",
          "min": _getMin(mesh.positions),
          "max": _getMax(mesh.positions)
        },
        {
          "bufferView": 1,
          "componentType": 5126,
          "count": mesh.normals.length,
          "type": "VEC3"
        },
        {
          "bufferView": 2,
          "componentType": 5123,
          "count": mesh.indices.length,
          "type": "SCALAR"
        }
      ],
      "meshes": [
        {
          "primitives": [
            {
              "attributes": {
                "POSITION": 0,
                "NORMAL": 1
              },
              "indices": 2
            }
          ]
        }
      ],
      "nodes": [
        {"mesh": 0}
      ],
      "scenes": [
        {"nodes": [0]}
      ],
      "scene": 0
    };

    return GltfAsset(json: json, binary: bufferData, isGlb: asGlb);
  }

  static Float32List _vec3ListToFloat32List(List<Vector3> list) {
    final data = Float32List(list.length * 3);
    for (var i = 0; i < list.length; i++) {
      data[i * 3 + 0] = list[i].x;
      data[i * 3 + 1] = list[i].y;
      data[i * 3 + 2] = list[i].z;
    }
    return data;
  }

  static int _alignTo4(int value) => (value + 3) & ~3;

  static List<double> _getMin(List<Vector3> list) {
    return [
      list.map((v) => v.x).reduce((a, b) => a < b ? a : b),
      list.map((v) => v.y).reduce((a, b) => a < b ? a : b),
      list.map((v) => v.z).reduce((a, b) => a < b ? a : b),
    ];
  }

  static List<double> _getMax(List<Vector3> list) {
    return [
      list.map((v) => v.x).reduce((a, b) => a > b ? a : b),
      list.map((v) => v.y).reduce((a, b) => a > b ? a : b),
      list.map((v) => v.z).reduce((a, b) => a > b ? a : b),
    ];
  }
}
