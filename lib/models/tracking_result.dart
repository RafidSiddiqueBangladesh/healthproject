enum EmotionState { happy, neutral, sad, unknown }

class TrackingResult {
  const TrackingResult({
    required this.faceDetected,
    required this.emotion,
    required this.shoulderActive,
    required this.handActive,
    required this.formScore,
    required this.repCount,
    required this.exerciseName,
    required this.exerciseFeedback,
  });

  final bool faceDetected;
  final EmotionState emotion;
  final bool shoulderActive;
  final bool handActive;
  final double formScore;
  final int repCount;
  final String exerciseName;
  final String exerciseFeedback;

  TrackingResult copyWith({
    bool? faceDetected,
    EmotionState? emotion,
    bool? shoulderActive,
    bool? handActive,
    double? formScore,
    int? repCount,
    String? exerciseName,
    String? exerciseFeedback,
  }) {
    return TrackingResult(
      faceDetected: faceDetected ?? this.faceDetected,
      emotion: emotion ?? this.emotion,
      shoulderActive: shoulderActive ?? this.shoulderActive,
      handActive: handActive ?? this.handActive,
      formScore: formScore ?? this.formScore,
      repCount: repCount ?? this.repCount,
      exerciseName: exerciseName ?? this.exerciseName,
      exerciseFeedback: exerciseFeedback ?? this.exerciseFeedback,
    );
  }
}
