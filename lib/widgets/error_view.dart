import 'package:flutter/material.dart';

import '../core/theme/bootstrap_theme.dart';
import '../services/auth_service.dart';
import 'bs/bs_alert.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BsAlert(
          message: AuthService.messageFor(error),
          variant: BsVariant.danger,
          icon: Icons.error_outline,
        ),
      ),
    );
  }
}
