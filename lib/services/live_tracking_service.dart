import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/tracking_result.dart';
import 'ml_input_image.dart';

class LiveTrackingService {
  final _controller = StreamController<TrackingResult>.broadcast();
  int _repCount = 0;
  bool _isProcessingFrame = false;
  bool _isInitialized = false;
  double _lastShoulderWidth = 0;
  double _lastHandHeight = 0;
  bool _repDownPhase = false;
  int _lastRepTimestampMs = 0;
  String _exerciseName = 'Push-ups';
  
  // Fallback to compatibility mode after consecutive empty pose frames
  int _noPoseFrames = 0;
  bool _liveCompatModeTried = false;

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  PoseDetector? _poseDetector;

  Stream<TrackingResult> get trackingStream => _controller.stream;
  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  bool get hasCameraIssue {
    final camera = _cameraController;
    if (camera == null) return true;
    final value = camera.value;
    return !value.isInitialized || value.hasError;
  }

  void setExerciseType(String exerciseName) {
    final normalized = exerciseName.trim().isEmpty ? 'Push-ups' : exerciseName;
    if (_exerciseName == normalized) {
      return;
    }
    _exerciseName = normalized;
    _repCount = 0;
    _repDownPhase = false;
    _lastShoulderWidth = 0;
    _lastHandHeight = 0;
    _lastRepTimestampMs = 0;
    _noPoseFrames = 0;
    _liveCompatModeTried = false;
  }

  Future<void> initializeCamera() async {
    if (_isInitialized) {
      return;
    }

    final cameras = await availableCameras();
    final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front).toList();
    final selected = front.isNotEmpty ? front.first : cameras.first;

