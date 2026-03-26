import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class HealthResultService {
  static const String _apiBaseUrl = 'http://localhost:5000';

  static String _normalizeRole(String role) {
    final raw = role.trim().toLowerCase();
    if (raw == 'parent') return 'patient';
    return raw == 'doctor' ? 'doctor' : 'patient';
  }

  static String _extractErrorMessage(http.Response response, {required String fallback}) {
    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final message = (payload['message'] ?? payload['error'] ?? '').toString().trim();
      if (message.isNotEmpty) return message;
    } catch (_) {}
    return '$fallback (status ${response.statusCode})';
  }

  static const Map<String, String> _moodYouTubeQueries = {
    'Happy': 'kindness volunteering helping others short motivation',
    'Sad': 'uplifting motivation emotional healing positive mindset',
    'Neutral': 'mindfulness focus breathing productivity calm',
    'Astonished': 'calming grounding techniques relax mind',
  };

  static Future<void> saveTrackingLog({
    required String type,
    required String label,
    double? score,
    Map<String, dynamic>? details,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/profile/health-tracking-logs'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'type': type,
        'label': label,
        'score': score,
        'details': details ?? <String, dynamic>{},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to save tracking log'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to save tracking log').toString());
    }
  }

  static Future<void> saveBmiLog({
    required double bmi,
    required double heightCm,
    required double weightKg,
    required String category,
    required String suggestion,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/profile/bmi-logs'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'bmi': double.parse(bmi.toStringAsFixed(2)),
        'heightCm': heightCm,
        'weightKg': weightKg,
        'category': category,
        'suggestion': suggestion,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to save BMI log'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to save BMI log').toString());
    }
  }

  static Future<Map<String, dynamic>> fetchHealthSummary({int limitPerType = 3}) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return <String, dynamic>{};

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/api/profile/health-results?limit=$limitPerType'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      return <String, dynamic>{};
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(payload['data'] ?? <String, dynamic>{});
  }

  static Future<List<Map<String, dynamic>>> fetchMoodVideos(String mood, {int maxResults = 5}) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return <Map<String, dynamic>>[];

    final query = _moodYouTubeQueries[mood] ?? _moodYouTubeQueries['Neutral']!;
    final response = await http.get(
      Uri.parse(
        '$_apiBaseUrl/api/ai/youtube/search?q=${Uri.encodeQueryComponent(query)}&maxResults=$maxResults',
      ),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      return <Map<String, dynamic>>[];
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      return <Map<String, dynamic>>[];
    }

    final list = List<Map<String, dynamic>>.from(payload['data'] ?? const <Map<String, dynamic>>[]);
    return list;
  }

  static Future<String> fetchAiMoodSuggestion(String mood) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return '';

    final prompt = '''
You are a supportive wellness assistant.
Current mood: $mood.
Give 2 short practical suggestions and one 1-line encouragement.
Keep total output under 55 words.
''';

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/ai/chat'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'prompt': prompt,
        'temperature': 0.4,
        'maxTokens': 120,
      }),
    );

    if (response.statusCode != 200) {
      return '';
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      return '';
    }

    return (payload['data']?['text'] ?? '').toString();
  }

  static Future<void> saveDoctorReport({
    required String doctorId,
    required String doctorName,
    String? doctorSpecialty,
    String reportTitle = 'Health Report',
    required String reportText,
    Map<String, dynamic>? reportPayload,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/profile/doctor-reports'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'doctorId': doctorId,
        'doctorName': doctorName,
        'doctorSpecialty': doctorSpecialty,
        'reportTitle': reportTitle,
        'reportText': reportText,
        'reportPayload': reportPayload ?? <String, dynamic>{},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to save doctor report'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to save doctor report').toString());
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDoctorReports({
    required String doctorId,
    int limit = 30,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/api/profile/doctor-reports?doctorId=${Uri.encodeQueryComponent(doctorId)}&limit=$limit'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to load doctor reports'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to load doctor reports').toString());
    }

    return List<Map<String, dynamic>>.from(payload['data'] ?? const <Map<String, dynamic>>[]);
  }

  static Future<String> fetchUserRole() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return 'patient';

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/api/profile/role'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      return 'patient';
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      return 'patient';
    }

    return _normalizeRole((payload['data']?['role'] ?? 'patient').toString());
  }

  static Future<void> saveUserRole(String role) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final normalizedRole = _normalizeRole(role);

    final response = await http.put(
      Uri.parse('$_apiBaseUrl/api/profile/role'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'role': normalizedRole}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to save role'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to save role').toString());
    }
  }

  static Future<void> saveDoctorBooking({
    required String doctorId,
    required String doctorName,
    String? doctorSpecialty,
    String bookingStatus = 'booked',
    String? notes,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/profile/doctor-bookings'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'doctorId': doctorId,
        'doctorName': doctorName,
        'doctorSpecialty': doctorSpecialty,
        'bookingStatus': bookingStatus,
        'notes': notes,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to save doctor booking'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to save doctor booking').toString());
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDoctorBookings({
    String? doctorId,
    int limit = 30,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final queryParts = <String>['limit=$limit'];
    if (doctorId != null && doctorId.trim().isNotEmpty) {
      queryParts.add('doctorId=${Uri.encodeQueryComponent(doctorId.trim())}');
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/api/profile/doctor-bookings?${queryParts.join('&')}'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to load doctor bookings'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to load doctor bookings').toString());
    }

    return List<Map<String, dynamic>>.from(payload['data'] ?? const <Map<String, dynamic>>[]);
  }

  static Future<Map<String, dynamic>> startVideoCall({
    required String doctorId,
    required String doctorName,
    String? doctorSpecialty,
    String? callContext,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/profile/video-calls'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'doctorId': doctorId,
        'doctorName': doctorName,
        'doctorSpecialty': doctorSpecialty,
        'callContext': callContext,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to start video call'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to start video call').toString());
    }

    return Map<String, dynamic>.from(payload['data'] ?? const <String, dynamic>{});
  }

  static Future<void> markVideoCallJoined(String callId) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final response = await http.put(
      Uri.parse('$_apiBaseUrl/api/profile/video-calls/${Uri.encodeComponent(callId)}/join'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to join video call'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to join video call').toString());
    }
  }

  static Future<List<Map<String, dynamic>>> fetchVideoCalls({
    String? doctorId,
    int limit = 40,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final queryParts = <String>['limit=$limit'];
    if (doctorId != null && doctorId.trim().isNotEmpty) {
      queryParts.add('doctorId=${Uri.encodeQueryComponent(doctorId.trim())}');
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/api/profile/video-calls?${queryParts.join('&')}'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, fallback: 'Failed to load video calls'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception((payload['message'] ?? 'Failed to load video calls').toString());
    }

    return List<Map<String, dynamic>>.from(payload['data'] ?? const <Map<String, dynamic>>[]);
  }
}
