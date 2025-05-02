import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'gltf_builder.dart';

class GltfWriter {
  /// Сохраняет glTF как `.gltf` + `.bin`
  static Future<void> writeGltf(GltfAsset asset, String outputDir, {String name = 'model'}) async {
    final gltfFile = File('$outputDir/$name.gltf');
    final binFile = File('$outputDir/$name.bin');

    if (asset.binary == null) {
      throw Exception('No binary buffer provided for .gltf format');
    }

    await gltfFile.writeAsString(JsonEncoder.withIndent('  ').convert(asset.json));
    await binFile.writeAsBytes(asset.binary!);
  }

  /// Сохраняет glTF как единый `.glb` файл
  static Future<void> writeGlb(GltfAsset asset, String outputPath) async {
    if (asset.binary == null || !asset.isGlb) {
      throw Exception('Invalid GLB asset');
    }

    final jsonData = utf8.encode(JsonEncoder.withIndent('  ').convert(asset.json));
    final jsonAligned = _alignTo4(Uint8List.fromList(jsonData));
    final binAligned = _alignTo4(asset.binary!);

    final totalLength = 12 + 8 + jsonAligned.length + 8 + binAligned.length;

    final header = ByteData(12)
      ..setUint32(0, 0x46546C67, Endian.little) // magic = 'glTF'
      ..setUint32(4, 2, Endian.little)          // version = 2
      ..setUint32(8, totalLength, Endian.little); // total length

    final jsonChunkHeader = ByteData(8)
      ..setUint32(0, jsonAligned.length, Endian.little)
      ..setUint32(4, 0x4E4F534A, Endian.little); // 'JSON'

    final binChunkHeader = ByteData(8)
      ..setUint32(0, binAligned.length, Endian.little)
      ..setUint32(4, 0x004E4942, Endian.little); // 'BIN\0'

    final glbBytes = BytesBuilder();
    glbBytes.add(header.buffer.asUint8List());
    glbBytes.add(jsonChunkHeader.buffer.asUint8List());
    glbBytes.add(jsonAligned);
    glbBytes.add(binChunkHeader.buffer.asUint8List());
    glbBytes.add(binAligned);

    final outFile = File(outputPath);
    await outFile.writeAsBytes(glbBytes.toBytes());
  }

  static Uint8List _alignTo4(Uint8List data) {
    final padding = (4 - (data.length % 4)) % 4;
    if (padding == 0) return data;

    final aligned = Uint8List(data.length + padding);
    aligned.setRange(0, data.length, data);
    return aligned;
  }
}
