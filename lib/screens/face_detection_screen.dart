import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import '../services/mediapipe_web_bridge.dart';
import '../services/ml_input_image.dart';
import '../widgets/full_camera_preview.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/web_camera_view.dart';

class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  final String _webContainerId = 'face-web-view';
  Timer? _webPollTimer;
  bool _webStarted = false;
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  String _status = 'Initializing camera...';
  String _emotion = 'Unknown';
  String _advice = 'Look at the camera for analysis.';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (kIsWeb) {
        setState(() {
          _isCameraReady = true;
          _status = 'Tap Start Browser Camera to begin realtime analysis.';
        });
        return;
      }

      if (!kIsWeb) {
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
        }
        if (!status.isGranted) {
          setState(() {
            _status = 'Camera permission denied. Please allow camera access.';
          });
          return;
        }
      }

      final cameras = await availableCameras();
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      final selected = front.isNotEmpty ? front.first : cameras.first;

      _cameraController = CameraController(selected, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      await _cameraController!.startImageStream(_processFrame);
      setState(() {
        _isCameraReady = true;
        _status = 'Realtime face detection is running.';
      });
    } catch (e) {
      setState(() {
        _status = 'Face detection is unavailable on this platform/runtime: $e';
      });
    }
  }

  Future<void> _startWebFace() async {
    _webPollTimer?.cancel();
    await stopWebMediaPipe();
    try {
      await startWebMediaPipe(mode: 'face', containerId: _webContainerId);
      if (!mounted) return;
      setState(() {
        _webStarted = true;
        _status = 'Realtime browser face detection is running.';
      });
      _webPollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        final data = getWebMediaPipeLatest('face');
        if (!mounted || data.isEmpty) {
          return;
        }
        setState(() {
          final detected = data['faceDetected'] == true;
          _emotion = (data['emotion'] ?? 'Unknown').toString();
          _advice = (data['advice'] ?? 'Look at the camera for analysis.').toString();
          _status = detected
              ? 'Realtime browser face detection is running.'
              : 'Face not detected. Keep full face in frame.';
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _webStarted = false;
        _status = 'Browser face detection failed to start: $e';
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || _cameraController == null || _faceDetector == null) {
      return;
    }
    _isProcessing = true;
    try {
      final inputImage = buildInputImage(_cameraController, image);
      if (inputImage == null) {
        return;
      }
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            _emotion = 'No face detected';
            _advice = 'Keep your full face inside frame with good light.';
          });
        }
        return;
      }

      final smile = faces.first.smilingProbability ?? 0.5;
      String emotion;
      String advice;
      if (smile > 0.62) {
        emotion = 'Happy';
        advice = 'Great energy. Keep this positive mood for your workout.';
      } else if (smile < 0.25) {
        emotion = 'Sad';
        advice = 'Try smile breathing: inhale 4s, exhale 6s, then light stretching.';
      } else {
        emotion = 'Neutral';
        advice = 'Try a short laughter or mobility exercise to lift mood.';
      }

      if (mounted) {
        setState(() {
          _emotion = emotion;
          _advice = advice;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Face analysis failed on this runtime.';
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _webPollTimer?.cancel();
    if (kIsWeb) {
      unawaited(stopWebMediaPipe());
    }
    final camera = _cameraController;
    if (camera != null && camera.value.isStreamingImages) {
      camera.stopImageStream();
    }
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Face Detection')),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: Column(
            children: [
              Expanded(
                child: LiquidGlassCard(
                  tint: const Color(0xFFDDE7FF),
                  padding: EdgeInsets.zero,
                  child: _isCameraReady
                      ? (kIsWeb
                          ? const WebCameraView(containerId: 'face-web-view')
                          : (_cameraController != null
                              ? FullCameraPreview(controller: _cameraController!)
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(_status, textAlign: TextAlign.center),
                                  ),
                                )))
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_status, textAlign: TextAlign.center),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startWebFace,
                          icon: const Icon(Icons.videocam),
                          label: Text(_webStarted ? 'Restart Browser Camera' : 'Start Browser Camera'),
                        ),
                      ),
                    ],
                  ),
                ),
              LiquidGlassCard(
                tint: const Color(0xFFFFE8C4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emotion: $_emotion', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_advice, style: const TextStyle(color: Color(0xFFEAF3FF))),
                    const SizedBox(height: 6),
                    Text(_status, style: const TextStyle(fontSize: 12, color: Color(0xD0EAF3FF))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
