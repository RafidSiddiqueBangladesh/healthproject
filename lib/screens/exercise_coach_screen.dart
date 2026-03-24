import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/exercise_guide_3d.dart';
import '../widgets/liquid_glass.dart';

class ExerciseCoachScreen extends StatefulWidget {
  const ExerciseCoachScreen({
    super.key,
    required this.exerciseName,
    required this.youtubeUrl,
  });

  final String exerciseName;
  final String youtubeUrl;

  @override
  State<ExerciseCoachScreen> createState() => _ExerciseCoachScreenState();
}

class _ExerciseCoachScreenState extends State<ExerciseCoachScreen> {
  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(widget.youtubeUrl));
    }
  }

  Future<void> _openYoutube() async {
    final uri = Uri.parse(widget.youtubeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.exerciseName} Coach'),
      ),
      body: LiquidGlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                Expanded(
                  flex: 6,
                  child: LiquidGlassCard(
                    tint: const Color(0xFFCDE7FF),
                    child: ExerciseGuide3D(
                      height: 320,
                      title: '3D ${widget.exerciseName} Guide',
                      subtitle: 'Mirror this movement before and during your set.',
                      exerciseName: widget.exerciseName,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  flex: 4,
                  child: LiquidGlassCard(
                    tint: const Color(0xFFFFE5BF),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YouTube Tutorial',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: kIsWeb
                                ? Container(
                                    color: const Color(0x22000000),
                                    alignment: Alignment.center,
                                    child: ElevatedButton.icon(
                                      onPressed: _openYoutube,
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('Open YouTube Video'),
                                    ),
                                  )
                                : (_webController == null
                                    ? const Center(child: CircularProgressIndicator())
                                    : WebViewWidget(controller: _webController!)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.play_circle_fill_rounded),
                    label: const Text('Start Timer & Back to List'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
