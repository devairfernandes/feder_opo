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
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';

// ── MODELOS ──────────────────────────────────────────────────────────────────

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

// ── APP START ────────────────────────────────────────────────────────────────

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
        primaryColor: const Color(0xFF6366F1),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: cameras.isEmpty
          ? const Scaffold(body: Center(child: Text('Câmera não encontrada')))
          : const SplashScreen(),
    ),
  );
}

// ── SPLASH SCREEN ────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    Timer(const Duration(seconds: 3), () async {
      final cameras = await availableCameras();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) =>
                TakePictureScreen(cameras: cameras),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_rounded,
                    size: 80,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Text(
                    'FEDER_OPO',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'FOTO 3X4 PROFISSIONAL',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TELA DE CAPTURA ──────────────────────────────────────────────────────────

class TakePictureScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const TakePictureScreen({super.key, required this.cameras});
  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen>
    with TickerProviderStateMixin {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  int _selectedCameraIdx = 0;
  FlashMode _flashMode = FlashMode.off;
  int _timerSecs = 0;
  int _countdown = 0;
  Timer? _timer;
  final PhotoModel _currentModel = officialModels[0];

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIdx);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), _checkUpdate);
    });
  }

  Future<void> _checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse(
          'https://raw.githubusercontent.com/devairfernandes/feder_opo/main/version.json?t=$timestamp',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'] as String;
        final apkUrl = data['url'] as String;
        if (latestVersion != currentVersion && mounted) {
          final changelog =
              data['changelog'] ?? 'Melhorias de estabilidade e performance.';
          _showUpdateDialog(latestVersion, apkUrl, changelog);
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar atualização: $e');
    }
  }

  void _showUpdateDialog(String version, String url, String notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Nova Versão Disponível ($version)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O que há de novo:',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                notes,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Deseja atualizar agora?',
              style: GoogleFonts.outfit(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'MAIS TARDE',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _executeUpdate(url);
            },
            child: Text(
              'ATUALIZAR AGORA',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _executeUpdate(String url) async {
    try {
      final progressNotifier = ValueNotifier<double>(0);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Baixando atualização...',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (ctx, prog, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: prog,
                    minHeight: 10,
                    backgroundColor: Colors.black26,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${(prog * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('Erro de armazenamento interno');
      final savePath = '${dir.path}/app_download.apk';
      final file = File(savePath);
      if (await file.exists()) await file.delete();
      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) progressNotifier.value = received / total;
        },
      );
      if (mounted) Navigator.of(context).pop();
      await OpenFilex.open(
        savePath,
        type: 'application/vnd.android.package-archive',
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
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
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
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
              if (snapshot.connectionState == ConnectionState.done) {
                return Center(child: CameraPreview(_controller));
              }
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              );
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _glassIconButton(
                    icon: _flashMode == FlashMode.off
                        ? Icons.flash_off
                        : _flashMode == FlashMode.always
                        ? Icons.flash_on
                        : Icons.flash_auto,
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
                  _glassIconButton(
                    icon: _timerSecs == 0 ? Icons.timer_off : Icons.timer,
                    color: _timerSecs > 0 ? const Color(0xFF6366F1) : null,
                    onPressed: () => setState(
                      () => _timerSecs = (_timerSecs == 0
                          ? 3
                          : (_timerSecs == 3 ? 5 : 0)),
                    ),
                  ),
                  if (widget.cameras.length > 1)
                    _glassIconButton(
                      icon: Icons.flip_camera_android_rounded,
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
                style: GoogleFonts.outfit(
                  fontSize: 140,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    const Shadow(
                      blurRadius: 30,
                      color: Colors.black,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.only(bottom: 40, top: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0F172A).withOpacity(0.9),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'MODO 3X4 ATIVO',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF6366F1),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: (_isProcessing || _countdown > 0)
                          ? null
                          : _startCapture,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          height: 75,
                          width: 75,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Color(0xFF0F172A),
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      'Desenvolvido por: Devair Fernandes',
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '(69) 99221-4709',
                      style: GoogleFonts.outfit(
                        color: Colors.white24,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF6366F1)),
                    const SizedBox(height: 20),
                    Text(
                      'Processando...',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

  Widget _glassIconButton({
    required IconData icon,
    VoidCallback? onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}

// ── TELA DE EDIÇÃO ───────────────────────────────────────────────────────────

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

  // Ajustes de Imagem
  double _brightness = 0.0;
  double _contrast = 1.0;

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

      // Aplicar brilho e contraste no processamento da folha
      img.Image adjusted = img.Image(
        width: source.width,
        height: source.height,
      );
      for (final pixel in source) {
        // Fórmula básica: (color - 128) * contrast + 128 + brightness
        int r = (((pixel.r - 128) * _contrast) + 128 + (_brightness * 255))
            .toInt()
            .clamp(0, 255);
        int g = (((pixel.g - 128) * _contrast) + 128 + (_brightness * 255))
            .toInt()
            .clamp(0, 255);
        int b = (((pixel.b - 128) * _contrast) + 128 + (_brightness * 255))
            .toInt()
            .clamp(0, 255);
        adjusted.setPixelRgb(pixel.x, pixel.y, r, g, b);
      }

      final sw = 2480, sh = 3508;
      final sheet = img.Image(width: sw, height: sh);
      img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
      int tw = 354, th = 472;
      final res = img.copyResize(adjusted, width: tw, height: th);
      int cols = 4;
      int rows = (_quantity / cols).ceil();
      int hGap = 60, vGap = 60;
      int totalW = (cols * tw) + ((cols - 1) * hGap);
      int startX = (sw - totalW) ~/ 2;
      int startY = 450;

      img.drawString(
        sheet,
        'Desenvolvido por: Devair Fernandes (69) 99221-4709',
        font: img.arial24,
        x: sw ~/ 2 - 700,
        y: 150,
        color: img.ColorRgb8(120, 120, 120),
      );
      img.drawString(
        sheet,
        'Grade de Impressão 3x4 Oficial - Feder_OPO',
        font: img.arial24,
        x: sw ~/ 2 - 580,
        y: 230,
        color: img.ColorRgb8(100, 100, 100),
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

  // Matriz de cor para o preview visual (filtros)
  List<double> _getColorMatrix() {
    double b = _brightness * 255;
    double c = _contrast;
    return <double>[c, 0, 0, 0, b, 0, c, 0, 0, b, 0, 0, c, 0, b, 0, 0, 0, 1, 0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ajuste e Impressão',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _isGeneratingSheet
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Aplicando ajustes...',
                          style: GoogleFonts.outfit(color: Colors.white70),
                        ),
                      ],
                    )
                  : _sheetPreview == null
                  ? const CircularProgressIndicator()
                  : ColorFiltered(
                      colorFilter: ColorFilter.matrix(_getColorMatrix()),
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF6366F1,
                                ).withOpacity(0.05),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(_sheetPreview!),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          _buildAdjustmentPanel(),
          _buildActionPanel(),
        ],
      ),
    );
  }

  Widget _buildAdjustmentPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          _sliderRow(
            label: 'Brilho',
            icon: Icons.light_mode_rounded,
            value: _brightness,
            onChanged: (v) => setState(() => _brightness = v),
            onChangeEnd: (_) => _updateSheetPreview(),
            min: -0.5,
            max: 0.5,
          ),
          const SizedBox(height: 8),
          _sliderRow(
            label: 'Contraste',
            icon: Icons.contrast_rounded,
            value: _contrast,
            onChanged: (v) => setState(() => _contrast = v),
            onChangeEnd: (_) => _updateSheetPreview(),
            min: 0.5,
            max: 1.5,
          ),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    required double min,
    required double max,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF6366F1),
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF6366F1).withOpacity(0.2),
              trackHeight: 2,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    color: Color(0xFF6366F1),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'QUANTIDADE NA FOLHA',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(12, (index) {
                  int val = index + 1;
                  bool isSelected = _quantity == val;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() => _quantity = val);
                        _updateSheetPreview();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white10,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$val',
                            style: GoogleFonts.outfit(
                              color: isSelected ? Colors.white : Colors.white54,
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
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _sheetPreview == null ? null : _shareSheet,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 64),
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 10,
                shadowColor: const Color(0xFF6366F1).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'SALVAR E COMPARTILHAR',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF6366F1).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final dashPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      dashPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.25,
        size.height * 0.15,
        size.width * 0.5,
        size.height * 0.42,
      ),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.05, size.height * 0.9)
        ..quadraticBezierTo(
          size.width * 0.05,
          size.height * 0.68,
          size.width * 0.25,
          size.height * 0.68,
        )
        ..lineTo(size.width * 0.75, size.height * 0.68)
        ..quadraticBezierTo(
          size.width * 0.95,
          size.height * 0.68,
          size.width * 0.95,
          size.height * 0.9,
        ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
