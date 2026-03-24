import 'package:supabase_flutter/supabase_flutter.dart';

class _PkceMemoryStorage extends GotrueAsyncStorage {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async {
    return _store[key];
  }

  @override
  Future<void> removeItem({required String key}) async {
    _store.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _store[key] = value;
  }
}

GotrueAsyncStorage createPkceStorageImpl() {
  return _PkceMemoryStorage();
}
