import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/google_auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/brand_icons.dart';
import '../../shared/widgets/duttrix_brand.dart';
import '../../shared/widgets/help_whatsapp.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginBusy { idle, google, apple, email }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _LoginBusy _busy = _LoginBusy.idle;
  bool _appleInFlight = false;
  bool _showEmailForm = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool get _isBusy => _busy != _LoginBusy.idle;

  bool _showAppleSignIn(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_isBusy) return;
    setState(() => _busy = _LoginBusy.google);
    try {
      final user = await ref.read(sessionProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        // User dismissed the account picker — no toast.
        setState(() => _busy = _LoginBusy.idle);
        return;
      }
      if (context.mounted) context.go('/home');
    } on SellerLoginBlocked catch (e) {
      if (!mounted) return;
      setState(() => _busy = _LoginBusy.idle);
      AppSnackBar.warning(context, e.userMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = _LoginBusy.idle);
      final message = e is AuthFailure
          ? e.userMessage
          : 'No se pudo iniciar sesión con Google. Probá de nuevo.';
      // AuthFailure already reported to Crashlytics in GoogleAuthService.
      AppSnackBar.error(
        context,
        message,
        cause: e is AuthFailure ? null : e,
        reportToCrashlytics: e is! AuthFailure,
        crashReason: 'login_google_failed',
      );
    }
  }

  Future<void> _signInWithApple() async {
    if (_isBusy || _appleInFlight) return;
    _appleInFlight = true;
    try {
      final user = await ref.read(sessionProvider.notifier).signInWithApple();
      if (!mounted) return;
      if (user == null) {
        AppSnackBar.info(
          context,
          'Inicio con Apple cancelado. En el simulador, iniciá sesión con un '
          'Apple ID en Ajustes.',
        );
        return;
      }
      if (context.mounted) context.go('/home');
    } on SellerLoginBlocked catch (e) {
      if (!mounted) return;
      AppSnackBar.warning(context, e.userMessage);
    } catch (e) {
      if (!mounted) return;
      final message = e is AuthFailure
          ? e.userMessage
          : 'No se pudo iniciar sesión con Apple. Probá de nuevo.';
      AppSnackBar.error(
        context,
        message,
        cause: e is AuthFailure ? null : e,
        reportToCrashlytics: e is! AuthFailure,
        crashReason: 'login_apple_failed',
      );
    } finally {
      _appleInFlight = false;
    }
  }

  Future<void> _signInWithEmail() async {
    if (_isBusy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      AppSnackBar.warning(context, 'Completá email y contraseña.');
      return;
    }

    setState(() => _busy = _LoginBusy.email);
    try {
      final user = await ref
          .read(sessionProvider.notifier)
          .signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      if (user == null) {
        setState(() => _busy = _LoginBusy.idle);
        return;
      }
      if (context.mounted) context.go('/home');
    } on SellerLoginBlocked catch (e) {
      if (!mounted) return;
      setState(() => _busy = _LoginBusy.idle);
      AppSnackBar.warning(context, e.userMessage);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = _LoginBusy.idle);
      AppSnackBar.error(
        context,
        _emailAuthMessage(e),
        reportToCrashlytics: false,
      );
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _busy = _LoginBusy.idle);
      AppSnackBar.error(
        context,
        'No se pudo iniciar sesión. Probá de nuevo.',
        cause: e,
        stackTrace: st,
        crashReason: 'login_email_unexpected',
      );
    }
  }

  String _emailAuthMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Email o contraseña incorrectos.',
      'invalid-email' => 'El email no es válido.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      'too-many-requests' => 'Demasiados intentos. Probá más tarde.',
      _ => 'No se pudo iniciar sesión. Probá de nuevo.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE6F7F2),
              AppColors.background,
              AppColors.background,
            ],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DuttrixBrandHeader(),
                    const SizedBox(height: 28),
                    const Text(
                      'Iniciá sesión para crear tu evento y gestionar tickets.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _signInWithGoogle,
                        icon: _busy == _LoginBusy.google
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const GoogleLogo(size: 18),
                        label: Text(
                          _busy == _LoginBusy.google
                              ? 'Conectando…'
                              : 'Continuar con Google',
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: AppColors.borderStrong),
                        ),
                      ),
                    ),
                    if (_showAppleSignIn(context)) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isBusy ? null : _signInWithApple,
                          icon: _busy == _LoginBusy.apple
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const AppleLogo(size: 18),
                          label: Text(
                            _busy == _LoginBusy.apple
                                ? 'Conectando…'
                                : 'Continuar con Apple',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.black54,
                            disabledForegroundColor: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () => setState(() => _showEmailForm = !_showEmailForm),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(
                        _showEmailForm ? 'Ocultar email' : 'Entrar con email',
                      ),
                    ),
                    if (_showEmailForm) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _emailController,
                        enabled: !_isBusy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        enabled: !_isBusy,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _signInWithEmail(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          isDense: true,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Mostrar' : 'Ocultar',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isBusy ? null : _signInWithEmail,
                          child: _busy == _LoginBusy.email
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    const HelpWhatsAppTextButton(),
                    const SizedBox(height: 16),
                    const Text(
                      'Si te invitaron como vendedor, validador o recaudador, '
                      'abrí el link que te compartieron: no necesitás cuenta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
