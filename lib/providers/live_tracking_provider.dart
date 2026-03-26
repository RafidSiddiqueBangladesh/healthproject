import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/tracking_result.dart';
import '../services/mediapipe_web_bridge.dart';
import '../services/live_tracking_service.dart';

class LiveTrackingProvider extends ChangeNotifier {
  final LiveTrackingService _service = LiveTrackingService();
  StreamSubscription<TrackingResult>? _subscription;
  Timer? _webLivePoll;
  int _webRepCount = 0;
  bool _webRepDown = false;
  String _selectedExercise = 'Push-ups';

  bool _isTracking = false;
  bool _isCameraReady = false;
  String? _errorMessage;
  TrackingResult _latest = const TrackingResult(
    faceDetected: false,
    emotion: EmotionState.unknown,
    shoulderActive: false,
    handActive: false,
    formScore: 0,
    repCount: 0,
    exerciseName: 'Push-ups',
    exerciseFeedback: 'Select an exercise and start monitoring.',
  );

  bool get isTracking => _isTracking;
  bool get isCameraReady => _isCameraReady;
  String? get errorMessage => _errorMessage;
  TrackingResult get latest => _latest;
  CameraController? get cameraController => _service.cameraController;

  Future<void> initializeCamera() async {
    try {
      _errorMessage = null;

      if (kIsWeb) {
        _isCameraReady = true;
        notifyListeners();
        return;
      }

      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }

      if (!status.isGranted) {
        _isCameraReady = false;
        _errorMessage = status.isPermanentlyDenied
            ? 'Camera permission permanently denied. Please enable it from app settings.'
            : 'Camera permission is required for live tracking.';
        notifyListeners();
        return;
      }

      await _service.initializeCamera();
      _isCameraReady = _service.isInitialized;
      notifyListeners();
    } catch (e) {
      _isCameraReady = false;
      _errorMessage = 'Camera initialization failed: $e';
      notifyListeners();
    }
  }

  Future<void> openSettingsForPermission() async {
    if (kIsWeb) {
      _errorMessage = 'For browser, allow camera in the site permission popup near the address bar.';
      notifyListeners();
      return;
    }
    await openAppSettings();
  }

  Future<void> startTracking({String exerciseName = 'Push-ups'}) async {
    if (_isTracking) {
      return;
    }
    if (!_isCameraReady) {
      await initializeCamera();
      if (!_isCameraReady) {
        return;
      }
    }

    _isTracking = true;
    _errorMessage = null;
    _service.setExerciseType(exerciseName);
    _selectedExercise = exerciseName;
    _latest = _latest.copyWith(
      exerciseName: exerciseName,
      exerciseFeedback: 'Starting realtime $exerciseName detection...',
      repCount: 0,
    );

    if (kIsWeb) {
      _webRepCount = 0;
      _webRepDown = false;
      _webLivePoll?.cancel();
      try {
        await startWebMediaPipe(mode: 'live', containerId: 'live-web-view');
        _webLivePoll = Timer.periodic(const Duration(milliseconds: 220), (_) {
          final data = getWebMediaPipeLatest('live');
          if (data.isEmpty) {
            return;
          }

          final faceDetected = data['faceDetected'] == true;
          final shoulderActive = data['shoulderActive'] == true;
          final handActive = data['handActive'] == true;
          final emotion = _emotionFromString((data['emotion'] ?? 'Unknown').toString());

          final elbowAngle = _asDouble(data['elbowAngle'], fallback: 180);
          final kneeAngle = _asDouble(data['kneeAngle'], fallback: 180);
          final bodyLineScore = _asDouble(data['bodyLineScore'], fallback: 0.5).clamp(0.0, 1.0);
          final armsUp = data['armsUp'] == true;
          final legsOpen = data['legsOpen'] == true;

          double formScore = 0.0;
          String feedback = 'Move clearly for realtime tracking.';
          final normalized = _selectedExercise.toLowerCase();

          if (normalized.contains('squat')) {
            if (kneeAngle < 100) {
              _webRepDown = true;
            }
            if (_webRepDown && kneeAngle > 158) {
              _webRepCount += 1;
              _webRepDown = false;
            }
            final depth = ((165 - kneeAngle) / 75).clamp(0.0, 1.0);
            formScore = ((depth * 0.7) + (bodyLineScore * 0.3)).clamp(0.0, 1.0);
            feedback = kneeAngle < 105
                ? 'Good squat depth. Push through heels to stand up.'
                : 'Go lower with hips back and knees controlled.';
          } else if (normalized.contains('jump')) {
            if (armsUp && legsOpen) {
              _webRepDown = true;
            }
            if (_webRepDown && !armsUp && !legsOpen) {
              _webRepCount += 1;
              _webRepDown = false;
            }
            final armsScore = armsUp ? 1.0 : 0.35;
            final legsScore = legsOpen ? 1.0 : 0.35;
            formScore = ((armsScore + legsScore) / 2).clamp(0.0, 1.0);
            feedback = (armsUp && legsOpen)
                ? 'Great open-jack position. Return to center to complete rep.'
                : 'Raise arms above shoulders and spread feet wider.';
          } else {
            if (elbowAngle < 98) {
              _webRepDown = true;
            }
            if (_webRepDown && elbowAngle > 152) {
              _webRepCount += 1;
              _webRepDown = false;
            }
            final depth = ((160 - elbowAngle) / 75).clamp(0.0, 1.0);
            formScore = ((depth * 0.65) + (bodyLineScore * 0.35)).clamp(0.0, 1.0);
            feedback = elbowAngle < 102
                ? 'Good push-up depth. Keep core tight and extend fully.'
                : 'Lower chest more while keeping body straight.';
          }

          _latest = TrackingResult(
            faceDetected: faceDetected,
            emotion: emotion,
            shoulderActive: shoulderActive,
            handActive: handActive,
            formScore: formScore,
            repCount: _webRepCount,
            exerciseName: _selectedExercise,
            exerciseFeedback: feedback,
          );
          notifyListeners();
        });
      } catch (e) {
        _isTracking = false;
        _errorMessage = 'Browser live realtime detection failed: $e';
      }
      notifyListeners();
      return;
    }

    _subscription = _service.trackingStream.listen((result) {
      _latest = result;
      notifyListeners();
    });
    try {
      await _service.start(exerciseName: exerciseName);
    } catch (e) {
      _isTracking = false;
      _subscription?.cancel();
      _subscription = null;
      _errorMessage = 'Realtime detection failed to start: $e';
    }
    notifyListeners();
  }

  void updateExerciseSelection(String exerciseName) {
    _selectedExercise = exerciseName;
    if (kIsWeb) {
      _webRepCount = 0;
      _webRepDown = false;
    }
    _service.setExerciseType(exerciseName);
    _latest = _latest.copyWith(
      exerciseName: exerciseName,
      exerciseFeedback: 'Switched to $exerciseName. Start moving to detect reps.',
      repCount: 0,
      formScore: 0,
    );
    notifyListeners();
  }

  Future<void> stopTracking() async {
    if (!_isTracking) {
      return;
    }
    _isTracking = false;

    if (kIsWeb) {
      _webLivePoll?.cancel();
      _webLivePoll = null;
      await stopWebMediaPipe();
      notifyListeners();
      return;
    }

    await _service.stop();
    _subscription?.cancel();
    _subscription = null;
    notifyListeners();
  }

  String get emotionLabel {
    switch (_latest.emotion) {
      case EmotionState.happy:
        return 'Happy';
      case EmotionState.neutral:
        return 'Neutral';
      case EmotionState.sad:
        return 'Sad';
      case EmotionState.unknown:
        return 'Unknown';
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _webLivePoll?.cancel();
    _subscription?.cancel();
    unawaited(_service.dispose());
    super.dispose();
  }

  EmotionState _emotionFromString(String value) {
    final v = value.toLowerCase();
    if (v.contains('happy')) {
      return EmotionState.happy;
    }
    if (v.contains('sad')) {
      return EmotionState.sad;
    }
    if (v.contains('neutral')) {
      return EmotionState.neutral;
    }
    return EmotionState.unknown;
  }

  double _asDouble(Object? value, {required double fallback}) {
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }
}
