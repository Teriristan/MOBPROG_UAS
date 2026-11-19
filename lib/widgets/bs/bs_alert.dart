import 'package:flutter/material.dart';

import '../../core/theme/bootstrap_theme.dart';

/// Kotak pesan ala Bootstrap (alert alert-danger, alert-success, dst.).
class BsAlert extends StatelessWidget {
  const BsAlert({
    super.key,
    required this.message,
    this.variant = BsVariant.danger,
    this.icon,
  });

  final String message;
  final BsVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: variant.subtleBg,
        border: Border.all(color: variant.subtleBorder),
        borderRadius: BorderRadius.circular(BsRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: variant.emphasis),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(message, style: TextStyle(color: variant.emphasis)),
          ),
        ],
      ),
    );
  }
}
