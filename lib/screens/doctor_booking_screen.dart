import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/health_result_service.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class DoctorBookingScreen extends StatefulWidget {
  const DoctorBookingScreen({super.key});

  @override
  State<DoctorBookingScreen> createState() => _DoctorBookingScreenState();
}

class _DoctorBookingScreenState extends State<DoctorBookingScreen> {
  final Set<String> _bookedDoctorIds = <String>{};
  final Set<String> _sentReportDoctorIds = <String>{};
  bool _isSendingReport = false;
  bool _isStartingVideoCall = false;
  bool _isLoadingDoctorReports = false;
  bool _isLoadingDoctorCalls = false;
  String _role = 'patient';
  String _selectedDoctorId = 'd1';
  List<Map<String, dynamic>> _doctorReports = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _doctorVideoCalls = <Map<String, dynamic>>[];

  final List<_Doctor> _doctors = const [
    _Doctor(id: 'd1', name: 'Dr. Sarah Ahmed', specialty: 'Cardiology', hospital: 'City Care Hospital', schedule: '10:00 AM - 1:00 PM', fee: 900, phone: '+8801711000001'),
    _Doctor(id: 'd2', name: 'Dr. Hasan Karim', specialty: 'Orthopedics', hospital: 'Green Life Medical', schedule: '4:00 PM - 8:00 PM', fee: 800, phone: '+8801711000002'),
    _Doctor(id: 'd3', name: 'Dr. Mehnaz Rahman', specialty: 'General Medicine', hospital: 'Evercare Mock Center', schedule: '9:00 AM - 12:00 PM', fee: 700, phone: '+8801711000003'),
    _Doctor(id: 'd4', name: 'Dr. Tanvir Hossain', specialty: 'Neurology', hospital: 'City Care Hospital', schedule: '6:00 PM - 9:00 PM', fee: 1200, phone: '+8801711000004'),
    _Doctor(id: 'd5', name: 'Dr. Nusrat Jahan', specialty: 'Endocrinology', hospital: 'Square Mock Clinic', schedule: '11:00 AM - 2:00 PM', fee: 1100, phone: '+8801711000005'),
    _Doctor(id: 'd6', name: 'Dr. Mahmudul Islam', specialty: 'Pulmonology', hospital: 'Central Heart Point', schedule: '5:00 PM - 8:00 PM', fee: 1000, phone: '+8801711000006'),
    _Doctor(id: 'd7', name: 'Dr. Farzana Alam', specialty: 'Nutrition Medicine', hospital: 'Nutrition Care Hub', schedule: '9:30 AM - 12:30 PM', fee: 850, phone: '+8801711000007'),
    _Doctor(id: 'd8', name: 'Dr. Rakib Chowdhury', specialty: 'Sports Medicine', hospital: 'ActiveLife Center', schedule: '3:00 PM - 7:00 PM', fee: 950, phone: '+8801711000008'),
    _Doctor(id: 'd9', name: 'Dr. Shaila Kabir', specialty: 'Dermatology', hospital: 'Prime Skin & Care', schedule: '10:30 AM - 1:30 PM', fee: 780, phone: '+8801711000009'),
    _Doctor(id: 'd10', name: 'Dr. Arif Mahbub', specialty: 'Psychiatry', hospital: 'Mind Wellness Point', schedule: '7:00 PM - 10:00 PM', fee: 1300, phone: '+8801711000010'),
    _Doctor(id: 'd11', name: 'Dr. Rubaida Karim', specialty: 'General Surgery', hospital: 'Apollo Mock Unit', schedule: '12:00 PM - 3:00 PM', fee: 1150, phone: '+8801711000011'),
    _Doctor(id: 'd12', name: 'Dr. Salman Rafi', specialty: 'Physiotherapy', hospital: 'Move Better Center', schedule: '8:00 AM - 11:00 AM', fee: 720, phone: '+8801711000012'),
  ];

  @override
  void initState() {
    super.initState();
    _loadRoleFromProfile();
  }

