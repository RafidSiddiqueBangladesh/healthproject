import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/food.dart';
import '../providers/nutrition_provider.dart';
import '../providers/user_provider.dart';

class NutritionTracker extends StatefulWidget {
  @override
  _NutritionTrackerState createState() => _NutritionTrackerState();
}

class _NutritionTrackerState extends State<NutritionTracker> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _spokenText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.listen(
        onResult: (result) => setState(() => _spokenText = result.recognizedWords),
      );
      if (available) {
        setState(() => _isListening = true);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_spokenText.isNotEmpty) {
        final provider = Provider.of<NutritionProvider>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        provider.addFood(Food(name: _spokenText, calories: 100.0));
        userProvider.addPoints(5);
        _spokenText = '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NutritionProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('🍎 Nutrition Tracker'),
        backgroundColor: Colors.orange[700],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[100]!, Colors.green[100]!, Colors.blue[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.orange[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.restaurant_menu, color: Colors.orange[700], size: 30),
                            SizedBox(width: 10),
                            Text(
                              'Add Food Item',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: InputDecoration(
                                  labelText: 'Enter food name',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(Icons.edit, color: Colors.orange[600]),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            IconButton(
                              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.blue[600]),
                              onPressed: _listen,
                              tooltip: 'Voice Input',
                              style: IconButton.styleFrom(backgroundColor: Colors.blue[50]),
                            ),
                            IconButton(
                              icon: Icon(Icons.camera_alt, color: Colors.green[600]),
                              onPressed: () {
                                // Placeholder for OCR
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('OCR feature coming soon! 📷')),
                                );
                              },
                              tooltip: 'OCR Scan',
                              style: IconButton.styleFrom(backgroundColor: Colors.green[50]),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                if (_controller.text.isNotEmpty) {
                                  provider.addFood(Food(name: _controller.text, calories: 100.0));
                                  userProvider.addPoints(5);
                                  _controller.clear();
                                }
                              },
                              child: Text('Add'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[700],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.blue[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.blue[700], size: 30),
                            SizedBox(width: 10),
                            Text(
                              'AI-Powered Daily Routine',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        _buildRoutineItem('🌅 Breakfast', 'Oatmeal with fruits and nuts'),
                        _buildRoutineItem('🌞 Lunch', 'Rice with vegetables and pulses'),
                        _buildRoutineItem('🌙 Dinner', 'Fish or chicken with salad'),
                        _buildRoutineItem('🍪 Snacks', 'Yogurt, fruits, and nuts'),
                        SizedBox(height: 15),
                        Text(
                          '💡 Tip: Stay hydrated and eat mindfully!',
                          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.blue[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.green[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.swap_horiz, color: Colors.green[700], size: 30),
                            SizedBox(width: 10),
                            Text(
                              'Smart Alternatives',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[800]),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        _buildAlternativeItem('Vitamin C', 'Lemon instead of Malta (cheaper & healthier)'),
                        _buildAlternativeItem('Protein', 'Pulses instead of Chicken (cost-effective)'),
                        _buildAlternativeItem('Iron', 'Spinach instead of expensive greens'),
                        SizedBox(height: 15),
                        Text(
                          '💰 Save money while staying healthy!',
                          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.green[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Container(
                height: 200, // Fixed height for scrollable list
                child: ListView.builder(
                  itemCount: provider.foods.length,
                  itemBuilder: (context, index) {
                    final food = provider.foods[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        leading: Icon(Icons.restaurant, color: Colors.orange),
                        title: Text(food.name, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${food.calories} cal'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => provider.removeFood(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Total Calories: ${provider.totalCalories}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineItem(String time, String meal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Text(time, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700])),
          SizedBox(width: 10),
          Expanded(child: Text(meal, style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildAlternativeItem(String nutrient, String alternative) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$nutrient:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
          SizedBox(width: 10),
          Expanded(child: Text(alternative, style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}