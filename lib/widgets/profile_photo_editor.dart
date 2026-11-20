import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/bootstrap_theme.dart';
import '../data/local_db.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'user_avatar.dart';

/// Avatar milik sendiri yang bisa diketuk untuk mengganti foto profil
/// (kamera, galeri, atau hapus foto).
class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor({
    super.key,
    required this.uid,
    required this.name,
    this.radius = 40,
  });

  final String uid;
  final String name;
  final double radius;

  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  final ImagePicker _picker = ImagePicker();
  final UserService _users = UserService();
  bool _busy = false;

  // Kamera hanya tersedia di web dan HP.
  bool get _canUseCamera =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _pick(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (picked == null) return; // dibatalkan
      final bytes = await picked.readAsBytes();
      await _users.updatePhoto(widget.uid, bytes);
      messenger.showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diganti.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.messageFor(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _users.removePhoto(widget.uid);
      messenger.showSnackBar(
        const SnackBar(content: Text('Foto profil dihapus.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.messageFor(e))),
      );
    }
  }

  void _showMenu() {
    final hasPhoto = LocalDb.instance.userById(widget.uid)?.photo != null;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canUseCamera)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pick(ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: BsColors.danger,
                ),
                title: const Text(
                  'Hapus foto',
                  style: TextStyle(color: BsColors.danger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _remove();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius;
    return Semantics(
      button: true,
      label: 'Ganti foto profil',
      child: GestureDetector(
        onTap: _busy ? null : _showMenu,
        child: Stack(
          alignment: Alignment.center,
          children: [
            UserAvatar(name: widget.name, radius: r, uid: widget.uid),
            if (_busy)
              const CircularProgressIndicator()
            else
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: r * 0.28,
                  backgroundColor: BsColors.primary,
                  child: Icon(
                    Icons.camera_alt,
                    size: r * 0.3,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}