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
  String _exerciseName = 'Push-ups';

  CameraController? _cameraController;
  late final FaceDetector _faceDetector;
  late final PoseDetector _poseDetector;

  Stream<TrackingResult> get trackingStream => _controller.stream;
  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;

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

  Future<void> start({String exerciseName = 'Push-ups'}) async {
    setExerciseType(exerciseName);
    await initializeCamera();
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
      final inputImage = buildInputImage(_cameraController, cameraImage);
      if (inputImage == null) {
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      final poses = await _poseDetector.processImage(inputImage);

      final faceDetected = faces.isNotEmpty;
      final emotion = _inferEmotion(faces);

      bool shoulderActive = false;
      bool handActive = false;
      double formScore = 0;
      String exerciseFeedback = 'Keep your body fully visible in camera frame.';

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
        final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
        final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
        final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
        final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
        final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
        final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
        final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
        final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
        final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
        final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
        final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

        if (leftShoulder != null && rightShoulder != null) {
          final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
          shoulderActive = (shoulderWidth - _lastShoulderWidth).abs() > 4.8;
          _lastShoulderWidth = shoulderWidth;
        }

        if (leftWrist != null && rightWrist != null) {
          final handHeight = ((leftWrist.y + rightWrist.y) / 2.0);
          handActive = (_lastHandHeight - handHeight).abs() > 5.4;

          if (leftShoulder != null && rightShoulder != null) {
            final shoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
            final delta = handHeight - shoulderY;

            if (delta > 42) {
              _repDownPhase = true;
            }
            if (_repDownPhase && delta < 10) {
              _repCount += 1;
              _repDownPhase = false;
            }

            final shoulderSymmetry = 1 - ((leftShoulder.y - rightShoulder.y).abs() / 70).clamp(0.0, 1.0);
            final handBalance = 1 - ((leftWrist.y - rightWrist.y).abs() / 90).clamp(0.0, 1.0);
            formScore = ((shoulderSymmetry * 0.55) + (handBalance * 0.45)).clamp(0.0, 1.0);
          }
          _lastHandHeight = handHeight;
        }

        final normalized = _exerciseName.toLowerCase();
        if (normalized.contains('squat')) {
          final leftKneeAngle = _angle(leftHip, leftKnee, leftAnkle);
          final rightKneeAngle = _angle(rightHip, rightKnee, rightAnkle);
          final kneeAngle = _average(leftKneeAngle, rightKneeAngle);

          if (kneeAngle != null) {
            // More conservative: increased threshold from 100 to 110, require more extension
            if (kneeAngle < 110) {
              _repDownPhase = true;
            }
            if (_repDownPhase && kneeAngle > 165) {
              _repCount += 1;
              _repDownPhase = false;
            }
            final squatDepth = ((165 - kneeAngle) / 75).clamp(0.0, 1.0);
            final kneeSymmetry = 1 - (((leftKnee?.y ?? 0) - (rightKnee?.y ?? 0)).abs() / 100).clamp(0.0, 1.0);
            formScore = ((squatDepth * 0.65) + (kneeSymmetry * 0.35)).clamp(0.0, 1.0);
            exerciseFeedback = kneeAngle < 115
                ? 'Great squat depth. Drive up through your heels.'
                : 'Go lower by bending knees and pushing hips back.';
          }
        } else if (normalized.contains('jump')) {
          final shoulderWidth = _distance(leftShoulder, rightShoulder);
          final ankleWidth = _distance(leftAnkle, rightAnkle);
          final shoulderY = _averageValue(leftShoulder?.y, rightShoulder?.y);
          final wristY = _averageValue(leftWrist?.y, rightWrist?.y);

          final armsUp = shoulderY != null && wristY != null ? wristY < (shoulderY - 20) : false;
          final legsOpen = shoulderWidth != null && ankleWidth != null ? ankleWidth > (shoulderWidth * 1.55) : false;

          if (armsUp && legsOpen) {
            _repDownPhase = true;
          }
          if (_repDownPhase && !armsUp && !legsOpen) {
            _repCount += 1;
            _repDownPhase = false;
          }

          final armsScore = armsUp ? 1.0 : 0.35;
          final legsScore = legsOpen ? 1.0 : 0.35;
          formScore = ((armsScore + legsScore) / 2).clamp(0.0, 1.0);
          exerciseFeedback = (armsUp && legsOpen)
              ? 'Perfect star position. Bring arms down and feet together to complete rep.'
              : 'Open arms above shoulders and spread feet wider.';
        } else {
          final leftElbowAngle = _angle(leftShoulder, leftElbow, leftWrist);
          final rightElbowAngle = _angle(rightShoulder, rightElbow, rightWrist);
          final elbowAngle = _average(leftElbowAngle, rightElbowAngle);
          final bodyLine = _angle(leftShoulder, leftHip, leftAnkle);

          if (elbowAngle != null) {
            // More conservative: increased threshold from 98 to 105, require more extension
            if (elbowAngle < 105) {
              _repDownPhase = true;
            }
            if (_repDownPhase && elbowAngle > 160) {
              _repCount += 1;
              _repDownPhase = false;
            }

            final pushDepth = ((160 - elbowAngle) / 75).clamp(0.0, 1.0);
            final plankScore = bodyLine == null ? 0.5 : (1 - ((180 - bodyLine).abs() / 70)).clamp(0.0, 1.0);
            formScore = ((pushDepth * 0.65) + (plankScore * 0.35)).clamp(0.0, 1.0);
            exerciseFeedback = elbowAngle < 110
                ? 'Good push depth. Keep core tight and push up fully.'
                : 'Lower chest more and keep elbows controlled.';
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
      await _faceDetector.close();
      await _poseDetector.close();
    }
    await _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;
    _controller.close();
  }
}
