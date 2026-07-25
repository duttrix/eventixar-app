import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/brand_icons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;

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
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo iniciar sesión con Google. Probá de nuevo.';
      });
      debugPrint('Google sign-in error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Logo(),
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
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const GoogleLogo(size: 18),
                      label: Text(
                        _busy ? 'Conectando…' : 'Continuar con Google',
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
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.confirmation_number_outlined,
            color: AppColors.accent,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Eventixar',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tickets para tu evento',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
