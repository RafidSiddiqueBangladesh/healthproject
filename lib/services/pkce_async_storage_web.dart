import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:html' as html;

class _PkceWebStorage extends GotrueAsyncStorage {
  static const String _prefix = 'nutricare.pkce.';

  String _scopedKey(String key) => '$_prefix$key';

  @override
  Future<String?> getItem({required String key}) async {
    return html.window.localStorage[_scopedKey(key)];
  }

  @override
  Future<void> removeItem({required String key}) async {
    html.window.localStorage.remove(_scopedKey(key));
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    html.window.localStorage[_scopedKey(key)] = value;
  }
}

GotrueAsyncStorage createPkceStorageImpl() {
  return _PkceWebStorage();
}
