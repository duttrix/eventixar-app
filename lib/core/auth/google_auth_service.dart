import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../monitoring/crash_reporting.dart';

/// User-facing auth failure. Technical detail goes to Crashlytics only.
class AuthFailure implements Exception {
  AuthFailure(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => userMessage;
}

/// Google Sign-In → Firebase Auth for organizers.
class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _authOverride = auth,
        _googleSignInOverride = googleSignIn;

  final FirebaseAuth? _authOverride;
  final GoogleSignIn? _googleSignInOverride;
  bool _initialized = false;

  // Resolved lazily so that constructing the service never requires Firebase
  // to be initialized (tests subclass this and override the members they use).
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn =>
      _googleSignInOverride ?? GoogleSignIn.instance;

  /// Web client ID from Firebase (needed on Android to obtain an ID token).
  static const String webClientId =
      '165106453677-1pv115libl5nvjtkdjkpa4lermbn7gko.apps.googleusercontent.com';

  static const _userGoogleFailure =
      'No se pudo iniciar sesión con Google. Probá de nuevo.';

  void _debug(String message, {Object? error}) {
    if (!kDebugMode) return;
    debugPrint('[DuttrixAuth] $message');
    if (error != null) debugPrint('[DuttrixAuth] error=$error');
  }

  Future<void> _breadcrumb(String message) {
    _debug(message);
    return CrashReporting.log(message);
  }

  Future<Never> _failGoogle(
    Object error,
    StackTrace stack, {
    required String reason,
    Map<String, Object?>? information,
  }) async {
    await CrashReporting.recordNonFatal(
      error,
      stack,
      reason: reason,
      information: information,
    );
    throw AuthFailure(_userGoogleFailure, cause: error);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _breadcrumb('google_sign_in.initialize');
    await _googleSignIn.initialize(serverClientId: webClientId);
    _initialized = true;
  }

  /// Email / password sign-in (demo / Play review accounts).
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e, st) {
      await CrashReporting.recordNonFatal(
        e,
        st,
        reason: 'email_password_sign_in_unexpected',
      );
      rethrow;
    }
  }

  /// Interactive Google sign-in. Returns the Firebase [User] or null if cancelled.
  Future<User?> signInWithGoogle() async {
    await _ensureInitialized();
    await _breadcrumb('google_sign_in.authenticate.start');

    try {
      final account = await _googleSignIn.authenticate();
      await _breadcrumb('google_sign_in.authenticate.ok');

      final idToken = account.authentication.idToken;
      if (idToken == null) {
        await _failGoogle(
          StateError('Google Sign-In returned null idToken'),
          StackTrace.current,
          reason: 'google_sign_in_missing_id_token',
        );
      }

      await _breadcrumb('firebase_auth.sign_in_with_credential.start');
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      await _breadcrumb('firebase_auth.sign_in_with_credential.ok');
      return result.user;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e, st) {
      _debug('FirebaseAuthException ${e.code}', error: e);
      await _failGoogle(
        e,
        st,
        reason: 'firebase_auth_google_credential',
        information: {
          'auth_code': e.code,
          'auth_message': e.message,
        },
      );
    } on GoogleSignInException catch (e, st) {
      // Credential Manager often reports config errors (missing SHA-1, wrong
      // package) as "canceled" with a description like "[16] Account reauth
      // failed". A real back-button cancel usually has an empty description.
      final detail = e.description?.trim();
      _debug(
        'GoogleSignInException ${e.code.name} description=$detail',
        error: e,
      );

      if (e.code == GoogleSignInExceptionCode.canceled &&
          (detail == null || detail.isEmpty)) {
        await _breadcrumb('google_sign_in.user_canceled');
        return null;
      }

      await _failGoogle(
        e,
        st,
        reason: e.code == GoogleSignInExceptionCode.canceled
            ? 'google_sign_in_canceled_with_detail'
            : 'google_sign_in_${e.code.name}',
        information: {
          'gsi_code': e.code.name,
          'gsi_description': detail,
          'gsi_details': e.details,
        },
      );
    } catch (e, st) {
      _debug('unexpected Google sign-in error', error: e);
      await _failGoogle(
        e,
        st,
        reason: 'google_sign_in_unexpected',
      );
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
