import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Crashlytics so call sites stay simple and testable.
class CrashReporting {
  CrashReporting._();

  static FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  /// Breadcrumb for the Crashlytics session log (not a separate issue).
  static Future<void> log(String message) async {
    try {
      await _crashlytics.log(message);
    } catch (_) {}
  }

  /// Associates subsequent reports with this Firebase Auth user.
  static Future<void> setUserId(String? uid) async {
    try {
      await _crashlytics.setUserIdentifier(uid ?? '');
    } catch (e, st) {
      debugPrint('[CrashReporting] setUserId failed: $e\n$st');
    }
  }

  /// Event context for filtering Crashlytics issues and looking up Firestore.
  static Future<void> setEventId(String? eventId) async {
    try {
      await _crashlytics.setCustomKey('event_id', eventId ?? '');
      if (eventId != null && eventId.isNotEmpty) {
        await _crashlytics.log('event_id=$eventId');
      }
    } catch (e, st) {
      debugPrint('[CrashReporting] setEventId failed: $e\n$st');
    }
  }

  /// Records a non-fatal issue (auth failures, recoverable errors, etc.).
  static Future<void> recordNonFatal(
    Object error,
    StackTrace stack, {
    String? reason,
    Map<String, Object?>? information,
  }) async {
    try {
      if (reason != null) {
        await _crashlytics.setCustomKey('failure_reason', reason);
      }
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
}
