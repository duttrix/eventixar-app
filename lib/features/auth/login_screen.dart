import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock/providers.dart';
import '../../shared/widgets/brand_icons.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  void _login(WidgetRef ref, BuildContext context, String email) {
    ref.read(repositoryProvider).ensureUser(email);
    ref.read(sessionProvider.notifier).login(email);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _login(ref, context, 'organizador@demo.com'),
                      icon: const GoogleLogo(size: 18),
                      label: const Text('Continuar con Google'),
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
                      onPressed: () => _login(ref, context, 'organizador@demo.com'),
                      icon: const AppleLogo(size: 18),
                      label: const Text('Continuar con Apple'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Modo demo · accesos rápidos',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _login(ref, context, 'organizador@demo.com'),
                            child: const Text('Entrar como organizador'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => context.go('/join/seller-ana-demo'),
                            child: const Text('Simular deeplink vendedor'),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => context.go('/join/validator-carlos-demo'),
                            child: const Text('Simular deeplink validador'),
                          ),
                        ),
                      ],
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
          child: const Icon(Icons.confirmation_number_outlined, color: AppColors.accent, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Eventixar',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text),
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
