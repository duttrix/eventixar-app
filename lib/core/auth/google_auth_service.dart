import 'package:firebase_auth/firebase_auth.dart';
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

  /// Interactive Google sign-in. Returns the Firebase [User] or null if cancelled.
  Future<User?> signInWithGoogle() async {
    await _ensureInitialized();

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError(
          'Google no devolvió idToken. Revisá el SHA-1 de debug en Firebase '
          'y que el proveedor Google esté habilitado.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
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