    _cameraController = kIsWeb
        ? CameraController(
            selected,
            ResolutionPreset.medium,
            enableAudio: false,
          )
        : CameraController(
            selected,
            ResolutionPreset.medium,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.yuv420,
          );
    await _cameraController!.initialize();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));

    _isInitialized = true;
  }

  Future<void> reinitializeCamera() async {
    await stop();
    try {
      await _faceDetector?.close();
    } catch (_) {}
    try {
      await _poseDetector?.close();
    } catch (_) {}
    await _cameraController?.dispose();

    _cameraController = null;
    _faceDetector = null;
    _poseDetector = null;
    _isInitialized = false;
    _isProcessingFrame = false;
    _noPoseFrames = 0;
    _liveCompatModeTried = false;

    await initializeCamera();
  }

  Future<void> start({String exerciseName = 'Push-ups'}) async {
    setExerciseType(exerciseName);
    if (!_isInitialized || hasCameraIssue) {
      await reinitializeCamera();
    } else {
      await stop();
      _isProcessingFrame = false;
    }
    if (_cameraController == null) {
      return;
    }

    if (kIsWeb) {
      throw UnsupportedError('Realtime ML detection stream is not supported on web for this runtime.');
    }

    if (_cameraController!.value.isStreamingImages) {
      return;
    }
    await _cameraController!.startImageStream(_processCameraImage);
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isProcessingFrame || !_isInitialized) {
      return;
    }

    _isProcessingFrame = true;
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final inputImage = buildInputImage(_cameraController, cameraImage);
      if (inputImage == null) {
        return;
      }

      final faceDetector = _faceDetector;
      final poseDetector = _poseDetector;
      if (faceDetector == null || poseDetector == null) {
        return;
      }

      final faces = await faceDetector.processImage(inputImage);
      final poses = await poseDetector.processImage(inputImage);

      final faceDetected = faces.isNotEmpty;
      final emotion = _inferEmotion(faces);

      bool shoulderActive = false;
      bool handActive = false;
      double formScore = 0;
      String exerciseFeedback = 'Keep your body fully visible in camera frame.';

      // Handle empty poses with fallback to single-frame compatibility mode
      if (poses.isEmpty) {
        _noPoseFrames += 1;
        
        if (_noPoseFrames > 20 && !_liveCompatModeTried) {
          _liveCompatModeTried = true;
          try {
            await _poseDetector?.close();
            _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.single));
          } catch (_) {}
        }
        
        // Emit result with current state
        _controller.add(
          TrackingResult(
            faceDetected: faceDetected,
            emotion: emotion,
            shoulderActive: shoulderActive,
            handActive: handActive,
            formScore: formScore,
            repCount: _repCount,
            exerciseName: _exerciseName,
            exerciseFeedback: exerciseFeedback,
          ),
        );
        return;
      }
      
      _noPoseFrames = 0;  // Reset counter on successful pose detection
      
      if (poses.isNotEmpty) {
        final pose = poses.first;
        final leftShoulder = _reliableLandmark(pose.landmarks[PoseLandmarkType.leftShoulder], min: 0.35);
        final rightShoulder = _reliableLandmark(pose.landmarks[PoseLandmarkType.rightShoulder], min: 0.35);
        final leftWrist = _reliableLandmark(pose.landmarks[PoseLandmarkType.leftWrist], min: 0.20);
        final rightWrist = _reliableLandmark(pose.landmarks[PoseLandmarkType.rightWrist], min: 0.20);
        final leftElbow = _reliableLandmark(pose.landmarks[PoseLandmarkType.leftElbow], min: 0.20);
        final rightElbow = _reliableLandmark(pose.landmarks[PoseLandmarkType.rightElbow], min: 0.20);
        final leftHip = _reliableLandmark(pose.landmarks[PoseLandmarkType.leftHip], min: 0.25);
        final rightHip = _reliableLandmark(pose.landmarks[PoseLandmarkType.rightHip], min: 0.25);
        final leftKnee = _reliableLandmark(pose.landmarks[PoseLandmarkType.leftKnee], min: 0.25);
        final rightKnee = _reliableLandmark(pose.landmarks[PoseLandmarkType.rightKnee], min: 0.25);
        final leftAnkle = _reliableLandmark(pose.landmarks[PoseLandmarkType.leftAnkle], min: 0.20);
        final rightAnkle = _reliableLandmark(pose.landmarks[PoseLandmarkType.rightAnkle], min: 0.20);

        final visibleCorePoints = <PoseLandmark?>[
          leftShoulder,
          rightShoulder,
          leftElbow,
          rightElbow,
          leftWrist,
          rightWrist,
          leftHip,
          rightHip,
          leftKnee,
          rightKnee,
          leftAnkle,
          rightAnkle,
        ].where((p) => p != null).length;
        final poseCoverageScore = (visibleCorePoints / 12.0).clamp(0.0, 1.0);
        // Keep progress bar responsive even when only part of body is visible.
        formScore = (poseCoverageScore * 0.55).clamp(0.0, 1.0);

        if (leftShoulder != null && rightShoulder != null) {
          final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
          // Normalized threshold: 3.8% frame width movement
          shoulderActive = _lastShoulderWidth > 0 && (shoulderWidth - _lastShoulderWidth).abs() > 0.038;
          _lastShoulderWidth = shoulderWidth;
        }

        if (leftWrist != null && rightWrist != null) {
          final handHeight = ((leftWrist.y + rightWrist.y) / 2.0);
          // Normalized threshold: 4% frame height movement
          handActive = _lastHandHeight > 0 && (_lastHandHeight - handHeight).abs() > 0.04;
          _lastHandHeight = handHeight;
        }

        final normalized = _exerciseName.toLowerCase();
        if (normalized.contains('squat')) {
          final leftKneeAngle = _angle(leftHip, leftKnee, leftAnkle);
          final rightKneeAngle = _angle(rightHip, rightKnee, rightAnkle);
          var kneeAngle = _average(leftKneeAngle, rightKneeAngle);
          
          // Fallback: if average is null, use whichever knee is available
          if (kneeAngle == null && leftKneeAngle != null) {
            kneeAngle = leftKneeAngle;
          } else if (kneeAngle == null && rightKneeAngle != null) {
            kneeAngle = rightKneeAngle;
          }

          if (kneeAngle != null) {
            // Squat thresholds: < 115° down (more lenient), > 150° up (lowered)
            if (kneeAngle < 115) {
              _repDownPhase = true;
            }
            if (_repDownPhase && kneeAngle > 150) {
              if (nowMs - _lastRepTimestampMs > 750) {
                _repCount += 1;
                _lastRepTimestampMs = nowMs;
              }
              _repDownPhase = false;
            }
            final squatDepth = ((160 - kneeAngle) / 70).clamp(0.0, 1.0);
            // Normalize knee symmetry: use normalized delta (0.0-1.0 coords) * 2x multiplier for score spread
            final kneeDelta = ((leftKnee?.y ?? 0) - (rightKnee?.y ?? 0)).abs();
            final kneeSymmetry = 1 - (kneeDelta * 2.0).clamp(0.0, 1.0);
            final squatScore = ((squatDepth * 0.65) + (kneeSymmetry * 0.35)).clamp(0.0, 1.0).toDouble();
            formScore = max(formScore, squatScore);
            exerciseFeedback = kneeAngle < 125
                ? 'Great squat depth. Drive up through your heels.'
                : 'Go lower by bending knees and pushing hips back.';
          } else {
            exerciseFeedback = 'Keep knees and ankles in frame for better squat matching.';
          }
        } else if (normalized.contains('jump')) {
          final shoulderWidth = _distance(leftShoulder, rightShoulder);
          final ankleWidth = _distance(leftAnkle, rightAnkle);
          final shoulderY = _averageValue(leftShoulder?.y, rightShoulder?.y);
          final wristY = _averageValue(leftWrist?.y, rightWrist?.y);

          final armsUp = shoulderY != null && wristY != null ? wristY < (shoulderY - 0.20) : false;
          final legsOpen = shoulderWidth != null && ankleWidth != null ? ankleWidth > (shoulderWidth * 1.55) : false;

          if (armsUp && legsOpen) {
            _repDownPhase = true;
          }
          if (_repDownPhase && !armsUp && !legsOpen) {
            if (nowMs - _lastRepTimestampMs > 750) {
              _repCount += 1;
              _lastRepTimestampMs = nowMs;
            }
            _repDownPhase = false;
          }

          final armsScore = armsUp ? 1.0 : 0.35;
          final legsScore = legsOpen ? 1.0 : 0.35;
          final jackScore = ((armsScore + legsScore) / 2).clamp(0.0, 1.0).toDouble();
          formScore = max(formScore, jackScore);
          exerciseFeedback = (armsUp && legsOpen)
              ? 'Perfect star position. Bring arms down and feet together to complete rep.'
              : 'Open arms above shoulders and spread feet wider.';
        } else {
          final leftElbowAngle = _angle(leftShoulder, leftElbow, leftWrist);
          final rightElbowAngle = _angle(rightShoulder, rightElbow, rightWrist);
          var elbowAngle = _average(leftElbowAngle, rightElbowAngle);
          
          // Fallback: if average is null, use whichever arm is available
          if (elbowAngle == null && leftElbowAngle != null) {
            elbowAngle = leftElbowAngle;
          } else if (elbowAngle == null && rightElbowAngle != null) {
            elbowAngle = rightElbowAngle;
          }
          
          final bodyLine = _angle(leftShoulder, leftHip, leftAnkle);

          if (elbowAngle != null) {
            // Push-ups: < 110° is down (more lenient), > 140° is extended (lowered threshold)
            if (elbowAngle < 110) {
              _repDownPhase = true;
            }
            if (_repDownPhase && elbowAngle > 140) {
              if (nowMs - _lastRepTimestampMs > 750) {
                _repCount += 1;
                _lastRepTimestampMs = nowMs;
              }
              _repDownPhase = false;
            }

            final pushDepth = ((155 - elbowAngle) / 75).clamp(0.0, 1.0);
            final plankScore = bodyLine == null ? 0.5 : (1 - ((180 - bodyLine).abs() / 70)).clamp(0.0, 1.0);
            final pushScore = ((pushDepth * 0.65) + (plankScore * 0.35)).clamp(0.0, 1.0).toDouble();
            formScore = max(formScore, pushScore);
            exerciseFeedback = elbowAngle < 105
                ? 'Good push depth. Keep core tight and push up fully.'
                : 'Lower chest more and keep elbows controlled.';
          } else {
            exerciseFeedback = 'Keep shoulders, elbows, and wrists fully visible for push-up matching.';
          }
        }
      }

      _controller.add(
        TrackingResult(
          faceDetected: faceDetected,
          emotion: emotion,
          shoulderActive: shoulderActive,
          handActive: handActive,
          formScore: formScore,
          repCount: _repCount,
          exerciseName: _exerciseName,
          exerciseFeedback: exerciseFeedback,
        ),
      );
    } catch (_) {
      // Attempt fallback to compatibility mode on error
      if (!_liveCompatModeTried) {
        _liveCompatModeTried = true;
        try {
          await _poseDetector?.close();
          _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.single));
        } catch (_) {}
      }
      
      _controller.add(
        TrackingResult(
          faceDetected: false,
          emotion: EmotionState.unknown,
          shoulderActive: false,
          handActive: false,
          formScore: 0,
          repCount: _repCount,
          exerciseName: _exerciseName,
          exerciseFeedback: 'Detection paused. Keep your full body in frame and retry.',
        ),
      );
    } finally {
      _isProcessingFrame = false;
    }
  }

  EmotionState _inferEmotion(List<Face> faces) {
    if (faces.isEmpty) {
      return EmotionState.unknown;
    }
    final smile = faces.first.smilingProbability;
    if (smile == null) {
      return EmotionState.neutral;
    }
    if (smile > 0.6) {
      return EmotionState.happy;
    }
    if (smile < 0.2) {
      return EmotionState.sad;
    }
    return EmotionState.neutral;
  }

  double? _distance(PoseLandmark? a, PoseLandmark? b) {
    if (a == null || b == null) {
      return null;
    }
    return sqrt(((a.x - b.x) * (a.x - b.x)) + ((a.y - b.y) * (a.y - b.y)));
  }

  PoseLandmark? _reliableLandmark(PoseLandmark? landmark, {double min = 0.5}) {
    if (landmark == null) {
      return null;
    }
    return landmark.likelihood >= min ? landmark : null;
  }

  double? _angle(PoseLandmark? a, PoseLandmark? b, PoseLandmark? c) {
    if (a == null || b == null || c == null) {
      return null;
    }
    final abX = a.x - b.x;
    final abY = a.y - b.y;
    final cbX = c.x - b.x;
    final cbY = c.y - b.y;

    final dot = (abX * cbX) + (abY * cbY);
    final mag1 = sqrt((abX * abX) + (abY * abY));
    final mag2 = sqrt((cbX * cbX) + (cbY * cbY));
    if (mag1 == 0 || mag2 == 0) {
      return null;
    }

    final cosine = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return acos(cosine) * (180 / pi);
  }

  double? _average(double? a, double? b) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return (a + b) / 2;
  }

  double? _averageValue(double? a, double? b) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return (a + b) / 2;
  }

  Future<void> stop() async {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
  }

  Future<void> dispose() async {
    await stop();
    if (_isInitialized) {
      await _faceDetector?.close();
      await _poseDetector?.close();
    }
    await _cameraController?.dispose();
    _cameraController = null;
    _faceDetector = null;
    _poseDetector = null;
    _isInitialized = false;
    _controller.close();
  }
}
