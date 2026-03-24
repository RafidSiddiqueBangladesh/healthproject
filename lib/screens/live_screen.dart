import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/live_tracking_provider.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/exercise_guide_3d.dart';
import '../widgets/full_camera_preview.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/web_camera_view.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  static const List<String> _exerciseNames = ['Push-ups', 'Squats', 'Jumping Jacks'];
  String _selectedExercise = 'Push-ups';
  LiveTrackingProvider? _trackingProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _trackingProvider == null) return;
      _trackingProvider!.initializeCamera();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _trackingProvider ??= context.read<LiveTrackingProvider>();
  }

  @override
  void dispose() {
    _trackingProvider?.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<LiveTrackingProvider>();
    final currentExercise = tracking.latest.exerciseName;
    final counterLabel = currentExercise == 'Squats'
        ? 'Squats Count'
        : (currentExercise == 'Jumping Jacks' ? 'Jumping Jacks Count' : 'Push-ups Count');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Live Exercise Monitor',
          icon: Icons.monitor_heart,
        ),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: ListView(
            children: [
              LiquidGlassCard(
                tint: const Color(0xFFCBEEFF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Realtime Camera Monitor',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 440,
                        child: Stack(
                          children: [
                            Positioned.fill(child: _cameraView(tracking)),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: SizedBox(
                                width: 145,
                                child: LiquidGlassCard(
                                  tint: const Color(0xFFDFE9FF),
                                  padding: const EdgeInsets.all(10),
                                  borderRadius: 16,
                                  child: ExerciseGuide3D(
                                    height: 110,
                                    exerciseName: _selectedExercise,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Large panel: your realtime camera + detection. Small panel: 3D form reference.',
                      style: TextStyle(color: Color(0xDDEDF5FF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassCard(
                tint: const Color(0xFFD4FFD8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Tracking',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _selectedExercise,
                      items: _exerciseNames
                          .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedExercise = value;
                        });
                        context.read<LiveTrackingProvider>().updateExerciseSelection(value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Exercise For Matching Guide',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Now analyzing: $currentExercise',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEAF7FF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x2BFFFFFF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '$counterLabel: ${tracking.latest.repCount}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Form Score: ${(tracking.latest.formScore * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: tracking.latest.formScore,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Realtime Exercise: ${tracking.latest.exerciseName}',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tracking.latest.exerciseFeedback,
                      style: const TextStyle(fontSize: 14, color: Color(0xFFE8F6FF)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: tracking.isTracking
                                ? null
                                : () async {
                                    await tracking.startTracking(exerciseName: _selectedExercise);
                                  },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Monitoring'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: tracking.isTracking
                                ? () async {
                                    await tracking.stopTracking();
                                  }
                                : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                          ),
                        ),
                      ],
                    ),
                    if (tracking.errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        tracking.errorMessage!,
                        style: const TextStyle(color: Color(0xFFFFD3D3), fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await tracking.initializeCamera();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Camera'),
                          ),
                          if (!kIsWeb)
                            OutlinedButton.icon(
                              onPressed: () async {
                                await tracking.openSettingsForPermission();
                              },
                              icon: const Icon(Icons.settings),
                              label: const Text('Open App Settings'),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      kIsWeb
                          ? 'Browser mode: realtime MediaPipe Holistic detection is active for selected exercise.'
                          : 'Device mode: realtime ML Kit face/pose analysis is active for selected exercise.',
                      style: const TextStyle(fontSize: 12, color: Color(0xCFE8F4FF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraView(LiveTrackingProvider tracking) {
    if (kIsWeb) {
      return const WebCameraView(containerId: 'live-web-view');
    }

    final CameraController? controller = tracking.cameraController;
    if (!tracking.isCameraReady || controller == null || !controller.value.isInitialized) {
      return Container(
        color: const Color(0x26000000),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await tracking.initializeCamera();
              },
              icon: const Icon(Icons.videocam),
              label: const Text('Grant Camera Access'),
            ),
          ],
        ),
      );
    }

    return FullCameraPreview(controller: controller);
  }
}
