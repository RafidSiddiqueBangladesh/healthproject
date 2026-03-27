import 'package:flutter/material.dart';

import 'nutrition_screen.dart';
import 'exercise_screen.dart';
import 'health_screen.dart';
import 'profile_screen.dart';
import 'cooking_screen.dart';
import 'live_screen.dart';
import 'cost_analysis_screen.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/theme_customizer_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    NutritionTracker(),
    ExerciseModule(),
    const HealthMonitoring(),
    const LiveScreen(),
    ProfileScreen(),
    CookingScreen(),
    const CostAnalysisScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openThemeCustomizer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      builder: (context) => const ThemeCustomizerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabBody = Stack(
      children: [
        Positioned.fill(child: _widgetOptions.elementAt(_selectedIndex)),
        Positioned(
          right: 16,
          bottom: 94,
          child: SafeArea(
            child: FloatingActionButton.small(
              heroTag: 'theme-customizer-fab',
              onPressed: _openThemeCustomizer,
              child: const Icon(Icons.palette_rounded),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: tabBody,
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
