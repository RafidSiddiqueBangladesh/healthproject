import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/user_provider.dart';
import 'nutrition_screen.dart';
import 'exercise_screen.dart';
import 'health_screen.dart';
import 'profile_screen.dart';
import 'cooking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    NutritionTracker(),
    ExerciseModule(),
    HealthMonitoring(),
    ProfileScreen(),
    CookingScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NutriCare'),
        backgroundColor: Colors.green[700],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[400]!, Colors.red[400]!, Colors.purple[400]!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant, color: _selectedIndex == 0 ? Colors.orange[300] : Colors.orange[600]),
              label: 'Nutrition',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center, color: _selectedIndex == 1 ? Colors.blue[300] : Colors.blue[600]),
              label: 'Exercise',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.health_and_safety, color: _selectedIndex == 2 ? Colors.red[300] : Colors.red[600]),
              label: 'Health',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, color: _selectedIndex == 3 ? Colors.purple[300] : Colors.purple[600]),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.kitchen, color: _selectedIndex == 4 ? Colors.green[300] : Colors.green[600]),
              label: 'Cooking',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.transparent,
          unselectedItemColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}