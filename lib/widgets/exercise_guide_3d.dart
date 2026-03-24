import 'dart:math' as math;

import 'package:flutter/material.dart';

class ExerciseGuide3D extends StatefulWidget {
  const ExerciseGuide3D({
    super.key,
    this.height = 220,
    this.title,
    this.subtitle,
    this.exerciseName = 'Push-ups',
  });

  final double height;
  final String? title;
  final String? subtitle;
  final String exerciseName;

  @override
  State<ExerciseGuide3D> createState() => _ExerciseGuide3DState();
}

class _ExerciseGuide3DState extends State<ExerciseGuide3D> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Text(
            widget.title!,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        if (widget.title != null) const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final angle = math.sin(_controller.value * math.pi * 2) * 0.35;
            final phase = (math.sin(_controller.value * math.pi * 2) + 1) / 2;
            return Center(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: Container(
                  height: widget.height,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x66FFFFFF)),
                  ),
                  child: CustomPaint(
                    painter: _ExercisePainter(
                      phase: phase,
                      exerciseName: widget.exerciseName,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            );
          },
          child: const SizedBox.shrink(),
        ),
        if (widget.subtitle != null) const SizedBox(height: 10),
        if (widget.subtitle != null)
          Text(
            widget.subtitle!,
            style: const TextStyle(color: Color(0xDDEDF5FF)),
          ),
      ],
    );
  }
}

class _ExercisePainter extends CustomPainter {
  _ExercisePainter({required this.phase, required this.exerciseName});

  final double phase;
  final String exerciseName;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFE4F1FF)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final lower = exerciseName.toLowerCase();
    if (lower.contains('squat')) {
      _paintSquat(canvas, size, line, cx);
    } else if (lower.contains('jump')) {
      _paintJumpingJack(canvas, size, line, cx);
    } else {
      _paintPushUp(canvas, size, line, cx);
    }
  }

  void _paintPushUp(Canvas canvas, Size size, Paint line, double cx) {
    final pushDepth = 20 + (phase * 55);
    final y = size.height * 0.56 + (phase * 8);

    final head = Offset(cx - 120 + (phase * 8), y - 34);
    final shoulder = Offset(cx - 82, y - 8);
    final hip = Offset(cx - 8, y + (pushDepth * 0.08));
    final knee = Offset(cx + 58, y + (pushDepth * 0.13));
    final ankle = Offset(cx + 122, y + (pushDepth * 0.18));
    final leftPalm = Offset(cx - 114, y + 32);
    final rightPalm = Offset(cx - 56, y + 32);

    canvas.drawCircle(head, 14, line);
    canvas.drawLine(shoulder, hip, line);
    canvas.drawLine(hip, knee, line);
    canvas.drawLine(knee, ankle, line);
    canvas.drawLine(shoulder, leftPalm, line);
    canvas.drawLine(shoulder, rightPalm, line);

    final floor = Paint()
      ..color = const Color(0x80C9DFFF)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(24, y + 42), Offset(size.width - 24, y + 42), floor);
  }

  void _paintSquat(Canvas canvas, Size size, Paint line, double cx) {
    final squat = phase;
    final hipDrop = 20 + (squat * 44);
    final kneeSpread = 32 + (squat * 20);

    final head = Offset(cx, size.height * 0.22 + (squat * 6));
    final neck = Offset(cx, size.height * 0.30 + (squat * 8));
    final hip = Offset(cx, size.height * 0.48 + hipDrop);

    final leftKnee = Offset(cx - kneeSpread, size.height * 0.68 + (squat * 22));
    final rightKnee = Offset(cx + kneeSpread, size.height * 0.68 + (squat * 22));
    final leftAnkle = Offset(cx - kneeSpread - 8, size.height * 0.88);
    final rightAnkle = Offset(cx + kneeSpread + 8, size.height * 0.88);

    final armRaise = 16 + (squat * 12);
    final leftHand = Offset(cx - 54, neck.dy + armRaise);
    final rightHand = Offset(cx + 54, neck.dy + armRaise);

    canvas.drawCircle(head, 16, line);
    canvas.drawLine(neck, hip, line);
    canvas.drawLine(neck, leftHand, line);
    canvas.drawLine(neck, rightHand, line);
    canvas.drawLine(hip, leftKnee, line);
    canvas.drawLine(leftKnee, leftAnkle, line);
    canvas.drawLine(hip, rightKnee, line);
    canvas.drawLine(rightKnee, rightAnkle, line);
  }

  void _paintJumpingJack(Canvas canvas, Size size, Paint line, double cx) {
    final spread = 0.25 + (phase * 0.75);
    final armSpread = 35 + (spread * 70);
    final legSpread = 18 + (spread * 56);

    final head = Offset(cx, size.height * 0.20);
    final shoulder = Offset(cx, size.height * 0.34);
    final hip = Offset(cx, size.height * 0.57);

    final leftHand = Offset(cx - armSpread, size.height * (0.30 - (spread * 0.11)));
    final rightHand = Offset(cx + armSpread, size.height * (0.30 - (spread * 0.11)));
    final leftFoot = Offset(cx - legSpread, size.height * 0.90);
    final rightFoot = Offset(cx + legSpread, size.height * 0.90);

    canvas.drawCircle(head, 16, line);
    canvas.drawLine(Offset(cx, size.height * 0.25), hip, line);
    canvas.drawLine(shoulder, leftHand, line);
    canvas.drawLine(shoulder, rightHand, line);
    canvas.drawLine(hip, leftFoot, line);
    canvas.drawLine(hip, rightFoot, line);
  }

  @override
  bool shouldRepaint(covariant _ExercisePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.exerciseName != exerciseName;
  }
}
