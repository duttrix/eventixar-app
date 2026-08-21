import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/brand_icons.dart';
import '../../shared/widgets/duttrix_brand.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;
  bool _showEmailForm = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(sessionProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        setState(() => _busy = false);
        return;
      }
      if (context.mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo iniciar sesión con Google. Probá de nuevo.';
      });
      debugPrint('Google sign-in error: $e');
    }
  }

  Future<void> _signInWithEmail() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Completá email y contraseña.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(sessionProvider.notifier)
          .signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      if (user == null) {
        setState(() => _busy = false);
        return;
      }
      if (context.mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _emailAuthMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo iniciar sesión. Probá de nuevo.';
      });
      debugPrint('Email sign-in error: $e');
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
                        onPressed: _busy ? null : _signInWithGoogle,
                        icon: _busy && !_showEmailForm
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const GoogleLogo(size: 18),
                        label: Text(
                          _busy && !_showEmailForm
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: const AppleLogo(size: 18),
                        label: const Text('Continuar con Apple (próximamente)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black54,
                          disabledForegroundColor: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _showEmailForm = !_showEmailForm;
                                _error = null;
                              }),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(
                        _showEmailForm
                            ? 'Ocultar email'
                            : 'Entrar con email',
                      ),
                    ),
                    if (_showEmailForm) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _emailController,
                        enabled: !_busy,
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
                        enabled: !_busy,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _signInWithEmail(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          isDense: true,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar'
                                : 'Ocultar',
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
                          onPressed: _busy ? null : _signInWithEmail,
                          child: _busy
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
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.dangerText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
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
