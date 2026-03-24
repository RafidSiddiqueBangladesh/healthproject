import 'package:flutter/material.dart';

import '../widgets/liquid_glass.dart';

class DoctorBookingScreen extends StatefulWidget {
  const DoctorBookingScreen({super.key});

  @override
  State<DoctorBookingScreen> createState() => _DoctorBookingScreenState();
}

class _DoctorBookingScreenState extends State<DoctorBookingScreen> {
  final Set<String> _bookedDoctorIds = <String>{};

  final List<_Doctor> _doctors = const [
    _Doctor(
      id: 'd1',
      name: 'Dr. Sarah Ahmed',
      specialty: 'Cardiology',
      hospital: 'City Care Hospital',
      schedule: '10:00 AM - 1:00 PM',
      fee: 900,
    ),
    _Doctor(
      id: 'd2',
      name: 'Dr. Hasan Karim',
      specialty: 'Orthopedics',
      hospital: 'Green Life Medical',
      schedule: '4:00 PM - 8:00 PM',
      fee: 800,
    ),
    _Doctor(
      id: 'd3',
      name: 'Dr. Mehnaz Rahman',
      specialty: 'General Medicine',
      hospital: 'Evercare Mock Center',
      schedule: '9:00 AM - 12:00 PM',
      fee: 700,
    ),
    _Doctor(
      id: 'd4',
      name: 'Dr. Tanvir Hossain',
      specialty: 'Neurology',
      hospital: 'City Care Hospital',
      schedule: '6:00 PM - 9:00 PM',
      fee: 1200,
    ),
  ];

  void _bookDoctor(_Doctor doctor) {
    if (_bookedDoctorIds.contains(doctor.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${doctor.name} already booked.')),
      );
      return;
    }

    setState(() {
      _bookedDoctorIds.add(doctor.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${doctor.name} booked.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Book Doctors'),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LiquidGlassCard(
                  tint: Color(0xFFDDF1FF),
                  child: Row(
                    children: [
                      Icon(Icons.medical_services, color: Color(0xFFEAF6FF), size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select a doctor and tap book. Data is mock for now and can be replaced with real API data later.',
                          style: TextStyle(color: Color(0xFFEAF6FF), fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ..._doctors.map(_doctorCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _doctorCard(_Doctor doctor) {
    final booked = _bookedDoctorIds.contains(doctor.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        tint: const Color(0xFFFFDDE8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0x30FFFFFF),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    doctor.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                if (booked)
                  const Icon(Icons.check_circle, color: Color(0xFFA7FFEB)),
              ],
            ),
            const SizedBox(height: 10),
            Text('Specialty: ${doctor.specialty}', style: const TextStyle(color: Color(0xFFEAF6FF))),
            Text('Hospital: ${doctor.hospital}', style: const TextStyle(color: Color(0xFFEAF6FF))),
            Text('Schedule: ${doctor.schedule}', style: const TextStyle(color: Color(0xFFEAF6FF))),
            Text('Fee: ${doctor.fee} BDT', style: const TextStyle(color: Color(0xFFEAF6FF))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _bookDoctor(doctor),
              icon: Icon(booked ? Icons.check : Icons.calendar_today),
              label: Text(booked ? 'Booked' : 'Book Doctor'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Doctor {
  const _Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.schedule,
    required this.fee,
  });

  final String id;
  final String name;
  final String specialty;
  final String hospital;
  final String schedule;
  final int fee;
}
