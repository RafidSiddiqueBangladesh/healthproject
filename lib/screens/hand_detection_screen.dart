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

class HandDetectionScreen extends StatefulWidget {
  const HandDetectionScreen({super.key});

  @override
  State<HandDetectionScreen> createState() => _HandDetectionScreenState();
}

class _HandDetectionScreenState extends State<HandDetectionScreen> {
  final String _webContainerId = 'hand-web-view';
  Timer? _webPollTimer;
  bool _webStarted = false;
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isReady = false;
  bool _isProcessing = false;

  bool _leftHand = false;
  bool _rightHand = false;
  List<String> _missing = const [];
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
          _status = 'Tap Start Browser Camera to begin hand/finger detection.';
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
        _status = 'Realtime hand/finger detection is running.';
      });
    } catch (e) {
      setState(() {
        _status = 'Hand detection is unavailable on this platform/runtime: $e';
      });
    }
  }

  Future<void> _startWebHand() async {
    _webPollTimer?.cancel();
    await stopWebMediaPipe();
    try {
      await startWebMediaPipe(mode: 'hand', containerId: _webContainerId);
      if (!mounted) return;
      setState(() {
        _webStarted = true;
        _status = 'Realtime browser hand/finger detection is running.';
      });
      _webPollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        final data = getWebMediaPipeLatest('hand');
        if (!mounted || data.isEmpty) {
          return;
        }
        final missingRaw = data['missing'];
        final missing = missingRaw is List ? missingRaw.map((e) => e.toString()).toList() : <String>[];
        setState(() {
          _leftHand = data['leftHand'] == true;
          _rightHand = data['rightHand'] == true;
          _missing = missing;
          _status = 'Realtime browser hand/finger detection is running.';
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _webStarted = false;
        _status = 'Browser hand detection failed to start: $e';
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
            _leftHand = false;
            _rightHand = false;
            _missing = const ['left hand', 'right hand'];
          });
        }
        return;
      }

      final p = poses.first;
      final leftWrist = p.landmarks[PoseLandmarkType.leftWrist];
      final rightWrist = p.landmarks[PoseLandmarkType.rightWrist];
      final leftThumb = p.landmarks[PoseLandmarkType.leftThumb];
      final rightThumb = p.landmarks[PoseLandmarkType.rightThumb];
      final leftIndex = p.landmarks[PoseLandmarkType.leftIndex];
      final rightIndex = p.landmarks[PoseLandmarkType.rightIndex];
      final leftPinky = p.landmarks[PoseLandmarkType.leftPinky];
      final rightPinky = p.landmarks[PoseLandmarkType.rightPinky];

      final missing = <String>[];
      bool leftHand = leftWrist != null;
      bool rightHand = rightWrist != null;

      if (!leftHand) missing.add('left hand');
      if (!rightHand) missing.add('right hand');
      if (leftThumb == null) missing.add('left thumb');
      if (rightThumb == null) missing.add('right thumb');
      if (leftIndex == null) missing.add('left index');
      if (rightIndex == null) missing.add('right index');
      if (leftPinky == null) missing.add('left pinky');
      if (rightPinky == null) missing.add('right pinky');

      if (mounted) {
        setState(() {
          _leftHand = leftHand;
          _rightHand = rightHand;
          _missing = missing;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Hand analysis failed on this runtime.';
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
    final allGood = _missing.isEmpty && (_leftHand || _rightHand);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Hand Detection')),
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
                        ? const WebCameraView(containerId: 'hand-web-view')
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
                      onPressed: _startWebHand,
                      icon: const Icon(Icons.videocam),
                      label: Text(_webStarted ? 'Restart Browser Camera' : 'Start Browser Camera'),
                    ),
                  ),
                ),
              LiquidGlassCard(
                tint: const Color(0xFFD8FFE4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Left Hand: ${_leftHand ? 'Detected' : 'Not detected'}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    Text('Right Hand: ${_rightHand ? 'Detected' : 'Not detected'}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      allGood ? 'All visible fingers are correct.' : 'Missing: ${_missing.join(', ')}',
                      style: const TextStyle(color: Color(0xFFE9F8FF)),
                    ),
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
