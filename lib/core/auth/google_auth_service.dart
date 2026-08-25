import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../monitoring/crash_reporting.dart';

/// Google Sign-In → Firebase Auth for organizers.
class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _authOverride = auth,
        _googleSignInOverride = googleSignIn;

  final FirebaseAuth? _authOverride;
  final GoogleSignIn? _googleSignInOverride;
  bool _initialized = false;

  static const _logName = 'DuttrixAuth';

  // Resolved lazily so that constructing the service never requires Firebase
  // to be initialized (tests subclass this and override the members they use).
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn =>
      _googleSignInOverride ?? GoogleSignIn.instance;

  /// Web client ID from Firebase (needed on Android to obtain an ID token).
  static const String webClientId =
      '165106453677-1pv115libl5nvjtkdjkpa4lermbn7gko.apps.googleusercontent.com';

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: _logName,
      error: error,
      stackTrace: stackTrace,
    );
    // Also mirror to debugPrint so `adb logcat` / Flutter consoles catch it.
    debugPrint('[$_logName] $message');
    if (error != null) debugPrint('[$_logName] error=$error');
    unawaited(CrashReporting.log('[$_logName] $message'));
  }

  Future<void> _reportAuthFailure(
    Object error,
    StackTrace stack, {
    required String reason,
    Map<String, Object?>? information,
  }) {
    return CrashReporting.recordNonFatal(
      error,
      stack,
      reason: reason,
      information: information,
    );
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _log('initialize GoogleSignIn serverClientId=$webClientId');
    await _googleSignIn.initialize(serverClientId: webClientId);
    _initialized = true;
    _log('GoogleSignIn initialized');
  }

  /// Email / password sign-in (demo / Play review accounts).
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result.user;
  }

  /// Interactive Google sign-in. Returns the Firebase [User] or null if cancelled.
  Future<User?> signInWithGoogle() async {
    await _ensureInitialized();
    _log('authenticate() starting');

    try {
      final account = await _googleSignIn.authenticate();
      _log(
        'authenticate() ok email=${account.email} id=${account.id} '
        'displayName=${account.displayName}',
      );

      final idToken = account.authentication.idToken;
      _log(
        'idToken present=${idToken != null} '
        'length=${idToken?.length ?? 0}',
      );
      if (idToken == null) {
        final error = StateError(
          'Google no devolvió idToken. Revisá que el SHA-1 de la firma '
          '(debug y release) esté cargado en Firebase Console → Project '
          'settings → Your apps → Android, y que el proveedor Google esté '
          'habilitado.',
        );
        await _reportAuthFailure(
          error,
          StackTrace.current,
          reason: 'google_sign_in_missing_id_token',
        );
        throw error;
      }

      _log('signInWithCredential(Firebase) starting');
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      _log(
        'Firebase Auth ok uid=${result.user?.uid} '
        'email=${result.user?.email}',
      );
      return result.user;
    } on FirebaseAuthException catch (e, st) {
      _log(
        'FirebaseAuthException code=${e.code} message=${e.message}',
        error: e,
        stackTrace: st,
      );
      await _reportAuthFailure(
        e,
        st,
        reason: 'firebase_auth_google_credential',
        information: {'auth_code': e.code, 'auth_message': e.message},
      );
      throw StateError('Firebase Auth: ${e.code} — ${e.message ?? e}');
    } on GoogleSignInException catch (e, st) {
      // Credential Manager often reports config errors (missing SHA-1, wrong
      // package) as "canceled" with a description like "[16] Account reauth
      // failed". A real back-button cancel usually has an empty description.
      _log(
        'GoogleSignInException code=${e.code.name} '
        'description=${e.description} details=${e.details}',
        error: e,
        stackTrace: st,
      );
      final detail = e.description?.trim();
      if (e.code == GoogleSignInExceptionCode.canceled) {
        if (detail == null || detail.isEmpty) {
          _log('treated as user cancel (empty description)');
          return null;
        }
        await _reportAuthFailure(
          e,
          st,
          reason: 'google_sign_in_canceled_with_detail',
          information: {
            'gsi_code': e.code.name,
            'gsi_description': detail,
            'gsi_details': e.details,
          },
        );
        throw StateError('Google: $detail (${e.code.name})');
      }
      await _reportAuthFailure(
        e,
        st,
        reason: 'google_sign_in_${e.code.name}',
        information: {
          'gsi_code': e.code.name,
          'gsi_description': detail,
          'gsi_details': e.details,
        },
      );
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw StateError(
          'Google config (${e.code.name}): ${detail ?? e}. '
          'Revisá SHA-1 / OAuth client de Android en Firebase.',
        );
      }
      throw StateError('Google: ${detail ?? e} (${e.code.name})');
    } on StateError {
      // Already reported (e.g. missing idToken).
      rethrow;
    } catch (e, st) {
      _log('signInWithGoogle unexpected error', error: e, stackTrace: st);
      await _reportAuthFailure(
        e,
        st,
        reason: 'google_sign_in_unexpected',
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
}
