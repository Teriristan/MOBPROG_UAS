import 'package:flutter/material.dart';

import '../../core/theme/bootstrap_theme.dart';

class BsButton extends StatelessWidget {
  const BsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BsVariant.primary,
    this.outline = false,
    this.loading = false,
    this.block = false,
    this.small = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final BsVariant variant;

  /// true → tombol outline (btn-outline-*)
  final bool outline;

  /// true → tampil spinner dan tombol tidak bisa ditekan
  final bool loading;

  /// true → lebar penuh (w-100)
  final bool block;

  /// true → tombol kecil (btn-sm)
  final bool small;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = variant.color;
    final enabled = onPressed != null && !loading;
    final spinnerColor = outline ? color : variant.onColor;
    final iconSize = small ? 16.0 : 18.0;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: small ? 13.0 : 14.0,
            ),
          ),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BsRadius.md),
    );
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final minimumSize = small ? const Size(0, 32) : const Size(64, 40);

    final Widget button = outline
        ? OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              disabledForegroundColor: color.withValues(alpha: 0.65),
              side: BorderSide(
                color: enabled ? color : color.withValues(alpha: 0.65),
              ),
              shape: shape,
              padding: padding,
              minimumSize: minimumSize,
            ),
            child: content,
          )
        : FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: variant.onColor,
              disabledBackgroundColor: color.withValues(alpha: 0.65),
              disabledForegroundColor: variant.onColor,
              shape: shape,
              padding: padding,
              minimumSize: minimumSize,
            ),
            child: content,
          );

    return block ? SizedBox(width: double.infinity, child: button) : button;
  }
}
