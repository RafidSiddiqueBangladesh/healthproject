import 'package:flutter/widgets.dart';

class WebCameraView extends StatelessWidget {
  const WebCameraView({
    super.key,
    required this.containerId,
  });

  final String containerId;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
