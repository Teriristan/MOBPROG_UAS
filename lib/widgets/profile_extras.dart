import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/bootstrap_theme.dart';
import '../core/utils/dates.dart';
import '../core/utils/formatters.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import 'activity_card.dart';
import 'bs/bs_button.dart';
import 'bs/bs_card.dart';
import 'profile_highlights.dart';

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 8),
  child: Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  ),
);

class ProfileExtras extends StatelessWidget {
  const ProfileExtras({
    super.key,
    required this.uid,
    required this.name,
    required this.items,
    required this.isMe,
  });

  final String uid;
  final String name;
  final List<Activity> items;
  final bool isMe;

  Future<void> _copySummary(
    BuildContext context, {
    required double totalM,
    required int totalS,
    required double weekM,
    required int streak,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = StringBuffer()
      ..writeln('$name di Lariku')
      ..writeln(
        '${items.length} aktivitas | ${Fmt.distance(totalM)} | '
        '${Fmt.duration(totalS)}',
      )
      ..writeln('Pace rata-rata ${Fmt.pace(totalM, totalS)} /km')
      ..writeln('Minggu ini: ${Fmt.distance(weekM)}')
      ..write('Streak: $streak hari');
    await Clipboard.setData(ClipboardData(text: text.toString()));
    messenger.showSnackBar(
      const SnackBar(content: Text('Ringkasan profil disalin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && !isMe) return const SizedBox.shrink();

    final now = DateTime.now();
    final weekStart = Dates.startOfWeek(now);
    final lastWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day - 7,
    );

    var totalM = 0.0;
    var totalS = 0;
    var weekM = 0.0;
    var lastM = 0.0;
    final days = <DateTime>{};
    for (final a in items) {
      totalM += a.distanceM;
      totalS += a.durationS;
      days.add(Dates.startOfDay(a.startTime));
      if (!a.startTime.isBefore(weekStart)) {
        weekM += a.distanceM;
      } else if (!a.startTime.isBefore(lastWeekStart)) {
        lastM += a.distanceM;
      }
    }

    final streak = ProfileHighlights.currentStreak(days, now);
    final longest = ProfileHighlights.longestStreak(days);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMe) ...[
          _sectionTitle('Target Mingguan'),
          _WeeklyGoalCard(uid: uid, weekM: weekM),
        ],
        if (items.isNotEmpty) ...[
          _sectionTitle('Minggu Ini'),
          _WeekCard(
            weekStart: weekStart,
            today: Dates.startOfDay(now),
            days: days,
            weekM: weekM,
            lastM: lastM,
            streak: streak,
            longest: longest,
          ),
          _sectionTitle('Rincian per Jenis'),
          _TypeBreakdown(items: items),
          _sectionTitle('Insight Kebiasaan'),
          _InsightsCard(items: items, activeDays: days.length),
          const SizedBox(height: 12),
          BsButton(
            label: 'Salin ringkasan profil',
            icon: Icons.copy,
            outline: true,
            onPressed: () => _copySummary(
              context,
              totalM: totalM,
              totalS: totalS,
              weekM: weekM,
              streak: streak,
            ),
          ),
        ],
      ],
    );
  }
}

class _WeeklyGoalCard extends StatefulWidget {
  const _WeeklyGoalCard({required this.uid, required this.weekM});

  final String uid;
  final double weekM;

  @override
  State<_WeeklyGoalCard> createState() => _WeeklyGoalCardState();
}

class _WeeklyGoalCardState extends State<_WeeklyGoalCard> {
  double? _goalKm;

