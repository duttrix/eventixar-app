import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'duttrix_brand.dart';

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

/// Shared scaffold + drawer for the event workspace (tabs).
/// Logout vive en home: acá solo se vuelve con “Mis eventos”.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    this.subtitle,
    this.header,
    this.navItems,
    required this.body,
    this.onHome,
    this.floatingActionButton,
  });

  /// Section label in the AppBar (e.g. current tab). Kept short on purpose.
  final String title;
  final String? subtitle;

  /// Optional banner under the AppBar (e.g. long event name).
  final Widget? header;

  final List<ShellNavItem>? navItems;
  final Widget body;
  final VoidCallback? onHome;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final items = navItems ?? const <ShellNavItem>[];
    final hasDrawer = items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (onHome != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: onHome,
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Mis eventos'),
              ),
            ),
        ],
      ),
      drawer: hasDrawer
          ? Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    const _DrawerHeader(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          for (final item in items)
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
            )
          : null,
      body: header == null
          ? body
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header!,
                const Divider(height: 1, thickness: 1),
                Expanded(child: body),
              ],
            ),
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
      child: const DuttrixBrandHeader(compact: true),
    );
  }
}
