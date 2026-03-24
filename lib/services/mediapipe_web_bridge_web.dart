// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_util' as js_util;

Future<bool> startWebMediaPipe({
  required String mode,
  required String containerId,
}) async {
  final global = js_util.globalThis;
  final bridge = js_util.getProperty<Object?>(global, 'nutriMediaPipe');
  if (bridge == null) {
    throw StateError('nutriMediaPipe JS bridge not loaded');
  }

  Object? lastError;
  for (int attempt = 0; attempt < 14; attempt++) {
    try {
      final result = js_util.callMethod<Object?>(bridge, 'start', <Object?>[mode, containerId]);
      if (result is Future) {
        await result;
      } else if (result != null && js_util.hasProperty(result, 'then')) {
        await js_util.promiseToFuture(result);
      }
      return true;
    } catch (e) {
      lastError = e;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  throw StateError('Unable to start MediaPipe for "$mode" on container "$containerId": $lastError');
}

Future<void> stopWebMediaPipe() async {
  final global = js_util.globalThis;
  final bridge = js_util.getProperty<Object?>(global, 'nutriMediaPipe');
  if (bridge == null) {
    return;
  }
  final result = js_util.callMethod<Object?>(bridge, 'stop', <Object?>[]);
  if (result != null && js_util.hasProperty(result, 'then')) {
    await js_util.promiseToFuture(result);
  }
}

Map<String, dynamic> getWebMediaPipeLatest(String mode) {
  final global = js_util.globalThis;
  final bridge = js_util.getProperty<Object?>(global, 'nutriMediaPipe');
  if (bridge == null) {
    return const <String, dynamic>{};
  }
  final data = js_util.callMethod<Object?>(bridge, 'getLatest', <Object?>[mode]);
  final dartData = js_util.dartify(data);
  if (dartData is Map<String, dynamic>) {
    return dartData;
  }
  if (dartData is Map) {
    return Map<String, dynamic>.from(dartData);
  }
  return const <String, dynamic>{};
}
