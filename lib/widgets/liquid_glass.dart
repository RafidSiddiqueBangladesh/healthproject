import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class LiquidGlassBackground extends StatefulWidget {
  const LiquidGlassBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<LiquidGlassBackground> createState() => _LiquidGlassBackgroundState();
}

class _LiquidGlassBackgroundState extends State<LiquidGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final orbColors = theme.orbColors;

    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final gradientColors = _buildGradientFromOrbs(orbColors, theme.isLight);

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                ),
              ),
              for (int i = 0; i < orbColors.length; i++)
                _AnimatedOrb(
                  color: orbColors[i],
                  index: i,
                  timeValue: t,
                ),
              _MeshOverlay(colors: orbColors),
              widget.child,
            ],
          );
        },
      ),
    );
  }

  List<Color> _buildGradientFromOrbs(List<Color> colors, bool isLight) {
    if (colors.length < 3) {
      return [
        isLight ? const Color(0xFFEAF2FF) : const Color(0xFF0E1324),
        isLight ? const Color(0xFFDCE9FF) : const Color(0xFF151A30),
        isLight ? const Color(0xFFF4F8FF) : const Color(0xFF131A2C),
      ];
    }
    return [
      Color.alphaBlend(colors[0].withValues(alpha: 0.38), isLight ? const Color(0xFFEAF2FF) : const Color(0xFF0E1324)),
      Color.alphaBlend(colors[1].withValues(alpha: 0.34), isLight ? const Color(0xFFE4EEFF) : const Color(0xFF141A32)),
      Color.alphaBlend(colors[2].withValues(alpha: 0.32), isLight ? const Color(0xFFF4F8FF) : const Color(0xFF10172A)),
    ];
  }
}

class _AnimatedOrb extends StatelessWidget {
  const _AnimatedOrb({
    required this.color,
    required this.index,
    required this.timeValue,
  });

  final Color color;
  final int index;
  final double timeValue;

  @override
  Widget build(BuildContext context) {
    final phase = index * 0.19;
    final waveX = math.sin((timeValue + phase) * math.pi * 2);
    final waveY = math.cos((timeValue * 0.9 + phase) * math.pi * 2);

    final width = 280.0 + (index * 46.0);
    final height = 240.0 + (index * 52.0);

    return Align(
      alignment: Alignment(waveX * 0.74, waveY * 0.78),
      child: Transform.scale(
        scale: 0.92 + 0.25 * math.sin((timeValue + phase) * math.pi * 2),
        child: IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0),
                  ],
                  stops: const [0.2, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeshOverlay extends StatelessWidget {
  const _MeshOverlay({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final c0 = colors.isNotEmpty ? colors[0] : const Color(0x596B0ACE);
    final c1 = colors.length > 1 ? colors[1] : const Color(0x590874DE);
    final c2 = colors.length > 2 ? colors[2] : const Color(0x590AA67A);

    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
        child: Opacity(
          opacity: 0.42,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.65, -0.2),
                radius: 0.9,
                colors: [
                  c0,
                  Colors.transparent,
                ],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, -0.8),
                  radius: 0.95,
                  colors: [
                    c1,
                    Colors.transparent,
                  ],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 0.95),
                    radius: 1,
                    colors: [
                      c2,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 24,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    const baseTint = Color(0xFFDDE9FF);
    final effectiveTint = Color.alphaBlend(
      (tint ?? baseTint).withValues(alpha: 0.45),
      baseTint,
    );
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  effectiveTint.withValues(alpha: 0.28),
                  effectiveTint.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.38),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF02070D).withValues(alpha: 0.32),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <BottomNavigationBarItem>[
    BottomNavigationBarItem(icon: Icon(Icons.restaurant_rounded), label: 'Nutrition'),
    BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded), label: 'Exercise'),
    BottomNavigationBarItem(icon: Icon(Icons.health_and_safety_rounded), label: 'Health'),
    BottomNavigationBarItem(icon: Icon(Icons.videocam_rounded), label: 'Live'),
    BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
    BottomNavigationBarItem(icon: Icon(Icons.kitchen_rounded), label: 'Cooking'),
    BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Cost'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: LiquidGlassCard(
        borderRadius: 30,
        padding: EdgeInsets.zero,
        tint: const Color(0xFFB6F7FF),
        child: BottomNavigationBar(
          items: _items,
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFFFFFFF),
          unselectedItemColor: const Color(0xFFB6D9DD),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
