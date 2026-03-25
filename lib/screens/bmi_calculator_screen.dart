import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../widgets/liquid_glass.dart';

class BMICalculatorScreen extends StatefulWidget {
  @override
  _BMICalculatorScreenState createState() => _BMICalculatorScreenState();
}

class _BMICalculatorScreenState extends State<BMICalculatorScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  double? _bmi;
  String _bmiCategory = '';
  String _suggestion = '';
  bool _isSaving = false;

  static const String _apiBaseUrl = 'http://localhost:5000';

  Future<void> _calculateBMI() async {
    double weight = double.tryParse(_weightController.text) ?? 0;
    double height = double.tryParse(_heightController.text) ?? 0;
    if (weight > 0 && height > 0) {
      _bmi = weight / ((height / 100) * (height / 100));
      if (_bmi! < 18.5) {
        _bmiCategory = 'Underweight';
        _suggestion = 'Eat more nutritious foods.';
      } else if (_bmi! < 25) {
        _bmiCategory = 'Normal';
        _suggestion = 'Maintain current lifestyle.';
      } else if (_bmi! < 30) {
        _bmiCategory = 'Overweight';
        _suggestion = 'Increase physical activity.';
      } else {
        _bmiCategory = 'Obese';
        _suggestion = 'Consult healthcare provider.';
      }
      setState(() {});
      await _saveBmiToBackend(weight: weight, height: height, bmi: _bmi!);
    }
  }

  Future<void> _saveBmiToBackend({
    required double weight,
    required double height,
    required double bmi,
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      if (mounted) {
        setState(() => _isSaving = true);
      }

      final response = await http.put(
        Uri.parse('$_apiBaseUrl/api/profile/me'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'heightCm': height,
          'weightKg': weight,
          'bmi': double.parse(bmi.toStringAsFixed(2)),
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('BMI saved to your profile')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('BMI calculated but could not be saved')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BMI calculated but save failed')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('BMI Calculator'),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                LiquidGlassCard(
                  tint: const Color(0xFFD3DDFF),
                  child: Column(
                    children: [
                      const Text(
                        'BMI Calculator',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Enter your weight and height to calculate your BMI',
                        style: TextStyle(fontSize: 14, color: Color(0xFFD0E1FF)),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _weightController,
                        decoration: InputDecoration(
                          labelText: 'Weight (kg)',
                          labelStyle: const TextStyle(color: Color(0xFFB0C9FF)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF7A9DFF)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _heightController,
                        decoration: InputDecoration(
                          labelText: 'Height (cm)',
                          labelStyle: const TextStyle(color: Color(0xFFB0C9FF)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF7A9DFF)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _calculateBMI,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        ),
                        child: Text(_isSaving ? 'Saving...' : 'Calculate BMI', style: const TextStyle(fontSize: 16)),
                      ),
                      if (_bmi != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: LiquidGlassCard(
                            tint: const Color(0xFFC8FFE9),
                            child: Column(
                              children: [
                                Text(
                                  'BMI: ${_bmi!.toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Category: $_bmiCategory',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _suggestion,
                                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }
}
