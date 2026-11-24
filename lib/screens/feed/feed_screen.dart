import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/activity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/follow_provider.dart';
import '../../services/activity_service.dart';
import '../../widgets/activity_card.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../profile/search_users_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: BsAppBar(
          title: AppConstants.appName,
          actions: [
            IconButton(
              tooltip: 'Cari teman',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SearchUsersScreen(),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Mengikuti'),
            ],
          ),
        ),
        body: const TabBarView(children: [_AllFeed(), _FollowingFeed()]),
      ),
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({required this.snapshot, required this.empty});

  final AsyncSnapshot<List<Activity>> snapshot;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    if (snap.hasError) return ErrorView(error: snap.error!);

    final items = snap.data;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return empty;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) => ActivityCard(activity: items[i]),
    );
  }
}

class _AllFeed extends StatefulWidget {
  const _AllFeed();

  @override
  State<_AllFeed> createState() => _AllFeedState();
}

class _AllFeedState extends State<_AllFeed> with AutomaticKeepAliveClientMixin {
  late final Stream<List<Activity>> _stream = ActivityService().watchFeed();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<Activity>>(
      stream: _stream,
      builder: (context, snap) => _FeedList(
        snapshot: snap,
        empty: const EmptyState(
          icon: Icons.directions_run,
          title: 'Belum ada aktivitas',
          message: 'Jadilah yang pertama! Buka tab Rekam untuk memulai.',
        ),
      ),
    );
  }
}

class _FollowingFeed extends StatefulWidget {
  const _FollowingFeed();

  @override
  State<_FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<_FollowingFeed>
    with AutomaticKeepAliveClientMixin {
  final ActivityService _service = ActivityService();
  Set<String> _ids = <String>{};
  Stream<List<Activity>>? _stream;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final me = context.select<AuthProvider, String?>((a) => a.user?.uid);
    final following = context.watch<FollowProvider>().followingIds;
    if (me == null) return const SizedBox.shrink();

    // Stream dibuat ulang hanya bila daftar yang diikuti berubah.
    final ids = <String>{me, ...following};
    if (_stream == null || !setEquals(ids, _ids)) {
      _ids = ids;
      _stream = _service.watchFeedOf(ids);
    }

    final noFollowing = following.isEmpty;

    return StreamBuilder<List<Activity>>(
      stream: _stream,
      builder: (context, snap) => _FeedList(
        snapshot: snap,
        empty: EmptyState(
          icon: Icons.group_outlined,
          title: noFollowing
              ? 'Belum mengikuti siapa pun'
              : 'Belum ada aktivitas',
          message: noFollowing
              ? 'Ikuti teman untuk melihat aktivitas mereka di sini.'
              : 'Aktivitas Anda dan teman yang Anda ikuti akan tampil di sini.',
          action: noFollowing
              ? BsButton(
                  label: 'Cari teman',
                  icon: Icons.person_search,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SearchUsersScreen(),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
