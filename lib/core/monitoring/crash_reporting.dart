import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Crashlytics so call sites stay simple and testable.
class CrashReporting {
  CrashReporting._();

  static FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  /// Records a non-fatal issue (auth failures, recoverable errors, etc.).
  static Future<void> recordNonFatal(
    Object error,
    StackTrace stack, {
    String? reason,
    Map<String, Object?>? information,
  }) async {
    try {
      if (information != null) {
        for (final entry in information.entries) {
          await _crashlytics.setCustomKey(
            entry.key,
            entry.value?.toString() ?? 'null',
          );
        }
      }
      await _crashlytics.recordError(
        error,
        stack,
        reason: reason,
        fatal: false,
      );
    } catch (e, st) {
      debugPrint('[CrashReporting] recordNonFatal failed: $e\n$st');
    }
  }

  static Future<void> log(String message) async {
    try {
      await _crashlytics.log(message);
    } catch (_) {}
  }
}
