import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stl_to_gltf_converter/converter/model_diff.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'converter/stl_parser.dart';
import 'converter/geometry_processor.dart';
import 'converter/gltf_builder.dart';
import 'converter/gltf_writer.dart';

import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

void main() {
  runApp(MaterialApp(home: ConverterPage()));
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage>
    with SingleTickerProviderStateMixin {
  String? _status;
  String? _modelPath;

  String? _binPath;

  bool modelLoaded = false;
  double elapsed = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _diffMesh() async {
    final oldTriangles = await StlParser.parse(File(_cubePath));
    final newTriangles = await StlParser.parse(File(_newPath));

    final diff = ModelDiffer.compareModels(oldTriangles, newTriangles);

    final gltfAsset = GltfBuilder.buildDiffMesh(
      unchanged: diff.unchanged,
      added: diff.added,
      asGlb: false,
    );

    final directory = await getApplicationDocumentsDirectory();
    final outputPath = '${directory.path}';

    await GltfWriter.writeGltf(gltfAsset, outputPath);

    setState(() {
      _status = '$outputPath';
      _modelPath = '$outputPath\\model.gltf';
      _binPath = '$outputPath\\model.bin';
    });
  }

  Future<void> _pickAndConvertFile() async {
    setState(() {
      _status = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['stl'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = 'Файл не выбран.';
        });
        return;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);

      final triangles = await StlParser.parse(file);
      final mesh = GeometryProcessor.process(triangles);
      final asset = GltfBuilder.build(mesh, asGlb: false);

      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}';

      await GltfWriter.writeGltf(asset, outputPath);

      setState(() {
        _status = '$outputPath';
        _modelPath = '$outputPath\\model.gltf';
        _binPath = '$outputPath\\model.bin';
      });
    } catch (e) {
      setState(() {
        _status = 'Ошибка: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STL to glTF Converter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _pickAndConvertFile,
              child: const Text('Выбрать STL-файл и конвертировать'),
            ),

            ElevatedButton(
              onPressed: _diffMesh,
              child: const Text('Выбрать STL-файл и конвертировать'),
            ),
            Text('$_status'),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  _modelPath != null
                      ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => WebModelViewerPage(
                                modelPath: _modelPath!,
                                binPath: _binPath!,
                              ),
                        ),
                      )
                      : null,
              child: const Text('Открыть в Web-просмотрщике'),
            ),
          ],
        ),
      ),
    );
  }
}

class WebModelViewerPage extends StatefulWidget {
  final String modelPath;
  final String binPath;
  const WebModelViewerPage({
    super.key,
    required this.modelPath,
    required this.binPath,
  });

  @override
  State<WebModelViewerPage> createState() => _WebModelViewerPageState();
}

class _WebModelViewerPageState extends State<WebModelViewerPage> {
  HttpServer? _server;
  String? _url;

  @override
  void initState() {
    super.initState();
    _startServerAndViewer();
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  Future<void> _startServerAndViewer() async {
    final tempDir = await getTemporaryDirectory();

    // Имя файла и расширение

    print(widget.modelPath);
    final isGlb = widget.modelPath.toLowerCase().endsWith('.glb');
    final modelName = isGlb ? 'model.glb' : 'model.gltf';

    // Копируем модель в tempDir
    await File(widget.modelPath).copy('${tempDir.path}/$modelName');
    await File(widget.binPath).copy('${tempDir.path}/model.bin');

    print('${tempDir.path}/$modelName');

    // HTML с относительным путём

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <script type="module" src="https://unpkg.com/@google/model-viewer@4.1.0/dist/model-viewer.min.js"></script>
  <style>
    html, body { margin: 0; height: 100%; background: #111; }
    model-viewer { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <model-viewer
    src="model.gltf"
    type="model/gltf+json"
    "uri": "model.bin",
    auto-rotate
    camera-controls
    background-color="#111">
  </model-viewer>
</body>
</html>
''';

    final htmlFile = File('${tempDir.path}/viewer.html');
    await htmlFile.writeAsString(html);

    // Запускаем HTTP-сервер
    final handler = createStaticHandler(
      tempDir.path,
      defaultDocument: 'viewer.html',
    );
    _server = await io.serve(handler, 'localhost', 0);
    final url = 'http://localhost:${_server!.port}/viewer.html';

    setState(() => _url = url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Viewer')),
      body:
          _url == null
              ? const Center(child: CircularProgressIndicator())
              : InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri.uri(Uri.parse(_url!)),
                ),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                ),
              ),
    );
  }
}
