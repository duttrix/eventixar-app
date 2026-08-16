import 'package:flutter/material.dart';

class BottomSystemInset extends StatelessWidget {
  const BottomSystemInset({super.key, required this.child, this.extra = 0});
  final Widget child;
  final double extra;
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom + extra;
    if (bottom <= 0) return child;
    return Padding(padding: EdgeInsets.only(bottom: bottom), child: child);
  }
}

EdgeInsets listPaddingWithFab(BuildContext context, {double baseBottom = 96}) {
  final inset = MediaQuery.viewPaddingOf(context).bottom;
  return EdgeInsets.fromLTRB(16, 16, 16, baseBottom + inset);
}
