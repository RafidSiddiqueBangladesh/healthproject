import 'package:flutter/material.dart';
import '../services/health_result_service.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';
import 'live_tracking_options_screen.dart';
import 'bmi_calculator_screen.dart';
import 'doctor_booking_screen.dart';
import 'health_results_screen.dart';
import 'health_suggestions_screen.dart';
import 'service_map_screen.dart';

class HealthMonitoring extends StatefulWidget {
  const HealthMonitoring({super.key});

  @override
  State<HealthMonitoring> createState() => _HealthMonitoringState();
}

class _HealthMonitoringState extends State<HealthMonitoring> {
  String _userRole = 'patient';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final role = await HealthResultService.fetchUserRole();
      if (!mounted) return;
      setState(() {
        _userRole = role == 'doctor' ? 'doctor' : 'patient';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userRole = 'patient';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Health Monitoring',
          icon: Icons.health_and_safety,
        ),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LiquidGlassCard(
                  tint: Color(0xFFFFD6E6),
                  child: Column(
                    children: [
                      Icon(Icons.health_and_safety, size: 50, color: Color(0xFFFFE8F2)),
                      SizedBox(height: 10),
                      Text(
                        'Health Monitoring Features',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Monitor your health, analyze prescriptions, and get emergency help.',
                        style: TextStyle(fontSize: 16, color: Color(0xFFEFF4FF)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServiceMapScreen(type: ServiceMapType.hospital),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('Find Nearest Hospital'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServiceMapScreen(type: ServiceMapType.ambulance),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emergency),
                  label: const Text('Find Nearest Ambulance'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServiceMapScreen(type: ServiceMapType.medicineShop),
                      ),
                    );
                  },
                  icon: const Icon(Icons.local_pharmacy),
                  label: const Text('Find Nearest Medicine Shop'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
                if (_userRole == 'doctor') ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DoctorBookingScreen()),
                      );
                    },
                    icon: const Icon(Icons.video_call),
                    label: const Text('Book Doctor Talk'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DoctorBookingScreen()),
                      );
                    },
                    icon: const Icon(Icons.video_call),
                    label: const Text('Doctor Calling'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LiveTrackingOptionsScreen()),
                    );
                  },
                  icon: const Icon(Icons.track_changes),
                  label: const Text('Tracking & AI Monitor'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BMICalculatorScreen()),
                    );
                  },
                  icon: const Icon(Icons.calculate),
                  label: const Text('BMI Calculator'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HealthResultsScreen()),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Health Results History'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HealthSuggestionsScreen()),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Mood Suggestions'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
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