import 'package:supabase_flutter/supabase_flutter.dart';

import 'pkce_async_storage_stub.dart'
    if (dart.library.html) 'pkce_async_storage_web.dart';

GotrueAsyncStorage createPkceStorage() {
  return createPkceStorageImpl();
}
