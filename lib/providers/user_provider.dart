import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as user_model;

class UserProvider with ChangeNotifier {
  user_model.User _user = user_model.User(id: '', name: 'Loading...', points: 0, avatar: '');
  bool _isLoading = true;
  String? _error;

  user_model.User get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );

  Future<void> fetchUserProfile() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _error = 'No active session';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/me'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final userData = data['data'];
          _user = user_model.User(
            id: userData['_id'] ?? userData['id'] ?? '',
            name: userData['name'] ?? 'User',
            points: userData['points'] ?? 0,
            avatar: userData['avatar'] ?? '',
          );
        }
      } else {
        _error = 'Failed to fetch profile';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addPoints(int points) {
    _user.points += points;
    notifyListeners();
  }

  void setAvatar(String avatarUrl) {
    _user.avatar = avatarUrl;
    notifyListeners();
  }
}