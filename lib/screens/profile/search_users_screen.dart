import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/follow_provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_badge.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/user_avatar.dart';
import 'profile_screen.dart';

/// Mencari pengguna lain berdasarkan awalan nama, lalu mengikutinya.
class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final UserService _service = UserService();
  final TextEditingController _queryC = TextEditingController();

  Timer? _debounce;
  int _requestId = 0;
  bool _loading = true;
  Object? _error;
  List<AppUser> _results = const <AppUser>[];

  @override
  void initState() {
    super.initState();
    _load(''); // tampilkan pengguna terbaru dulu
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryC.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });
      _load(value);
    });
  }

  Future<void> _load(String keyword) async {
    final id = ++_requestId;
    try {
      final list = await _service.search(keyword);
      // Abaikan hasil lama bila pengguna sudah mengetik kata lain.
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.select<AuthProvider, String?>((a) => a.user?.uid);

    return Scaffold(
      appBar: const BsAppBar(title: 'Cari Teman'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: BsTextField(
              controller: _queryC,
              label: 'Cari berdasarkan nama',
              hint: 'Ketik awal nama...',
              prefixIcon: Icons.search,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
            ),
          ),
          Expanded(child: _buildResults(me)),
        ],
      ),
    );
  }

  Widget _buildResults(String? me) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final error = _error;
    if (error != null) return ErrorView(error: error);

    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search,
        title: 'Pengguna tidak ditemukan',
        message: 'Coba ketik awal nama dengan ejaan lain.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final user = _results[i];
        return _UserTile(user: user, isMe: user.uid == me);
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.isMe});

  final AppUser user;
  final bool isMe;

  Future<void> _toggle(BuildContext context) async {
    final follow = context.read<FollowProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await follow.toggle(user.uid);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.messageFor(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = context.select<FollowProvider, bool>(
      (f) => f.isFollowing(user.uid),
    );

    return BsCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProfileScreen(uid: user.uid)),
      ),
      child: Row(
        children: [
          UserAvatar(name: user.displayName, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (user.bio.isNotEmpty)
                  Text(
                    user.bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: BsColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMe)
            const BsBadge(
              text: 'Anda',
              variant: BsVariant.secondary,
              pill: true,
            )
          else
            BsButton(
              label: following ? 'Mengikuti' : 'Ikuti',
              small: true,
              outline: following,
              onPressed: () => _toggle(context),
            ),
        ],
      ),
    );
  }
}
