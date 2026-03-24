import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

class _PkceWebStorage extends GotrueAsyncStorage {
  static const String _prefix = 'nutricare.pkce.';

  String _scopedKey(String key) => '$_prefix$key';

  @override
  Future<String?> getItem({required String key}) async {
    return web.window.localStorage.getItem(_scopedKey(key));
  }

  @override
  Future<void> removeItem({required String key}) async {
    web.window.localStorage.removeItem(_scopedKey(key));
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    web.window.localStorage.setItem(_scopedKey(key), value);
  }
}

GotrueAsyncStorage createPkceStorageImpl() {
  return _PkceWebStorage();
}
