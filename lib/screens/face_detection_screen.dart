import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;

import '../services/mediapipe_web_bridge.dart';
import '../services/ml_input_image.dart';
import '../services/health_result_service.dart';
import '../services/mood_palette_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/beautified_tab_heading.dart';
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
  Map<String, Color> _moodPalette = MoodPaletteService.defaultPalette();
  Map<String, Map<String, dynamic>> _moodThemes = MoodPaletteService.defaultMoodThemes();
  String _activeMood = 'Neutral';
  String _lastAppliedMood = '';
  bool _isSavingResult = false;
  String _saveFeedback = '';
  bool _faceCompatMode = false;
  bool _faceFallbackTried = false;

  Future<void> _loadMoodPalette() async {
    final palette = await MoodPaletteService.loadPalette();
    final moodThemes = await MoodPaletteService.loadMoodThemes();
    final savedMood = await MoodPaletteService.loadSelectedMood();
    if (!mounted) return;
    setState(() {
      _moodPalette = palette;
      _moodThemes = moodThemes;
      _activeMood = savedMood;
    });
    _applyThemeForMood(savedMood);
  }

  void _handleMoodFromEmotion(String emotion) {
    final mood = MoodPaletteService.normalizeMood(emotion);
    if (mood != _activeMood) {
      if (mounted) {
        setState(() {
          _activeMood = mood;
        });
      }
      unawaited(MoodPaletteService.saveSelectedMood(mood));
      _applyThemeForMood(mood);
    }
  }

  void _applyThemeForMood(String mood) {
    if (_lastAppliedMood == mood) return;
    _lastAppliedMood = mood;
    final fallbackColor = _moodPalette[mood] ?? _moodPalette['Neutral']!;
    final fallbackHsl = HSLColor.fromColor(fallbackColor);
    final config = _moodThemes[mood] ?? _moodThemes['Neutral'] ?? const <String, dynamic>{};
    final isLight = config['isLight'] == true;
    final primaryHue = (config['primaryHue'] as num?)?.toDouble() ?? fallbackHsl.hue;
    final accentHue = (config['accentHue'] as num?)?.toDouble() ?? ((fallbackHsl.hue + 40) % 360);
    final orbHues = List<double>.from(
      (config['orbHues'] as List<dynamic>? ?? const <double>[263, 239, 276, 162, 24])
          .map((v) => (v as num).toDouble()),
    );

    final theme = context.read<ThemeProvider>();
    theme.applyThemeSnapshot(
      isLight: isLight,
      primaryHue: primaryHue,
      accentHue: accentHue,
      orbHues: orbHues,
      persist: false,
    );
  }

  Future<void> _saveCurrentResult() async {
    if (_isSavingResult) return;
    if (_emotion == 'Unknown') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for detection first, then save.')),
      );
      return;
    }

    setState(() {
      _isSavingResult = true;
      _saveFeedback = '';
    });

    try {
      await HealthResultService.saveTrackingLog(
        type: 'face_detection',
        label: _emotion,
        score: _emotion == 'No face detected' ? 0.0 : 1.0,
        details: {
          'detected': _emotion != 'No face detected',
          'advice': _advice,
          'status': _status,
        },
      );
      if (!mounted) return;
      setState(() {
        _saveFeedback = 'Saved to health results.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Face result saved to DB.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saveFeedback = 'Save failed. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingResult = false;
        });
      }
    }
  }

  double? _mouthOpenScore(Face face) {
    final upperLip = face.contours[FaceContourType.upperLipBottom]?.points;
    final lowerLip = face.contours[FaceContourType.lowerLipTop]?.points;
    if (upperLip == null || lowerLip == null || upperLip.isEmpty || lowerLip.isEmpty) {
      return null;
    }

    double avgY(List<math.Point<int>> points) {
      final sum = points.fold<double>(0.0, (s, p) => s + p.y.toDouble());
      return sum / points.length;
    }

    final upperY = avgY(upperLip);
    final lowerY = avgY(lowerLip);
    final mouthGap = (lowerY - upperY).abs();

    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;

    double mouthWidth;
    if (leftMouth != null && rightMouth != null) {
      mouthWidth = (rightMouth.x - leftMouth.x).abs().toDouble();
    } else {
      final all = <math.Point<int>>[...upperLip, ...lowerLip];
      final minX = all.map((p) => p.x).reduce(math.min).toDouble();
      final maxX = all.map((p) => p.x).reduce(math.max).toDouble();
      mouthWidth = (maxX - minX).abs();
    }

    if (mouthWidth <= 0) return null;
    return mouthGap / mouthWidth;
  }

  ({String emotion, String advice}) _classifyEmotion(Face face) {
    final smileRaw = face.smilingProbability;
    final leftEyeRaw = face.leftEyeOpenProbability;
    final rightEyeRaw = face.rightEyeOpenProbability;

    // If model cannot classify this frame, keep a stable neutral state.
    if (smileRaw == null && leftEyeRaw == null && rightEyeRaw == null) {
      return (
        emotion: 'Neutral',
        advice: 'Hold steady, keep face centered, and maintain good light for better emotion accuracy.',
      );
    }

    final smile = smileRaw ?? 0.5;
    final leftEye = leftEyeRaw ?? 0.5;
    final rightEye = rightEyeRaw ?? 0.5;
    final eyesOpenAvg = (leftEye + rightEye) / 2.0;
    final mouthOpen = _mouthOpenScore(face) ?? 0.0;

    // 4-emotion model: Happy, Sad, Neutral, Astonished.
    // Prioritize open mouth surprise before smile so "big mouth open" is not mislabeled as Happy.
    if (mouthOpen >= 0.055 || (mouthOpen >= 0.045 && smile < 0.85 && eyesOpenAvg >= 0.45)) {
      return (
        emotion: 'Astonished',
        advice: 'Mouth-open surprise detected. Take a calm breath and relax your expression before continuing.',
      );
    }

    if (smile >= 0.68) {
      return (
        emotion: 'Happy',
        advice: 'Great energy. Keep this positive mood for your workout.',
      );
    }

    if (smile <= 0.35) {
      return (
        emotion: 'Sad',
        advice: 'Low-smile expression detected. Try smile breathing: inhale 4s, exhale 6s, then light stretching.',
      );
    }

    return (
      emotion: 'Neutral',
      advice: 'Balanced mood detected. Start with a light warm-up and maintain focus.',
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadMoodPalette());
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

      try {
        _cameraController = CameraController(
          selected,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );
      } catch (_) {
        _cameraController = CameraController(
          selected,
          ResolutionPreset.medium,
          enableAudio: false,
        );
      }
      await _cameraController!.initialize();

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          enableContours: true,
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
        _handleMoodFromEmotion(_emotion);
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
            _status = _faceCompatMode
                ? 'No face detected (compatibility mode).'
                : 'No face detected.';
          });
        }
        return;
      }

      final result = _classifyEmotion(faces.first);

      if (mounted) {
        setState(() {
          _emotion = result.emotion;
          _advice = result.advice;
          _status = _faceCompatMode
              ? 'Face detected (compatibility mode).'
              : 'Face detected.';
        });
      }
      _handleMoodFromEmotion(result.emotion);
    } catch (e) {
      if (!_faceFallbackTried && !kIsWeb) {
        _faceFallbackTried = true;
        try {
          await _faceDetector?.close();
          _faceDetector = FaceDetector(
            options: FaceDetectorOptions(
              enableClassification: false,
              enableLandmarks: false,
              enableContours: false,
              performanceMode: FaceDetectorMode.fast,
            ),
          );
          if (mounted) {
            setState(() {
              _faceCompatMode = true;
              _status = 'Switched to compatibility mode. Retrying face detection...';
            });
          }
          return;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _status = 'Face analysis failed on this runtime: $e';
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
    final moodColor = _moodPalette[_activeMood] ?? _moodPalette['Neutral']!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Face Detection',
          icon: Icons.tag_faces,
        ),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
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
                tint: moodColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mood Theme: $_activeMood', style: const TextStyle(color: Color(0xFFEAF3FF), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Emotion: $_emotion', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_advice, style: const TextStyle(color: Color(0xFFEAF3FF))),
                    const SizedBox(height: 6),
                    Text(_status, style: const TextStyle(fontSize: 12, color: Color(0xD0EAF3FF))),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingResult ? null : _saveCurrentResult,
                        icon: _isSavingResult
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSavingResult ? 'Saving...' : 'Save Result to DB'),
                      ),
                    ),
                    if (_saveFeedback.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_saveFeedback, style: const TextStyle(fontSize: 12, color: Color(0xFFEAF3FF))),
                    ],
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
