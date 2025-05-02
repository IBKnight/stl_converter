import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'converter/stl_parser.dart';
import 'converter/geometry_processor.dart';
import 'converter/gltf_builder.dart';
import 'converter/gltf_writer.dart';

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage>
    with SingleTickerProviderStateMixin {
  String? _status;
  bool _isProcessing = false;
  String? _modelPath;

  Scene scene = Scene();
  bool modelLoaded = false;
  double elapsed = 0;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    final mesh = Mesh(CuboidGeometry(vm.Vector3(1, 1, 1)), UnlitMaterial());
    scene.addMesh(mesh);

    _ticker = createTicker((Duration elapsedTime) {
      setState(() {
        elapsed = elapsedTime.inMilliseconds / 1000.0;
      });
    })
      ..start();
  }

  @override
  void dispose() {
    scene.removeAll();
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _pickAndConvertFile() async {
    setState(() {
      _status = null;
      _isProcessing = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['stl'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = 'Файл не выбран.';
          _isProcessing = false;
        });
        return;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);

      final triangles = await StlParser.parse(file);
      final mesh = GeometryProcessor.process(triangles);
      final asset = GltfBuilder.build(mesh, asGlb: true);

      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/converted_model.glb';

      await GltfWriter.writeGlb(asset, outputPath);

      setState(() {
        _status = 'Файл сохранён: $outputPath';
        _modelPath = outputPath;
      });

      _loadModel(outputPath);
    } catch (e) {
      setState(() {
        _status = 'Ошибка: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickAndDisplayGltfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _modelPath = path;
        _status = 'Файл загружен: $path';
      });
      _loadModel(path);
    }
  }

  Future<void> _loadModel(String path) async {
    scene.removeAll();
    modelLoaded = false;

    final node = await Node.fromAsset(path);
    node.name = 'LoadedModel';
    scene.add(node);

    setState(() {
      modelLoaded = true;
    });
  }

  Widget _buildModelViewer() {
    if (!modelLoaded) return const SizedBox.shrink();

    return Expanded(
      child: CustomPaint(
        painter: _ScenePainter(scene, elapsed),
        size: Size.infinite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('STL to glTF Converter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isProcessing ? null : _pickAndConvertFile,
              child: const Text('Выбрать STL-файл и конвертировать'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickAndDisplayGltfFile,
              child: const Text('Открыть .glb/.gltf файл'),
            ),
            const SizedBox(height: 20),
            if (_isProcessing) const CircularProgressIndicator(),
            if (_status != null)
              Text(
                _status!,
                style: TextStyle(
                  color:
                      _status!.startsWith('Ошибка') ? Colors.red : Colors.green,
                ),
              ),
            const SizedBox(height: 10),
            _buildModelViewer(),
          ],
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final Scene scene;
  final double elapsed;

  _ScenePainter(this.scene, this.elapsed);

  @override
  void paint(Canvas canvas, Size size) {
    final camera = PerspectiveCamera(
      position: vm.Vector3(sin(elapsed) * 5, 2, cos(elapsed) * 5),
      target: vm.Vector3.zero(),
    );
    scene.render(camera, canvas, viewport: Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
