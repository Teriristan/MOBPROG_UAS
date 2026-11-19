import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../feed/feed_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import '../record/record_screen.dart';
import '../stats/stats_screen.dart';

/// Kerangka halaman utama: lima tab dan navigasi di bagian bawah.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Tab baru dibangun saat pertama kali dibuka, supaya pengamat data
  // milik tab lain tidak aktif sebelum dibutuhkan. Setelah dibuka, tab
  // dipertahankan (IndexedStack) sehingga perekaman dan posisi scroll aman.
  final Set<int> _visited = <int>{0};

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavProvider>();
    final uid = context.select<AuthProvider, String?>((a) => a.user?.uid);
    _visited.add(nav.index);

    Widget tab(int index, Widget Function() create) {
      return _visited.contains(index) ? create() : const SizedBox.shrink();
    }

    return PopScope(
      // Tombol kembali di tab lain membawa pengguna ke Beranda dulu.
      canPop: nav.index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) nav.go(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: nav.index,
          children: [
            tab(0, () => const FeedScreen()),
            tab(1, () => const RecordScreen()),
            tab(2, () => const StatsScreen()),
            tab(3, () => const LeaderboardScreen()),
            tab(
              4,
              () => uid == null
                  ? const SizedBox.shrink()
                  : ProfileScreen(
                      key: ValueKey<String>(uid),
                      uid: uid,
                      isTab: true,
                    ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: nav.index,
          onDestinationSelected: nav.go,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              selectedIcon: Icon(Icons.play_circle),
              label: 'Rekam',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Statistik',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events),
              label: 'Peringkat',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
