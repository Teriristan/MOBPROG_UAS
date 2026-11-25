import 'package:flutter/material.dart';

import '../../core/theme/bootstrap_theme.dart';

class BsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BsAppBar({super.key, required this.title, this.actions, this.bottom});

  final String title;
  final List<Widget>? actions;

  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: BsColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: actions,
      bottom: bottom,
    );
  }
}
