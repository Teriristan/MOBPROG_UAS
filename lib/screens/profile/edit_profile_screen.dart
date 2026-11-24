import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/bs/bs_alert.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _bioC;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.user.displayName);
    _bioC = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _bioC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final name = _nameC.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await UserService().updateProfile(
        uid: widget.user.uid,
        displayName: name,
        bio: _bioC.text,
      );
      await auth.updateDisplayName(name);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AuthService.messageFor(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BsAppBar(title: 'Ubah Profil'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(
                width: double.infinity,
                child: BsCard(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                          prefixIcon: Icons.person_outline,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          maxLength: 40,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Nama wajib diisi';
                            if (value.length < 3) {
                              return 'Nama minimal 3 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        BsTextField(
                          controller: _bioC,
                          label: 'Bio (opsional)',
                          hint: 'Ceritakan sedikit tentang Anda',
                          prefixIcon: Icons.notes,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 3,
                          maxLength: 120,
                        ),
                        const SizedBox(height: 16),
                        BsButton(
                          label: 'Simpan perubahan',
                          icon: Icons.check,
                          block: true,
                          loading: _saving,
                          onPressed: _save,
                        ),
                        const SizedBox(height: 8),
                        BsButton(
                          label: 'Batal',
                          variant: BsVariant.secondary,
                          outline: true,
                          block: true,
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
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
    );
  }
}
