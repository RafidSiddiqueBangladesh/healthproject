import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthResult {
  const AuthResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );

  static const String _webRedirectUrl = String.fromEnvironment(
    'WEB_REDIRECT_URL',
    defaultValue: 'http://localhost:64616',
  );

  List<String> _candidateBaseUrls() {
    return <String>{
      _apiBaseUrl,
      'http://10.0.2.2:5000',
      'http://127.0.0.1:5000',
    }.toList();
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final token = response.session?.accessToken;
      if (token == null || token.isEmpty) {
        return const AuthResult(
          success: false,
          message: 'Login failed: missing Supabase access token.',
        );
      }

      try {
        await _syncUserWithBackend(accessToken: token);
      } catch (_) {
        // Do not block login if backend sync temporarily fails.
      }

      return const AuthResult(success: true, message: 'Sign in successful.');
    } on AuthException catch (e) {
      return AuthResult(success: false, message: e.message);
    } catch (e) {
      return AuthResult(success: false, message: 'Sign in failed: $e');
    }
  }

  Future<AuthResult> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );

      final token = response.session?.accessToken;
      if (token != null && token.isNotEmpty) {
        try {
          await _syncUserWithBackend(accessToken: token, name: name);
        } catch (_) {
          // Do not block sign up if backend sync temporarily fails.
        }
        return const AuthResult(
          success: true,
          message: 'Sign up successful.',
        );
      }

      return const AuthResult(
        success: true,
        message: 'Sign up complete. Check your email to confirm your account, then sign in.',
      );
    } on AuthException catch (e) {
      return AuthResult(success: false, message: e.message);
    } catch (e) {
      return AuthResult(success: false, message: 'Sign up failed: $e');
    }
  }

  Future<AuthResult> signInWithOAuth({required OAuthProvider provider}) async {
    try {
      if (kIsWeb) {
        final currentOrigin = Uri.base.origin;
        final expectedOrigin = Uri.parse(_webRedirectUrl).origin;
        if (currentOrigin != expectedOrigin) {
          return AuthResult(
            success: false,
            message:
                'Open the app on $expectedOrigin before Google login. Current origin: $currentOrigin',
          );
        }
      }

      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? _webRedirectUrl : null,
      );
      final providerName = provider.name[0].toUpperCase() + provider.name.substring(1);
      return AuthResult(
        success: true,
        message: 'Continue with $providerName and come back to the app.',
      );
    } on AuthException catch (e) {
      return AuthResult(success: false, message: e.message);
    } catch (e) {
      return AuthResult(success: false, message: 'OAuth sign in failed: $e');
    }
  }

  Future<AuthResult> syncCurrentSessionWithBackend() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Missing session token after social login.',
      );
    }

    try {
      await _syncUserWithBackend(accessToken: token);
      return const AuthResult(success: true, message: 'Social login successful.');
    } catch (_) {
      return const AuthResult(
        success: true,
        message: 'Social login successful. Backend sync will retry later.',
      );
    }
  }

  Future<void> _syncUserWithBackend({
    required String accessToken,
    String? name,
  }) async {
    final payload = <String, dynamic>{'accessToken': accessToken};
    if (name != null && name.trim().isNotEmpty) {
      payload['name'] = name.trim();
    }

    Object? lastError;
    for (final baseUrl in _candidateBaseUrls()) {
      try {
        final uri = Uri.parse('$baseUrl/api/auth/supabase-login');
        final response = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode < 400) {
          return;
        }
        lastError = Exception('Backend auth sync failed (${response.statusCode}): ${response.body}');
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw Exception(lastError.toString());
    }
  }
}
