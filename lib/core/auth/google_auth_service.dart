import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  GoogleSignIn get _googleSignIn => _googleSignInOverride ?? GoogleSignIn.instance;

  /// Web client ID from Firebase (needed on Android to obtain an ID token).
  static const String webClientId =
      '165106453677-1pv115libl5nvjtkdjkpa4lermbn7gko.apps.googleusercontent.com';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize(serverClientId: webClientId);
    _initialized = true;
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

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError(
          'Google no devolvió idToken. Revisá que el SHA-1 de la firma '
          '(debug y release) esté cargado en Firebase Console → Project '
          'settings → Your apps → Android, y que el proveedor Google esté '
          'habilitado.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } on GoogleSignInException catch (e) {
      // Credential Manager often reports config errors (missing SHA-1, wrong
      // package) as "canceled" — indistinguishable from a real user cancel.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('GoogleSignIn canceled (may be config): $e');
        return null;
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw StateError(
          'Configuración de Google Sign-In incompleta. Falta el SHA-1 del '
          'keystore en Firebase o el OAuth client de Android.',
        );
      }
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
