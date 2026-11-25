import 'package:flutter/material.dart';

import '../../core/theme/bootstrap_theme.dart';

class BsBadge extends StatelessWidget {
  const BsBadge({
    super.key,
    required this.text,
    this.variant = BsVariant.primary,
    this.pill = false,
  });

  final String text;
  final BsVariant variant;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: variant.color,
        borderRadius: BorderRadius.circular(pill ? 50 : BsRadius.md),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: variant.onColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