  String get _key => 'lariku_goal_${widget.uid}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getDouble(_key);
      if (!mounted) return;
      setState(() => _goalKm = value);
    } catch (_) {
      // Tanpa target kalau penyimpanan tidak bisa dibaca.
    }
  }

  Future<void> _edit() async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _GoalDialog(current: _goalKm),
    );
    if (result == null) return; // dibatalkan
    try {
      final prefs = await SharedPreferences.getInstance();
      if (result <= 0) {
        await prefs.remove(_key);
      } else {
        await prefs.setDouble(_key, result);
      }
    } catch (_) {
      // Abaikan; target tetap tampil selama halaman terbuka.
    }
    if (!mounted) return;
    setState(() => _goalKm = result <= 0 ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goalKm;
    final goalM = (goal ?? 0) * 1000;
    final progress = goalM > 0 ? (widget.weekM / goalM).clamp(0.0, 1.0) : 0.0;
    final reached = goal != null && widget.weekM >= goalM;

    return BsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: BsColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  goal == null
                      ? 'Belum ada target'
                      : '${Fmt.km(widget.weekM)} / ${Fmt.km(goalM)} km',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _edit,
                child: Text(goal == null ? 'Atur' : 'Ubah'),
              ),
            ],
          ),
          if (goal == null)
            const Text(
              'Atur target jarak per minggu untuk memantau progres.',
              style: TextStyle(fontSize: 12, color: BsColors.muted),
            )
          else ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 6),
            Text(
              reached
                  ? 'Target minggu ini tercapai!'
                  : '${Fmt.km(goalM - widget.weekM)} km lagi menuju target',
              style: TextStyle(
                fontSize: 12,
                color: reached ? BsColors.success : BsColors.muted,
                fontWeight: reached ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.current});

  final double? current;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.current == null
        ? ''
        : widget.current!.toStringAsFixed(widget.current! % 1 == 0 ? 0 : 1),
  );
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (value == null || value < 1 || value > 500) {
      setState(() => _error = 'Isi angka antara 1 dan 500.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Target mingguan'),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Target (km per minggu)',
          errorText: _error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, 0.0),
            child: const Text(
              'Hapus target',
              style: TextStyle(color: BsColors.danger),
            ),
          ),
        TextButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}

