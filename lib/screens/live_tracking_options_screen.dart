import 'package:flutter/material.dart';

import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';
import 'face_detection_screen.dart';
import 'hand_detection_screen.dart';
import 'live_screen.dart';
import 'shoulder_detection_screen.dart';

class LiveTrackingOptionsScreen extends StatelessWidget {
  const LiveTrackingOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Tracking Options',
          icon: Icons.track_changes,
        ),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
          child: ListView(
            children: [
              const LiquidGlassCard(
                tint: Color(0xFFFFD6E6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Tracking Modules',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Choose tracking modules. The Live tab combines face mood + shoulder + hand movement while you exercise.',
                      style: TextStyle(color: Color(0xDDEAF5FF), fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _OptionTile(
                icon: Icons.tag_faces,
                title: 'Face Detection & Mood',
                subtitle: 'Detect face and classify happy, neutral, sad states.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FaceDetectionScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _OptionTile(
                icon: Icons.accessibility_new,
                title: 'Shoulder Movement',
                subtitle: 'Track shoulder engagement and posture movement.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShoulderDetectionScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _OptionTile(
                icon: Icons.pan_tool_alt,
                title: 'Hand Movement',
                subtitle: 'Detect arm/hand motion for exercise repetition quality.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HandDetectionScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LiveScreen()),
                  );
                },
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Open Live Monitor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: LiquidGlassCard(
        tint: const Color(0xFFD8E5FF),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: const Color(0xFFE9F2FF)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xD7EBF4FF)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFFEAF3FF)),
          ],
        ),
      ),
    );
  }
}
