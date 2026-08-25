import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/monitoring/crash_reporting.dart';
import '../../core/theme/app_colors.dart';

/// Visual tone for [AppSnackBar]. Customize colors here in one place.
enum AppSnackTone { info, success, warning, error }

/// Central entry point for user-facing transient messages (SnackBars).
///
/// Prefer this over raw `ScaffoldMessenger.showSnackBar` so visuals and
/// Crashlytics reporting stay consistent.
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    AppSnackTone tone = AppSnackTone.info,
    Duration? duration,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      buildSnackBar(
        message,
        tone: tone,
        duration: duration ?? _defaultDuration(tone),
      ),
    );
  }

  static void info(BuildContext context, String message) =>
      show(context, message, tone: AppSnackTone.info);

  static void success(BuildContext context, String message) =>
      show(context, message, tone: AppSnackTone.success);

  static void warning(BuildContext context, String message) =>
      show(context, message, tone: AppSnackTone.warning);

  /// Shows an error SnackBar. When [cause] is set, also records a non-fatal
  /// Crashlytics event (unless [reportToCrashlytics] is false).
  static void error(
    BuildContext context,
    String message, {
    Object? cause,
    StackTrace? stackTrace,
    String? crashReason,
    bool reportToCrashlytics = true,
  }) {
    show(
      context,
      message,
      tone: AppSnackTone.error,
      duration: const Duration(seconds: 4),
    );

    if (!reportToCrashlytics || cause == null) return;
    unawaited(
      CrashReporting.recordNonFatal(
        cause,
        stackTrace ?? StackTrace.current,
        reason: crashReason ?? 'user_visible_error',
        information: {'user_message': message},
      ),
    );
  }

  /// Builds the SnackBar widget — useful for tests or rare custom hosts.
  static SnackBar buildSnackBar(
    String message, {
    AppSnackTone tone = AppSnackTone.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = _colorsFor(tone);
    return SnackBar(
      content: Text(
        message,
        style: TextStyle(color: colors.foreground, fontSize: 14, height: 1.35),
      ),
      backgroundColor: colors.background,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: duration,
    );
  }

  static Duration _defaultDuration(AppSnackTone tone) {
    return switch (tone) {
      AppSnackTone.error || AppSnackTone.warning => const Duration(seconds: 4),
      _ => const Duration(seconds: 3),
    };
  }

  static ({Color background, Color foreground}) _colorsFor(AppSnackTone tone) {
    return switch (tone) {
      AppSnackTone.success => (
        background: AppColors.successBg,
        foreground: AppColors.successText,
      ),
      AppSnackTone.warning => (
        background: AppColors.warnBg,
        foreground: AppColors.warnText,
      ),
      AppSnackTone.error => (
        background: AppColors.dangerBg,
        foreground: AppColors.dangerText,
      ),
      AppSnackTone.info => (
        background: AppColors.night,
        foreground: Colors.white,
      ),
    };
  }
}
