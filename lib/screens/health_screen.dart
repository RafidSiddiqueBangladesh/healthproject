import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';

class HealthMonitoring extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🏥 Health Monitoring'),
        backgroundColor: Colors.red[700],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[100]!, Colors.pink[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.health_and_safety, size: 50, color: Colors.red),
                      SizedBox(height: 10),
                      Text(
                        'Health Monitoring Features',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red[800]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Monitor your health, analyze prescriptions, and get emergency help.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HospitalMapScreen()),
                  );
                },
                icon: Icon(Icons.location_on),
                label: Text('Find Nearest Hospital'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Book Doctor Talk'),
                      content: Text('Select a time slot for teleconsultation.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Doctor talk booked! Call coming soon.')),
                            );
                          },
                          child: Text('Book Now'),
                        ),
                      ],
                    ),
                  );
                },
                icon: Icon(Icons.video_call),
                label: Text('Book Doctor Talk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HospitalMapScreen extends StatefulWidget {
  @override
  _HospitalMapScreenState createState() => _HospitalMapScreenState();
}

class _HospitalMapScreenState extends State<HospitalMapScreen> {
  late WebViewController controller;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      controller = WebViewController()
        ..loadRequest(Uri.parse('https://www.google.com/maps/search/hospitals+near+me'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nearest Hospitals'),
        backgroundColor: Colors.red[700],
      ),
      body: kIsWeb
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Maps not available on web. Open in browser?'),
                  ElevatedButton(
                    onPressed: () async {
                      const url = 'https://www.google.com/maps/search/hospitals+near+me';
                      if (await canLaunch(url)) {
                        await launch(url);
                      }
                    },
                    child: Text('Open Maps'),
                  ),
                ],
              ),
            )
          : WebViewWidget(controller: controller),
    );
  }
}