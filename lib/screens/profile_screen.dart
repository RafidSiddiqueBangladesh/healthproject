import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  double? _bmi;
  String _bmiCategory = '';
  String _suggestion = '';

  void _calculateBMI() {
    double weight = double.tryParse(_weightController.text) ?? 0;
    double height = double.tryParse(_heightController.text) ?? 0;
    if (weight > 0 && height > 0) {
      _bmi = weight / ((height / 100) * (height / 100));
      if (_bmi! < 18.5) {
        _bmiCategory = 'Underweight';
        _suggestion = 'Eat more nutritious foods like nuts, fruits, and proteins. Suggested exercise: Strength training.';
      } else if (_bmi! < 25) {
        _bmiCategory = 'Normal';
        _suggestion = 'Maintain with balanced diet and regular exercise. Suggested food: Vegetables, grains. Exercise: Cardio.';
      } else if (_bmi! < 30) {
        _bmiCategory = 'Overweight';
        _suggestion = 'Reduce calories, increase activity. Suggested food: Low-fat options. Exercise: Walking, jogging.';
      } else {
        _bmiCategory = 'Obese';
        _suggestion = 'Consult doctor, focus on healthy eating. Suggested food: Salads, lean meats. Exercise: Yoga, swimming.';
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('👤 Profile'),
        backgroundColor: Colors.purple[700],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[100]!, Colors.blue[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          'Name: ${userProvider.user.name}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Points: ${userProvider.user.points}',
                          style: TextStyle(fontSize: 18, color: Colors.green[700]),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Achievements',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        if (userProvider.user.points >= 50)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star, color: Colors.yellow),
                              Text(' Health Champion!', style: TextStyle(color: Colors.yellow[800])),
                            ],
                          )
                        else
                          Text('Keep earning points for badges!', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          'BMI Calculator',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple[800]),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: _weightController,
                          decoration: InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: _heightController,
                          decoration: InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _calculateBMI,
                          child: Text('Calculate BMI'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                        ),
                        if (_bmi != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              children: [
                                Text('BMI: ${_bmi!.toStringAsFixed(1)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('Category: $_bmiCategory', style: TextStyle(color: Colors.blue)),
                                Text('Suggestion: $_suggestion', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                      ],
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
                        colors: [Colors.white, Colors.teal[50]!],
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
                              Icon(Icons.message, color: Colors.teal[700], size: 30),
                              SizedBox(width: 10),
                              Text(
                                'Messages',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Messaging feature coming soon!')),
                              );
                            },
                            icon: Icon(Icons.send),
                            label: Text('Send Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[600],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
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
                        colors: [Colors.white, Colors.indigo[50]!],
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
                              Icon(Icons.group, color: Colors.indigo[700], size: 30),
                              SizedBox(width: 10),
                              Text(
                                'Find Similar Profiles',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo[800]),
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                          Text(
                            'Connect with people who have similar health conditions (e.g., diabetes) and live within 5 km.',
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Placeholder for finding profiles
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Similar Profiles Found'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: CircleAvatar(child: Icon(Icons.person)),
                                        title: Text('John Doe'),
                                        subtitle: Text('Diabetes, 3 km away'),
                                        trailing: ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Request sent to John Doe!')),
                                            );
                                          },
                                          child: Text('Send Request'),
                                        ),
                                      ),
                                      ListTile(
                                        leading: CircleAvatar(child: Icon(Icons.person)),
                                        title: Text('Jane Smith'),
                                        subtitle: Text('Diabetes, 4 km away'),
                                        trailing: ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Request sent to Jane Smith!')),
                                            );
                                          },
                                          child: Text('Send Request'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: Icon(Icons.search),
                            label: Text('Find Profiles'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo[600],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
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