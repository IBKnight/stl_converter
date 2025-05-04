import 'dart:convert';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';

import 'geometry_processor.dart' as gm;
import 'stl_parser.dart' as stl;

class GltfAsset {
  final Map<String, dynamic> json;
  final Uint8List? binary;
  final bool isGlb;

  GltfAsset({required this.json, required this.binary, this.isGlb = false});
}

class GltfBuilder {
  static GltfAsset build(gm.MeshData mesh, {bool asGlb = false}) {
    final positions = _vec3ListToFloat32List(mesh.positions);
    final normals = _vec3ListToFloat32List(mesh.normals);
    final indices = Uint16List.fromList(mesh.indices);

    final positionOffset = 0;
    final normalOffset = positionOffset + positions.lengthInBytes;
    final indexOffset = _alignTo4(normalOffset + normals.lengthInBytes);
    final totalLength = _alignTo4(indexOffset + indices.lengthInBytes);

    final bufferData = Uint8List(totalLength);
    bufferData.setRange(
      positionOffset,
      positionOffset + positions.lengthInBytes,
      positions.buffer.asUint8List(),
    );
    bufferData.setRange(
      normalOffset,
      normalOffset + normals.lengthInBytes,
      normals.buffer.asUint8List(),
    );
    bufferData.setRange(
      indexOffset,
      indexOffset + indices.lengthInBytes,
      indices.buffer.asUint8List(),
    );

    final json = {
      "asset": {"version": "2.0"},
      "buffers": [
        {"byteLength": totalLength, if (!asGlb) "uri": "model.bin"},
      ],
      "bufferViews": [
        {
          "buffer": 0,
          "byteOffset": positionOffset,
          "byteLength": positions.lengthInBytes,
          "target": 34962,
        },
        {
          "buffer": 0,
          "byteOffset": normalOffset,
          "byteLength": normals.lengthInBytes,
          "target": 34962,
        },
        {
          "buffer": 0,
          "byteOffset": indexOffset,
          "byteLength": indices.lengthInBytes,
          "target": 34963,
        },
      ],
      "accessors": [
        {
          "bufferView": 0,
          "componentType": 5126,
          "count": mesh.positions.length,
          "type": "VEC3",
          "min": _getMin(mesh.positions),
          "max": _getMax(mesh.positions),
        },
        {
          "bufferView": 1,
          "componentType": 5126,
          "count": mesh.normals.length,
          "type": "VEC3",
        },
        {
          "bufferView": 2,
          "componentType": 5123,
          "count": mesh.indices.length,
          "type": "SCALAR",
        },
      ],
      "meshes": [
        {
          "primitives": [
            {
              "attributes": {"POSITION": 0, "NORMAL": 1},
              "indices": 2,
            },
          ],
        },
      ],
      "nodes": [
        {"mesh": 0},
      ],
      "scenes": [
        {
          "nodes": [0],
        },
      ],
      "scene": 0,
    };

    return GltfAsset(json: json, binary: bufferData, isGlb: asGlb);
  }