  Future<void> _loadRoleFromProfile() async {
    String role = 'patient';
    try {
      role = await HealthResultService.fetchUserRole();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _role = role == 'doctor' ? 'doctor' : 'patient';
      _selectedDoctorId = _doctors.any((d) => d.id == _selectedDoctorId) ? _selectedDoctorId : 'd1';
    });
    if (_role == 'doctor') {
      await Future.wait([
        _loadDoctorReports(),
        _loadDoctorVideoCalls(),
      ]);
    }
  }

  Future<void> _setSelectedDoctorId(String doctorId) async {
    if (!mounted) return;
    setState(() {
      _selectedDoctorId = doctorId;
    });
    if (_role == 'doctor') {
      await Future.wait([
        _loadDoctorReports(),
        _loadDoctorVideoCalls(),
      ]);
    }
  }

  Future<void> _loadDoctorReports() async {
    setState(() {
      _isLoadingDoctorReports = true;
    });
    try {
      final reports = await HealthResultService.fetchDoctorReports(doctorId: _selectedDoctorId, limit: 50);
      if (!mounted) return;
      setState(() {
        _doctorReports = reports;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load reports: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDoctorReports = false;
        });
      }
    }
  }

  Future<void> _loadDoctorVideoCalls() async {
    setState(() {
      _isLoadingDoctorCalls = true;
    });
    try {
      final calls = await HealthResultService.fetchVideoCalls(doctorId: _selectedDoctorId, limit: 50);
      if (!mounted) return;
      setState(() {
        _doctorVideoCalls = calls;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load video calls: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDoctorCalls = false;
        });
      }
    }
  }

  Future<void> _bookDoctor(_Doctor doctor) async {
    if (_bookedDoctorIds.contains(doctor.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${doctor.name} already booked.')));
      return;
    }
    try {
      await HealthResultService.saveDoctorBooking(
        doctorId: doctor.id,
        doctorName: doctor.name,
        doctorSpecialty: doctor.specialty,
        bookingStatus: 'booked',
      );
      if (!mounted) return;
      setState(() {
        _bookedDoctorIds.add(doctor.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${doctor.name} booked and saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
    }
  }

  Future<void> _callDoctor(_Doctor doctor) async {
    final uri = Uri.parse('tel:${doctor.phone}');
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not call ${doctor.name}.')));
    }
  }

  Future<void> _startVideoCall(_Doctor doctor) async {
    if (_isStartingVideoCall) return;
    setState(() {
      _isStartingVideoCall = true;
    });

    try {
      final callData = await HealthResultService.startVideoCall(
        doctorId: doctor.id,
        doctorName: doctor.name,
        doctorSpecialty: doctor.specialty,
        callContext: 'doctor_booking_screen',
      );

      final joinUrl = (callData['joinUrl'] ?? '').toString();
      final callId = (callData['id'] ?? '').toString();
      if (joinUrl.isEmpty) {
        throw Exception('Join URL missing from server');
      }

      final launched = await _openCallUrl(joinUrl);
      if (!launched) {
        throw Exception('Could not open video call URL');
      }

      if (callId.isNotEmpty) {
        await HealthResultService.markVideoCallJoined(callId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video call room opened for ${doctor.name}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start video call: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingVideoCall = false;
        });
      }
    }
  }

  Future<void> _joinVideoCallFromDoctorInbox(Map<String, dynamic> call) async {
    try {
      final joinUrl = (call['joinUrl'] ?? '').toString();
      final callId = (call['id'] ?? '').toString();
      if (joinUrl.isEmpty) {
        throw Exception('Join URL unavailable');
      }

      final launched = await _openCallUrl(joinUrl);
      if (!launched) {
        throw Exception('Could not open call URL');
      }

      if (callId.isNotEmpty) {
        await HealthResultService.markVideoCallJoined(callId);
      }

      await _loadDoctorVideoCalls();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join video call: $e')));
    }
  }

  Future<bool> _openCallUrl(String joinUrl) async {
    final uri = Uri.parse(joinUrl);

    // Prefer in-app opening so user stays inside NutriCare.
    final inApp = await launchUrl(uri, mode: LaunchMode.inAppWebView);
    if (inApp) return true;

    final defaultLaunch = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (defaultLaunch) return true;

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _buildHealthReportText(Map<String, dynamic> summary) {
    final trackingRaw = Map<String, dynamic>.from(summary['tracking'] ?? const <String, dynamic>{});
    final bmiRows = List<Map<String, dynamic>>.from(summary['bmi'] ?? const <Map<String, dynamic>>[]);

    final lines = <String>['NutriCare Health Report', 'Generated: ${DateTime.now().toLocal()}', '', 'Latest BMI'];

    if (bmiRows.isEmpty) {
      lines.add('- No BMI logs available');
    } else {
      final latestBmi = bmiRows.first;
      lines.add('- BMI: ${latestBmi['bmi'] ?? 'N/A'}');
      lines.add('- Category: ${latestBmi['category'] ?? 'N/A'}');
      lines.add('- Height: ${latestBmi['heightCm'] ?? 'N/A'} cm');
      lines.add('- Weight: ${latestBmi['weightKg'] ?? 'N/A'} kg');
    }

    lines.add('');
    lines.add('Latest Tracking Results');

    if (trackingRaw.isEmpty) {
      lines.add('- No tracking logs available');
    } else {
      final trackingOrder = <String>['face_detection', 'shoulder_detection', 'hand_detection', 'live_monitor'];
      final keys = trackingOrder.where((k) => trackingRaw.containsKey(k)).toList()..addAll(trackingRaw.keys.where((k) => !trackingOrder.contains(k)));
      for (final key in keys) {
        final rows = List<Map<String, dynamic>>.from(trackingRaw[key] ?? const <Map<String, dynamic>>[]);
        if (rows.isEmpty) continue;
        lines.add('- ${key.replaceAll('_', ' ')}: ${rows.first['label'] ?? 'N/A'}');
      }
    }

    return lines.join('\n');
  }

  Future<void> _sendReportToDoctor(_Doctor doctor) async {
    if (_isSendingReport) return;
    setState(() {
      _isSendingReport = true;
    });

    try {
      final summary = await HealthResultService.fetchHealthSummary(limitPerType: 3);
      final trackingRaw = Map<String, dynamic>.from(summary['tracking'] ?? const <String, dynamic>{});
      final bmiRows = List<Map<String, dynamic>>.from(summary['bmi'] ?? const <Map<String, dynamic>>[]);

      if (trackingRaw.isEmpty && bmiRows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No health report data found. Save results first.')));
        return;
      }

      final reportText = _buildHealthReportText(summary);
      if (!mounted) return;

      final shouldSend = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Send Report to ${doctor.name}?'),
              content: SizedBox(width: 420, child: SingleChildScrollView(child: Text(reportText))),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.send), label: const Text('Send')),
              ],
            ),
          ) ??
          false;

      if (!shouldSend || !mounted) return;

      await HealthResultService.saveDoctorReport(
        doctorId: doctor.id,
        doctorName: doctor.name,
        doctorSpecialty: doctor.specialty,
        reportTitle: 'NutriCare Health Report',
        reportText: reportText,
        reportPayload: summary,
      );

      if (!mounted) return;

      setState(() {
        _sentReportDoctorIds.add(doctor.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Health report sent to ${doctor.name}.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send report: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReport = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(title: 'Book Doctors', icon: Icons.medical_services),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LiquidGlassCard(
                  tint: const Color(0xFFDDF1FF),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Doctor Booking Access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 10),
                      Text(
                        _role == 'doctor'
                            ? 'Role from profile: Doctor. You can view patient reports and join video calls.'
                            : 'Role from profile: Patient. Doctor report inbox is hidden for your account.',
                        style: const TextStyle(color: Color(0xFFEAF6FF), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_role == 'doctor')
                  _doctorInboxSection()
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LiquidGlassCard(
                        tint: const Color(0xFFFFDDE8),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Patient View', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                            SizedBox(height: 10),
                            Text(
                              'You can book doctors, send your report, and start doctor calls here.',
                              style: TextStyle(color: Color(0xFFEAF6FF), fontSize: 14),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Doctor report inbox stays hidden for patient role.',
                              style: TextStyle(color: Color(0xFFEAF6FF), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._doctors.map(_doctorCard),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _doctorInboxSection() {
    return LiquidGlassCard(
      tint: const Color(0xFFD2F7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Doctor Report Inbox', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedDoctorId,
            items: _doctors.map((d) => DropdownMenuItem<String>(value: d.id, child: Text('${d.name} (${d.specialty})'))).toList(),
            onChanged: (value) {
              if (value == null) return;
              _setSelectedDoctorId(value);
            },
            decoration: const InputDecoration(labelText: 'Doctor Profile'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isLoadingDoctorReports || _isLoadingDoctorCalls)
                  ? null
                  : () async {
                      await Future.wait([
                        _loadDoctorReports(),
                        _loadDoctorVideoCalls(),
                      ]);
                    },
              icon: _isLoadingDoctorReports
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(_isLoadingDoctorReports ? 'Loading...' : 'Refresh Reports'),
            ),
          ),
          const SizedBox(height: 10),
          if (_doctorReports.isEmpty)
            const Text('No reports received yet for this doctor.', style: TextStyle(color: Color(0xFFEAF6FF)))
          else
            ..._doctorReports.take(20).map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0x2AFFFFFF), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((r['reportTitle'] ?? 'Health Report').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Sent at: ${(r['createdAt'] ?? '').toString()}', style: const TextStyle(color: Color(0xDDEAF6FF), fontSize: 12)),
                          const SizedBox(height: 6),
                          Text((r['reportText'] ?? '').toString(), style: const TextStyle(color: Color(0xFFEAF6FF))),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          const Text('Video Call Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          if (_isLoadingDoctorCalls)
            const CircularProgressIndicator()
          else if (_doctorVideoCalls.isEmpty)
            const Text('No video call requests yet.', style: TextStyle(color: Color(0xFFEAF6FF)))
          else
            ..._doctorVideoCalls.take(20).map(
              (call) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0x2AFFFFFF), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient: ${(call['patientUserId'] ?? '').toString()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Started: ${(call['startedAt'] ?? '').toString()}', style: const TextStyle(color: Color(0xDDEAF6FF), fontSize: 12)),
                      Text('Status: ${(call['callStatus'] ?? 'requested').toString()}', style: const TextStyle(color: Color(0xDDEAF6FF), fontSize: 12)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _joinVideoCallFromDoctorInbox(call),
                          icon: const Icon(Icons.video_call),
                          label: const Text('Join Video Call'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _doctorCard(_Doctor doctor) {
    final booked = _bookedDoctorIds.contains(doctor.id);
    final reportSent = _sentReportDoctorIds.contains(doctor.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        tint: const Color(0xFFFFDDE8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 20, backgroundColor: Color(0x30FFFFFF), child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: Text(doctor.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                if (reportSent) const Icon(Icons.mark_email_read, color: Color(0xFFA7FFEB)),
                if (!reportSent && booked) const Icon(Icons.check_circle, color: Color(0xFFA7FFEB)),
              ],
            ),
            const SizedBox(height: 10),
            Text('Specialty: ${doctor.specialty}', style: const TextStyle(color: Color(0xFFEAF6FF))),
            Text('Hospital: ${doctor.hospital}', style: const TextStyle(color: Color(0xFFEAF6FF))),
            Text('Schedule: ${doctor.schedule}', style: const TextStyle(color: Color(0xFFEAF6FF))),
            Text('Fee: ${doctor.fee} BDT', style: const TextStyle(color: Color(0xFFEAF6FF))),
            Text('Phone: ${doctor.phone}', style: const TextStyle(color: Color(0xFFEAF6FF))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 165,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _bookDoctor(doctor);
                    },
                    icon: Icon(booked ? Icons.check : Icons.calendar_today),
                    label: Text(booked ? 'Booked' : 'Book Doctor'),
                  ),
                ),
                SizedBox(
                  width: 165,
                  child: ElevatedButton.icon(
                    onPressed: _isSendingReport ? null : () => _sendReportToDoctor(doctor),
                    icon: Icon(reportSent ? Icons.done_all : Icons.send),
                    label: Text(reportSent ? 'Report Sent' : 'Send Report'),
                  ),
                ),
                SizedBox(
                  width: 165,
                  child: ElevatedButton.icon(
                    onPressed: _isStartingVideoCall ? null : () => _startVideoCall(doctor),
                    icon: const Icon(Icons.video_call),
                    label: Text(_isStartingVideoCall ? 'Starting...' : 'Video Call'),
                  ),
                ),
                SizedBox(
                  width: 165,
                  child: ElevatedButton.icon(
                    onPressed: () => _callDoctor(doctor),
                    icon: const Icon(Icons.call),
                    label: const Text('Call Doctor'),
                  ),
                ),
              ],
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
    required this.phone,
  });

  final String id;
  final String name;
  final String specialty;
  final String hospital;
  final String schedule;
  final int fee;
  final String phone;
}
