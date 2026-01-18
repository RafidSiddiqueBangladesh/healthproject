import 'package:flutter/material.dart';

class CookingScreen extends StatefulWidget {
  @override
  _CookingScreenState createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  final TextEditingController _inventoryController = TextEditingController();
  String _suggestion = 'Add inventory to get suggestions.';
  List<String> _recipes = [];

  void _updateSuggestion() {
    // Placeholder logic
    if (_inventoryController.text.contains('rice')) {
      _suggestion = 'Cook rice with vegetables. Utilize leftovers for farming compost.';
      _recipes = ['Vegetable Fried Rice', 'Rice Porridge', 'Rice Salad'];
    } else if (_inventoryController.text.contains('chicken')) {
      _suggestion = 'Make chicken curry or stir-fry. Use bones for broth.';
      _recipes = ['Chicken Curry', 'Chicken Stir-Fry', 'Chicken Soup'];
    } else {
      _suggestion = 'Cook simple meals at low cost. Use food waste for organic farming.';
      _recipes = ['Simple Vegetable Stew', 'Basic Salad', 'Oatmeal'];
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🍳 Cooking Assistant'),
        backgroundColor: Colors.orange[700],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[200]!, Colors.orange[200]!, Colors.yellow[200]!, Colors.green[200]!, Colors.blue[200]!, Colors.indigo[200]!, Colors.purple[200]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What\'s in your kitchen?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown[800]),
              ),
              SizedBox(height: 10),
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
                            Icon(Icons.kitchen, color: Colors.orange[700], size: 30),
                            SizedBox(width: 10),
                            Text('Inventory Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown[700])),
                          ],
                        ),
                        SizedBox(height: 15),
                        TextField(
                          controller: _inventoryController,
                          decoration: InputDecoration(
                            labelText: 'Enter ingredients (e.g., rice, chicken, vegetables)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.restaurant_menu, color: Colors.orange[600]),
                          ),
                        ),
                        SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // OCR placeholder
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OCR coming soon! 📷')));
                              },
                              icon: Icon(Icons.camera_alt),
                              label: Text('Scan Receipt'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Voice placeholder
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voice input coming soon! 🎤')));
                              },
                              icon: Icon(Icons.mic),
                              label: Text('Voice Input'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: _updateSuggestion,
                          child: Text('Get Cooking Ideas'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Smart Suggestions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red[800]),
              ),
              SizedBox(height: 10),
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.red[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.yellow[700], size: 30),
                            SizedBox(width: 10),
                            Text('Tip:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700])),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          _suggestion,
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              if (_recipes.isNotEmpty) ...[
                Text(
                  'Recipe Ideas',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[800]),
                ),
                SizedBox(height: 10),
                ..._recipes.map((recipe) => Card(
                  elevation: 5,
                  margin: EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: Icon(Icons.restaurant, color: Colors.green[600]),
                    title: Text(recipe, style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Icon(Icons.arrow_forward_ios, color: Colors.green[600]),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recipe details coming soon for $recipe!')));
                    },
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}