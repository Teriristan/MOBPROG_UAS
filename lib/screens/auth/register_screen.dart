import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/bs/bs_alert.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().register(
        _nameC.text,
        _emailC.text,
        _passC.text,
      );

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: const BsAppBar(title: 'Daftar Akun'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -85,
            right: -70,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -105,
            left: -75,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: BsCard(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Buat akun baru',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_error != null) ...[
                                BsAlert(
                                  message: _error!,
                                  variant: BsVariant.danger,
                                  icon: Icons.error_outline,
                                ),
                                const SizedBox(height: 16),
                              ],
                              BsTextField(
                                controller: _nameC,
                                label: 'Nama lengkap',
                                hint: 'Nama yang tampil di aplikasi',
                                prefixIcon: Icons.person_outline,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (value.isEmpty) return 'Nama wajib diisi';
                                  if (value.length < 3) {
                                    return 'Nama minimal 3 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              BsTextField(
                                controller: _emailC,
                                label: 'Email',
                                hint: 'nama@email.com',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (value.isEmpty) return 'Email wajib diisi';
                                  if (!AuthService.isValidEmail(value)) {
                                    return 'Format email tidak valid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              BsTextField(
                                controller: _passC,
                                label: 'Kata sandi',
                                hint: 'Minimal 6 karakter',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _hidePassword,
                                textInputAction: TextInputAction.next,
                                suffix: IconButton(
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Kata sandi wajib diisi';
                                  }
                                  if (v.length < 6) {
                                    return 'Minimal 6 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              BsTextField(
                                controller: _confirmC,
                                label: 'Ulangi kata sandi',
                                hint: 'Ketik ulang kata sandi',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _hidePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (v) => v != _passC.text
                                    ? 'Konfirmasi kata sandi tidak sama'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              BsButton(
                                label: 'Daftar',
                                block: true,
                                loading: _loading,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Sudah punya akun? Masuk'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}