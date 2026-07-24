import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock/providers.dart';

class ShellNavItem {
  const ShellNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// Shared scaffold + drawer for organizer home and event workspace.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.navItems,
    required this.body,
    this.onHome,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final List<ShellNavItem> navItems;
  final Widget body;
  final VoidCallback? onHome;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            Text(title),
          ],
        ),
        actions: [
          if (onHome != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: onHome,
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Mis eventos'),
              ),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () {
              ref.read(sessionProvider.notifier).logout();
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const _DrawerHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final item in navItems)
                      ListTile(
                        leading: Icon(
                          item.icon,
                          color: item.selected ? AppColors.accent : AppColors.textSecondary,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: item.selected ? AppColors.accent : AppColors.text,
                            fontWeight: item.selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        selected: item.selected,
                        selectedTileColor: AppColors.accentBg,
                        onTap: () {
                          Navigator.pop(context);
                          item.onTap();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Eventixar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text),
          ),
          SizedBox(height: 2),
          Text(
            'Tickets para tu evento',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