// ======================= MINGGU INI + STREAK =======================

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.weekStart,
    required this.today,
    required this.days,
    required this.weekM,
    required this.lastM,
    required this.streak,
    required this.longest,
  });

  final DateTime weekStart;
  final DateTime today;
  final Set<DateTime> days;
  final double weekM;
  final double lastM;
  final int streak;
  final int longest;

  static const List<String> _labels = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  @override
  Widget build(BuildContext context) {
    String delta;
    Color deltaColor = BsColors.muted;
    IconData? deltaIcon;
    if (lastM <= 0) {
      delta = weekM > 0
          ? 'Minggu lalu belum ada aktivitas'
          : 'Belum ada aktivitas minggu ini';
    } else {
      final pct = ((weekM - lastM) / lastM * 100).round();
      final up = pct >= 0;
      delta = '${up ? '+' : ''}$pct% dari minggu lalu (${Fmt.km(lastM)} km)';
      deltaColor = up ? BsColors.success : BsColors.danger;
      deltaIcon = up ? Icons.trending_up : Icons.trending_down;
    }

    return BsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _DayDot(
                  label: _labels[i],
                  active: days.contains(
                    DateTime(
                      weekStart.year,
                      weekStart.month,
                      weekStart.day + i,
                    ),
                  ),
                  isToday:
                      DateTime(
                        weekStart.year,
                        weekStart.month,
                        weekStart.day + i,
                      ) ==
                      today,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.local_fire_department,
                  color: BsColors.orange,
                  value: '$streak hari',
                  label: 'Streak sekarang',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.emoji_events_outlined,
                  color: BsColors.primary,
                  value: '$longest hari',
                  label: 'Streak terpanjang',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${Fmt.km(weekM)} km minggu ini',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (deltaIcon != null) ...[
                Icon(deltaIcon, size: 16, color: deltaColor),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  delta,
                  style: TextStyle(fontSize: 12, color: deltaColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.active,
    required this.isToday,
  });

  final String label;
  final bool active;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? BsColors.success : Colors.transparent,
            border: Border.all(
              color: active
                  ? BsColors.success
                  : (isToday ? BsColors.primary : const Color(0xFFDEE2E6)),
              width: isToday ? 2 : 1,
            ),
          ),
          child: active
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isToday ? BsColors.primary : BsColors.muted,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: BsColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeBreakdown extends StatelessWidget {
  const _TypeBreakdown({required this.items});

  final List<Activity> items;

  @override
  Widget build(BuildContext context) {
    return BsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final type in ActivityType.values) ...[
            _row(type),
            if (type != ActivityType.values.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _row(ActivityType type) {
    var count = 0;
    var meters = 0.0;
    for (final a in items) {
      if (a.type == type) {
        count++;
        meters += a.distanceM;
      }
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: type.color.withValues(alpha: 0.12),
          child: Icon(type.icon, size: 20, color: type.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            type.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Fmt.distance(meters),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '$count aktivitas',
              style: const TextStyle(fontSize: 11, color: BsColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

// ======================= INSIGHT KEBIASAAN =======================

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.items, required this.activeDays});

  final List<Activity> items;
  final int activeDays;

  static const List<String> _dayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  Widget build(BuildContext context) {
    final dayCount = List<int>.filled(7, 0);
    final slotCount = <String, int>{
      'Pagi': 0,
      'Siang': 0,
      'Sore': 0,
      'Malam': 0,
    };
    final weekTotals = <DateTime, double>{};
    final monthStart = Dates.startOfMonth(DateTime.now());
    var totalM = 0.0;
    Activity? longestMonth;

    for (final a in items) {
      dayCount[a.startTime.weekday - 1]++;

      final h = a.startTime.hour;
      final String slot;
      if (h >= 5 && h < 11) {
        slot = 'Pagi';
      } else if (h >= 11 && h < 15) {
        slot = 'Siang';
      } else if (h >= 15 && h < 19) {
        slot = 'Sore';
      } else {
        slot = 'Malam';
      }
      slotCount[slot] = (slotCount[slot] ?? 0) + 1;

      totalM += a.distanceM;
      final ws = Dates.startOfWeek(a.startTime);
      weekTotals[ws] = (weekTotals[ws] ?? 0) + a.distanceM;

      if (!a.startTime.isBefore(monthStart)) {
        final best = longestMonth;
        if (best == null || a.distanceM > best.distanceM) longestMonth = a;
      }
    }

    var dayIdx = 0;
    for (var i = 1; i < 7; i++) {
      if (dayCount[i] > dayCount[dayIdx]) dayIdx = i;
    }
    final favSlot = slotCount.entries
        .reduce((x, y) => y.value > x.value ? y : x)
        .key;
    final bestWeek = weekTotals.entries.reduce(
      (x, y) => y.value > x.value ? y : x,
    );
    final avgPerDay = activeDays > 0 ? totalM / activeDays : 0.0;
    final month = longestMonth;

    return BsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _InsightRow(
            icon: Icons.calendar_today_outlined,
            label: 'Hari favorit',
            value: '${_dayNames[dayIdx]} (${dayCount[dayIdx]}x)',
          ),
          _InsightRow(
            icon: Icons.schedule,
            label: 'Waktu favorit',
            value: favSlot,
          ),
          _InsightRow(
            icon: Icons.straighten,
            label: 'Rata-rata per hari aktif',
            value: Fmt.distance(avgPerDay),
          ),
          _InsightRow(
            icon: Icons.date_range,
            label: 'Minggu terbaik',
            value:
                '${Fmt.distance(bestWeek.value)} (${Fmt.shortDate(bestWeek.key)})',
          ),
          _InsightRow(
            icon: Icons.terrain,
            label: 'Terpanjang bulan ini',
            value: month == null ? '-' : Fmt.distance(month.distanceM),
            last: true,
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: BsColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: BsColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Period {
  all('Semua'),
  month('Bulan ini'),
  week('Minggu ini');

  const _Period(this.label);
  final String label;
}

enum _Sort {
  newest('Terbaru'),
  farthest('Terjauh'),
  longest('Terlama');

  const _Sort(this.label);
  final String label;
}

class FilteredActivityList extends StatefulWidget {
  const FilteredActivityList({super.key, required this.items});

  final List<Activity> items;

  @override
  State<FilteredActivityList> createState() => _FilteredActivityListState();
}

class _FilteredActivityListState extends State<FilteredActivityList> {
  ActivityType? _type;
  _Period _period = _Period.all;
  _Sort _sort = _Sort.newest;

  List<Activity> _filtered() {
    final now = DateTime.now();
    final DateTime? from = switch (_period) {
      _Period.all => null,
      _Period.month => Dates.startOfMonth(now),
      _Period.week => Dates.startOfWeek(now),
    };

    final list = widget.items.where((a) {
      if (_type != null && a.type != _type) return false;
      if (from != null && a.startTime.isBefore(from)) return false;
      return true;
    }).toList();

    switch (_sort) {
      case _Sort.newest:
        list.sort((a, b) => b.startTime.compareTo(a.startTime));
      case _Sort.farthest:
        list.sort((a, b) => b.distanceM.compareTo(a.distanceM));
      case _Sort.longest:
        list.sort((a, b) => b.durationS.compareTo(a.durationS));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final list = _filtered();
    final filtering = _type != null || _period != _Period.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filtering
              ? 'Aktivitas (${list.length} dari $total)'
              : 'Aktivitas ($total)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (total > 0) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Semua jenis'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              for (final t in ActivityType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in _Period.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _period == p,
                  onSelected: (_) => setState(() => _period = p),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Urutkan: ',
                style: TextStyle(fontSize: 13, color: BsColors.muted),
              ),
              DropdownButton<_Sort>(
                value: _sort,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final s in _Sort.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _sort = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                total == 0
                    ? 'Belum ada aktivitas.'
                    : 'Tidak ada aktivitas yang cocok dengan filter.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BsColors.muted),
              ),
            ),
          )
        else
          for (final a in list) ActivityCard(activity: a, showAuthor: false),
      ],
    );
  }
}
