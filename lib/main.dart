import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:gallery_saver/gallery_saver.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const CameraApp());
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CameraScreen(),
    );
  }
}

enum PhotoFilter { none, bw, sepia, vintage, cool, warm }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  int _cameraIndex = 0;

  bool _isReady = false;
  bool _isProcessing = false;
  bool _showFlash = false;

  PhotoFilter _filter = PhotoFilter.none;

  @override
  void initState() {
    super.initState();
    _initCamera(cameras[_cameraIndex]);
  }

  Future<void> _initCamera(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() => _isReady = true);
  }

  void _switchCamera() {
    if (cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % cameras.length;
    setState(() => _isReady = false);
    _initCamera(cameras[_cameraIndex]);
  }

  Future<void> _takePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _showFlash = true;
    });

    // Flash effect
    await Future.delayed(const Duration(milliseconds: 120));
    setState(() => _showFlash = false);

    try {
      final XFile raw = await _controller!.takePicture();

      final bytes = await File(raw.path).readAsBytes();
      img.Image? photo = img.decodeImage(bytes);

      if (photo == null) throw 'ไม่สามารถอ่านไฟล์ภาพได้';

      photo = _applyFilter(photo, _filter);

      final tempPath =
          '${Directory.systemTemp.path}/IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File(tempPath);

      await tempFile.writeAsBytes(img.encodeJpg(photo));

      final result = await GallerySaver.saveImage(tempPath);
      await tempFile.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == true
                ? '✅ บันทึกรูปภาพเรียบร้อย'
                : '⚠️ ไม่สามารถบันทึกรูปภาพได้',
          ),
          backgroundColor: result == true ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  img.Image _applyFilter(img.Image image, PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.bw:
        return img.grayscale(image);
      case PhotoFilter.sepia:
        return img.sepia(image);
      case PhotoFilter.vintage:
        return img.sepia(img.adjustColor(image, contrast: 1.2));
      case PhotoFilter.cool:
        return img.adjustColor(image, hue: 15);
      case PhotoFilter.warm:
        return img.adjustColor(image, hue: -15);
      default:
        return image;
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: PhotoFilter.values.map((f) {
          return ListTile(
            leading: const Icon(Icons.filter, color: Colors.white),
            title: Text(
              f.name.toUpperCase(),
              style: TextStyle(
                color: _filter == f ? Colors.blue : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              setState(() => _filter = f);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isReady
          ? Stack(
              children: [
                CameraPreview(_controller!),

                // Flash overlay
                if (_showFlash)
                  Container(color: Colors.white),

                // Loading overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'กำลังบันทึกรูป...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Filter label
                Positioned(
                  top: 40,
                  left: 20,
                  child: Chip(
                    backgroundColor: Colors.black54,
                    label: Text(
                      _filter.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                // Bottom bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    color: Colors.black87,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.filter_alt),
                          color: Colors.white,
                          iconSize: 32,
                          onPressed: _showFilterSheet,
                        ),

                        // Shutter
                        GestureDetector(
                          onTap: _isProcessing ? null : _takePhoto,
                          child: Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.flip_camera_android),
                          color: Colors.white,
                          iconSize: 32,
                          onPressed: _switchCamera,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
