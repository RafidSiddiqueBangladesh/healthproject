import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import '../services/mediapipe_web_bridge.dart';
import '../services/ml_input_image.dart';
import '../widgets/full_camera_preview.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/web_camera_view.dart';

class ShoulderDetectionScreen extends StatefulWidget {
  const ShoulderDetectionScreen({super.key});

  @override
  State<ShoulderDetectionScreen> createState() => _ShoulderDetectionScreenState();
}

class _ShoulderDetectionScreenState extends State<ShoulderDetectionScreen> {
  final String _webContainerId = 'shoulder-web-view';
  Timer? _webPollTimer;
  bool _webStarted = false;
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isReady = false;
  bool _isProcessing = false;

  bool _leftShoulder = false;
  bool _rightShoulder = false;
  bool _movement = false;
  double? _lastLeftY;
  double? _lastRightY;
  String _status = 'Initializing camera...';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (kIsWeb) {
        setState(() {
          _isReady = true;
          _status = 'Tap Start Browser Camera to begin shoulder detection.';
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
            _status = 'Camera permission denied.';
          });
          return;
        }
      }

      final cameras = await availableCameras();
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      final selected = front.isNotEmpty ? front.first : cameras.first;

      _cameraController = CameraController(selected, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));

      await _cameraController!.startImageStream(_processFrame);
      setState(() {
        _isReady = true;
        _status = 'Realtime shoulder detection is running.';
      });
    } catch (e) {
      setState(() {
        _status = 'Shoulder detection is unavailable on this platform/runtime: $e';
      });
    }
  }

  Future<void> _startWebShoulder() async {
    _webPollTimer?.cancel();
    await stopWebMediaPipe();
    try {
      await startWebMediaPipe(mode: 'shoulder', containerId: _webContainerId);
      if (!mounted) return;
      setState(() {
        _webStarted = true;
        _status = 'Realtime browser shoulder detection is running.';
      });
      _webPollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        final data = getWebMediaPipeLatest('shoulder');
        if (!mounted || data.isEmpty) {
          return;
        }
        setState(() {
          _leftShoulder = data['leftShoulder'] == true;
          _rightShoulder = data['rightShoulder'] == true;
          _movement = data['movement'] == true;
          _status = (data['feedback'] ?? 'Realtime shoulder detection running.').toString();
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _webStarted = false;
        _status = 'Browser shoulder detection failed to start: $e';
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || _cameraController == null || _poseDetector == null) {
      return;
    }
    _isProcessing = true;
    try {
      final input = buildInputImage(_cameraController, image);
      if (input == null) {
        return;
      }
      final poses = await _poseDetector!.processImage(input);
      if (poses.isEmpty) {
        if (mounted) {
          setState(() {
            _leftShoulder = false;
            _rightShoulder = false;
            _movement = false;
          });
        }
        return;
      }

      final p = poses.first;
      final left = p.landmarks[PoseLandmarkType.leftShoulder];
      final right = p.landmarks[PoseLandmarkType.rightShoulder];

      bool movement = false;
      if (left != null && _lastLeftY != null && (left.y - _lastLeftY!).abs() > 4.5) {
        movement = true;
      }
      if (right != null && _lastRightY != null && (right.y - _lastRightY!).abs() > 4.5) {
        movement = true;
      }

      _lastLeftY = left?.y;
      _lastRightY = right?.y;

      if (mounted) {
        setState(() {
          _leftShoulder = left != null;
          _rightShoulder = right != null;
          _movement = movement;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Shoulder analysis failed on this runtime.';
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
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedback = !_leftShoulder || !_rightShoulder
        ? 'Keep your full upper body in frame.'
        : (_movement ? 'Good shoulder movement detected.' : 'Move shoulders slightly to start detection.');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Shoulder Movement')),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: Column(
            children: [
              Expanded(
                child: LiquidGlassCard(
                  tint: const Color(0xFFD9E7FF),
                  padding: EdgeInsets.zero,
                    child: _isReady
                      ? (kIsWeb
                        ? const WebCameraView(containerId: 'shoulder-web-view')
                        : (_cameraController != null
                          ? FullCameraPreview(controller: _cameraController!)
                          : Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_status, textAlign: TextAlign.center)))))
                      : Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_status, textAlign: TextAlign.center))),
                ),
              ),
              const SizedBox(height: 12),
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startWebShoulder,
                      icon: const Icon(Icons.videocam),
                      label: Text(_webStarted ? 'Restart Browser Camera' : 'Start Browser Camera'),
                    ),
                  ),
                ),
              LiquidGlassCard(
                tint: const Color(0xFFE5D9FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Left Shoulder: ${_leftShoulder ? 'Detected' : 'Missing'}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    Text('Right Shoulder: ${_rightShoulder ? 'Detected' : 'Missing'}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    Text('Movement: ${_movement ? 'Active' : 'Not active'}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(feedback, style: const TextStyle(color: Color(0xFFEAF3FF))),
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