  static GltfAsset buildDiffMesh({
    required List<stl.Triangle> unchanged,
    required List<stl.Triangle> added,
    bool asGlb = false,
  }) {
    final baseMesh = gm.GeometryProcessor.process(unchanged);
    final diffMesh = gm.GeometryProcessor.process(added);

    final posBase = _vec3ListToFloat32List(baseMesh.positions);
    final normBase = _vec3ListToFloat32List(baseMesh.normals);
    final indBase = Uint16List.fromList(baseMesh.indices);

    final posDiff = _vec3ListToFloat32List(diffMesh.positions);
    final normDiff = _vec3ListToFloat32List(diffMesh.normals);
    final indDiff = Uint16List.fromList(diffMesh.indices);

    // Вычисление смещений с выравниванием
    int offset = 0;
    int offsetPosBase = offset;
    offset += posBase.lengthInBytes;
    int offsetNormBase = offset;
    offset += normBase.lengthInBytes;
    int offsetIndBase = _alignTo4(offset);
    offset = offsetIndBase + indBase.lengthInBytes;

    int offsetPosDiff = offset;
    offset += posDiff.lengthInBytes;
    int offsetNormDiff = offset;
    offset += normDiff.lengthInBytes;
    int offsetIndDiff = _alignTo4(offset);
    offset = offsetIndDiff + indDiff.lengthInBytes;

    final totalLength = _alignTo4(offset);
    final buffer = Uint8List(totalLength);

    buffer.setRange(
      offsetPosBase,
      offsetPosBase + posBase.lengthInBytes,
      posBase.buffer.asUint8List(),
    );
    buffer.setRange(
      offsetNormBase,
      offsetNormBase + normBase.lengthInBytes,
      normBase.buffer.asUint8List(),
    );
    buffer.setRange(
      offsetIndBase,
      offsetIndBase + indBase.lengthInBytes,
      indBase.buffer.asUint8List(),
    );
    buffer.setRange(
      offsetPosDiff,
      offsetPosDiff + posDiff.lengthInBytes,
      posDiff.buffer.asUint8List(),
    );
    buffer.setRange(
      offsetNormDiff,
      offsetNormDiff + normDiff.lengthInBytes,
      normDiff.buffer.asUint8List(),
    );
    buffer.setRange(
      offsetIndDiff,
      offsetIndDiff + indDiff.lengthInBytes,
      indDiff.buffer.asUint8List(),
    );

    final json = {
      "asset": {"version": "2.0"},
      "buffers": [
        {"byteLength": totalLength, if (!asGlb) "uri": "model.bin"},
      ],
      "bufferViews": [
        _view(0, offsetPosBase, posBase.lengthInBytes, 34962), // 0
        _view(0, offsetNormBase, normBase.lengthInBytes, 34962), // 1
        _view(0, offsetIndBase, indBase.lengthInBytes, 34963), // 2
        _view(0, offsetPosDiff, posDiff.lengthInBytes, 34962), // 3
        _view(0, offsetNormDiff, normDiff.lengthInBytes, 34962), // 4
        _view(0, offsetIndDiff, indDiff.lengthInBytes, 34963), // 5
      ],
      "accessors": [
        _vec3Accessor(0, baseMesh.positions),
        _vec3Accessor(1, baseMesh.normals),
        _scalarAccessor(2, indBase.length),
        _vec3Accessor(3, diffMesh.positions),
        _vec3Accessor(4, diffMesh.normals),
        _scalarAccessor(5, indDiff.length),
      ],
      "materials": [
        {
          "pbrMetallicRoughness": {
            "baseColorFactor": [0.7, 0.7, 0.7, 1.0],
          },
        },
        {
          "pbrMetallicRoughness": {
            "baseColorFactor": [0.0, 1.0, 0.0, 1.0], // зелёный
          },
        },
      ],
      "meshes": [
        {
          "primitives": [
            {
              "attributes": {"POSITION": 0, "NORMAL": 1},
              "indices": 2,
              "material": 0,
            },
            {
              "attributes": {"POSITION": 3, "NORMAL": 4},
              "indices": 5,
              "material": 1,
            },
          ],
        },
      ],
      "nodes": [
        {"mesh": 0},
      ],
      "scenes": [
        {
          "nodes": [0],
        },
      ],
      "scene": 0,
    };

    return GltfAsset(json: json, binary: buffer, isGlb: asGlb);
  }

  static Map<String, dynamic> _view(
    int buffer,
    int offset,
    int length,
    int target,
  ) {
    return {
      "buffer": buffer,
      "byteOffset": offset,
      "byteLength": length,
      "target": target,
    };
  }

  static Map<String, dynamic> _vec3Accessor(int view, List<Vector3> data) {
    return {
      "bufferView": view,
      "componentType": 5126,
      "count": data.length,
      "type": "VEC3",
      "min": _getMin(data),
      "max": _getMax(data),
    };
  }

  static Map<String, dynamic> _scalarAccessor(int view, int count) {
    return {
      "bufferView": view,
      "componentType": 5123,
      "count": count,
      "type": "SCALAR",
    };
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
