import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/web_iframe_registry.dart'
  if (dart.library.html) '../utils/web_iframe_registry_web.dart' as web_iframe;

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
  String? _webViewType;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(widget.youtubeUrl));
    } else {
      final videoId = _extractVideoId(widget.youtubeUrl);
      final viewType = 'coach-youtube-$videoId';
      _webViewType = viewType;
      web_iframe.registerIFrame(
        viewType: viewType,
        src: 'https://www.youtube.com/embed/$videoId?autoplay=0&modestbranding=1&rel=0',
      );
    }
  }

  String _extractVideoId(String url) {
    final uri = Uri.parse(url);
    if (uri.pathSegments.contains('embed')) {
      return uri.pathSegments.last;
    }
    final v = uri.queryParameters['v'];
    return (v == null || v.isEmpty) ? '2W4ZNSwoW_4' : v;
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
                                ? (_webViewType == null
                                    ? const Center(child: CircularProgressIndicator())
                                    : HtmlElementView(viewType: _webViewType!))
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
                    label: const Text('Start Timer and Return to Exercise List'),
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
