import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';

class PhotoModel {
  final String name;
  final double aspectRatio;
  final String description;
  const PhotoModel({
    required this.name,
    required this.aspectRatio,
    required this.description,
  });
}

const List<PhotoModel> officialModels = [
  PhotoModel(
    name: '3x4',
    aspectRatio: 3 / 4,
    description: 'Documentos, CNH e Identidade',
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Erro: $e');
  }
  runApp(
    MaterialApp(
      title: 'Feder_OPO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: cameras.isEmpty
          ? const Scaffold(body: Center(child: Text('Câmera não encontrada')))
          : TakePictureScreen(cameras: cameras),
    ),
  );
}

class TakePictureScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const TakePictureScreen({super.key, required this.cameras});
  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  int _selectedCameraIdx = 0;
  FlashMode _flashMode = FlashMode.off;
  int _timerSecs = 0;
  int _countdown = 0;
  Timer? _timer;
  PhotoModel _currentModel = officialModels[0];

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIdx);
    // Aguarda o frame ser desenhado antes de checar atualização
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), _checkUpdate);
    });
  }

  Future<void> _checkUpdate() async {
    try {
      debugPrint('>>> Checando atualização...');
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('>>> Versão atual do app: $currentVersion');

      final response = await http.get(
        Uri.parse(
          'https://raw.githubusercontent.com/devairfernandes/feder_opo/main/version.json',
        ),
      );

      debugPrint('>>> Status HTTP: \${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'] as String;
        final apkUrl = data['url'] as String;
        debugPrint('>>> Versão no GitHub: $latestVersion');

        if (latestVersion != currentVersion && mounted) {
          debugPrint('>>> Mostrando diálogo de atualização!');
          _showUpdateDialog(latestVersion, apkUrl);
        } else {
          debugPrint('>>> App já está atualizado ou não está montado.');
        }
      }
    } catch (e) {
      debugPrint('>>> Erro ao verificar atualização: $e');
    }
  }

  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Nova Versão Disponível!'),
        content: Text(
          'Uma nova versão ($version) está disponível. Deseja atualizar agora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('MAIS TARDE'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeUpdate(url);
            },
            child: const Text('ATUALIZAR AGORA'),
          ),
        ],
      ),
    );
  }

  void _executeUpdate(String url) async {
    try {
      // Mostra progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          title: Text('Baixando atualização...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Aguarde o download...'),
            ],
          ),
        ),
      );

      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/update.apk';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          debugPrint('Download: $received / $total');
        },
      );

      if (mounted) Navigator.of(context).pop(); // fecha o dialog

      // Abre o instalador via Android Intent
      final result = await Process.run('am', [
        'start',
        '-a',
        'android.intent.action.VIEW',
        '-t',
        'application/vnd.android.package-archive',
        '-d',
        'file://$savePath',
        '--grant-read-uri-permission',
      ]);
      debugPrint('Install result: ${result.stdout}');
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      debugPrint('Erro ao atualizar: $e');
    }
  }

  Future<void> _initCamera(int idx) async {
    _controller = CameraController(
      widget.cameras[idx],
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize().then((_) async {
      await _controller.setFlashMode(_flashMode);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCapture() {
    if (_timerSecs == 0) {
      _processCapture();
    } else {
      setState(() => _countdown = _timerSecs);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            t.cancel();
            _processCapture();
          }
        });
      });
    }
  }

  Future<void> _processCapture() async {
    try {
      setState(() => _isProcessing = true);
      await _initializeControllerFuture;
      final xFile = await _controller.takePicture();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              EditPhotoScreen(imagePath: xFile.path, model: _currentModel),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done)
                return Center(child: CameraPreview(_controller));
              return const Center(child: CircularProgressIndicator());
            },
          ),
          Positioned.fill(
            child: Center(
              child: AspectRatio(
                aspectRatio: _currentModel.aspectRatio,
                child: Container(
                  margin: const EdgeInsets.all(40),
                  child: CustomPaint(painter: SilhouettePainter()),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      _flashMode == FlashMode.off
                          ? Icons.flash_off
                          : _flashMode == FlashMode.always
                          ? Icons.flash_on
                          : Icons.flash_auto,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      final modes = [
                        FlashMode.off,
                        FlashMode.always,
                        FlashMode.auto,
                      ];
                      _flashMode =
                          modes[(modes.indexOf(_flashMode) + 1) % modes.length];
                      await _controller.setFlashMode(_flashMode);
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _timerSecs == 0 ? Icons.timer_off : Icons.timer,
                      color: _timerSecs > 0 ? Colors.orange : Colors.white,
                    ),
                    onPressed: () => setState(
                      () => _timerSecs = (_timerSecs == 0
                          ? 3
                          : (_timerSecs == 3 ? 5 : 0)),
                    ),
                  ),
                  if (widget.cameras.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.flip_camera_android,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(
                          () => _selectedCameraIdx =
                              (_selectedCameraIdx + 1) % widget.cameras.length,
                        );
                        _controller.dispose();
                        _initCamera(_selectedCameraIdx);
                      },
                    ),
                ],
              ),
            ),
          ),
          if (_countdown > 0)
            Center(
              child: Text(
                '$_countdown',
                style: const TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.only(bottom: 60, top: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'MODO 3X4 ATIVO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 25),
                    FloatingActionButton.large(
                      onPressed: (_isProcessing || _countdown > 0)
                          ? null
                          : _startCapture,
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Desenvolvido por: Devair fernandes (69)99221-4709',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class EditPhotoScreen extends StatefulWidget {
  final String imagePath;
  final PhotoModel model;
  const EditPhotoScreen({
    super.key,
    required this.imagePath,
    required this.model,
  });
  @override
  EditPhotoScreenState createState() => EditPhotoScreenState();
}

class EditPhotoScreenState extends State<EditPhotoScreen> {
  int _quantity = 2;
  img.Image? _croppedBase;
  img.Image? _currentSheet;
  Uint8List? _sheetPreview;
  bool _isGeneratingSheet = false;

  @override
  void initState() {
    super.initState();
    _loadAndPrepare();
  }

  Future<void> _loadAndPrepare() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    img.Image source = img.Image(width: decoded.width, height: decoded.height);
    for (var frame in decoded.frames) {
      for (var pixel in frame) {
        source.setPixelRgb(
          pixel.x,
          pixel.y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
        );
      }
    }

    int w = source.width, h = source.height;
    double ratio = widget.model.aspectRatio;
    int tw, th, ox = 0, oy = 0;
    if (w / h > ratio) {
      th = h;
      tw = (h * ratio).toInt();
      ox = (w - tw) ~/ 2;
    } else {
      tw = w;
      th = (w / ratio).toInt();
      oy = (h - th) ~/ 2;
    }

    _croppedBase = img.copyCrop(source, x: ox, y: oy, width: tw, height: th);
    _updateSheetPreview();
  }

  Future<void> _updateSheetPreview() async {
    if (_croppedBase == null) return;
    setState(() => _isGeneratingSheet = true);

    try {
      img.Image source = _croppedBase!;

      // CONFIGURAÇÃO FOLHA A4 (2480 x 3508 pixels @ 300 DPI)
      final sw = 2480, sh = 3508;
      final sheet = img.Image(width: sw, height: sh);
      img.fill(sheet, color: img.ColorRgb8(255, 255, 255));

      // TAMANHO REAL 30x40mm @ 300 DPI:
      // 30mm = 354 pixels
      // 40mm = 472 pixels
      int tw = 354, th = 472;
      final res = img.copyResize(source, width: tw, height: th);

      // Organização em colunas e linhas para A4
      int cols =
          4; // 4 fotos por linha cabem bem no A4 (4 * 3cm = 12cm + margens)
      int rows = (_quantity / cols).ceil();

      // Margens para centralizar o bloco de fotos no topo do A4
      int hGap = 60, vGap = 60;
      int totalW = (cols * tw) + ((cols - 1) * hGap);
      int startX = (sw - totalW) ~/ 2;
      int startY = 350; // Margem superior (ajustada para dar espaço ao texto)

      // Adiciona o nome do desenvolvedor no topo da folha
      img.drawString(
        sheet,
        'Desenvolvido por: Devair fernandes (69)99221-4709',
        font: img.arial24,
        x: sw ~/ 2 - 350,
        y: 100,
        color: img.ColorRgb8(150, 150, 150),
      );

      int count = 0;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (count < _quantity) {
            img.compositeImage(
              sheet,
              res,
              dstX: startX + c * (tw + hGap),
              dstY: startY + r * (th + vGap),
            );
            count++;
          }
        }
      }

      _currentSheet = sheet;
      // Gerar preview menor para tela
      img.Image previewSheet = img.copyResize(sheet, height: 800);
      setState(() {
        _sheetPreview = Uint8List.fromList(img.encodeJpg(previewSheet));
        _isGeneratingSheet = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isGeneratingSheet = false);
    }
  }

  Future<void> _shareSheet() async {
    if (_currentSheet == null) return;
    try {
      final dir = await getTemporaryDirectory();
      String ts = DateTime.now().millisecondsSinceEpoch.toString();
      final fullPath = join(dir.path, 'fotos_A4_3x4_$ts.jpg');
      await File(
        fullPath,
      ).writeAsBytes(img.encodeJpg(_currentSheet!, quality: 95));
      await Gal.putImage(fullPath);
      await Share.shareXFiles([
        XFile(fullPath),
      ], text: 'Folha A4 com fotos 3x4 pronta');
    } catch (e) {
      debugPrint('Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folha A4 - Fotos 3x4')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _isGeneratingSheet
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.greenAccent),
                        SizedBox(height: 10),
                        Text('Redimensionando para A4...'),
                      ],
                    )
                  : _sheetPreview == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: Image.memory(_sheetPreview!),
                      ),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
              color: Colors.grey[900],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FOLHA PAPEL A4 ATIVA',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Text(
                    'ESCOLHA A QUANTIDADE:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(12, (index) {
                        // Aumentado para até 12 fotos no A4
                        int val = index + 1;
                        bool isSelected = _quantity == val;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: InkWell(
                            onTap: () {
                              setState(() => _quantity = val);
                              _updateSheetPreview();
                            },
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.greenAccent
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$val',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton.icon(
                    onPressed: _sheetPreview == null ? null : _shareSheet,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('SALVAR E COMPARTILHAR A4'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 70),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(Offset.zero & size, p);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.25,
        size.height * 0.15,
        size.width * 0.5,
        size.height * 0.4,
      ),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.1, size.height * 0.85)
        ..quadraticBezierTo(
          size.width * 0.1,
          size.height * 0.65,
          size.width * 0.3,
          size.height * 0.65,
        )
        ..lineTo(size.width * 0.7, size.height * 0.65)
        ..quadraticBezierTo(
          size.width * 0.9,
          size.height * 0.65,
          size.width * 0.9,
          size.height * 0.85,
        ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
