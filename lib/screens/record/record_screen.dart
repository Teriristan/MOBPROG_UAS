import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../models/activity_type.dart';
import '../../providers/tracking_provider.dart';
import '../../widgets/bs/bs_alert.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_badge.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/route_map.dart';
import '../../widgets/stat_tile.dart';
import 'save_activity_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TrackingProvider>().locate();
    });
  }

  void _openSave() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SaveActivityScreen()));
  }

  Future<void> _finish() async {
    final t = context.read<TrackingProvider>();

    if (t.distanceM < 10) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rekaman terlalu pendek'),
          content: const Text(
            'Jarak masih di bawah 10 meter sehingga belum layak disimpan. '
            'Lanjutkan merekam atau buang rekaman ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Lanjutkan'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Buang',
                style: TextStyle(color: BsColors.danger),
              ),
            ),
          ],
        ),
      );
      if (discard == true) t.reset();
      return;
    }

    t.finish();
    if (mounted) _openSave();
  }

  Future<void> _discard() async {
    final t = context.read<TrackingProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buang rekaman?'),
        content: const Text('Rekaman ini tidak akan disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Buang',
              style: TextStyle(color: BsColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) t.reset();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackingProvider>();

    return Scaffold(
      appBar: const BsAppBar(title: 'Rekam Aktivitas'),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: RouteMap(
                    route: t.route,
                    current: t.current,
                    followCurrent: true,
                    interactive: !t.isActive,
                    color: t.type.color,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Center(child: _TopBar(tracking: t)),
                ),
                if (!t.isActive)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: IconButton.filled(
                      tooltip: 'Lokasi saya',
                      onPressed: () => t.locate(ask: true),
                      icon: const Icon(Icons.my_location),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: BsColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildPanel(t),
        ],
      ),
    );
  }

  Widget _buildPanel(TrackingProvider t) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: BsColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.error != null) ...[
              BsAlert(
                message: t.error!,
                variant: BsVariant.warning,
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(height: 10),
            ],
            ActivityStatsRow(
              distanceM: t.distanceM,
              durationS: t.elapsedS,
              type: t.type,
              big: true,
            ),
            const SizedBox(height: 14),
            ..._buildButtons(t),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildButtons(TrackingProvider t) {
    switch (t.status) {
      case TrackingStatus.idle:
        return [
          Row(
            children: [
              Switch(value: t.simulate, onChanged: t.setSimulate),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Mode simulasi (uji coba tanpa bergerak)',
                  style: TextStyle(fontSize: 12, color: BsColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BsButton(
            label: 'MULAI',
            icon: Icons.play_arrow,
            variant: BsVariant.success,
            block: true,
            onPressed: t.start,
          ),
        ];

      case TrackingStatus.recording:
        return [
          Row(
            children: [
              Expanded(
                child: BsButton(
                  label: 'Jeda',
                  icon: Icons.pause,
                  variant: BsVariant.warning,
                  onPressed: t.pause,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BsButton(
                  label: 'Selesai',
                  icon: Icons.stop,
                  variant: BsVariant.danger,
                  onPressed: _finish,
                ),
              ),
            ],
          ),
        ];

      case TrackingStatus.paused:
        return [
          Row(
            children: [
              Expanded(
                child: BsButton(
                  label: 'Lanjut',
                  icon: Icons.play_arrow,
                  variant: BsVariant.success,
                  onPressed: t.resume,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BsButton(
                  label: 'Selesai',
                  icon: Icons.stop,
                  variant: BsVariant.danger,
                  onPressed: _finish,
                ),
              ),
            ],
          ),
        ];

      case TrackingStatus.finished:
        return [
          const BsAlert(
            message: 'Rekaman sudah selesai tetapi belum disimpan.',
            variant: BsVariant.info,
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: BsButton(
                  label: 'Simpan',
                  icon: Icons.save_outlined,
                  onPressed: _openSave,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BsButton(
                  label: 'Buang',
                  icon: Icons.delete_outline,
                  variant: BsVariant.danger,
                  outline: true,
                  onPressed: _discard,
                ),
              ),
            ],
          ),
        ];
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.tracking});

  final TrackingProvider tracking;

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    const shadow = [BoxShadow(color: Color(0x26000000), blurRadius: 6)];

    if (t.status == TrackingStatus.idle) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BsRadius.lg),
          boxShadow: shadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in ActivityType.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  avatar: Icon(
                    type.icon,
                    size: 18,
                    color: t.type == type ? Colors.white : type.color,
                  ),
                  label: Text(type.label),
                  selected: t.type == type,
                  selectedColor: type.color,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: t.type == type ? Colors.white : BsColors.body,
                  ),
                  onSelected: (_) => t.setType(type),
                ),
              ),
          ],
        ),
      );
    }

    final (String text, BsVariant variant) = switch (t.status) {
      TrackingStatus.recording => ('MEREKAM', BsVariant.danger),
      TrackingStatus.paused => ('DIJEDA', BsVariant.warning),
      _ => ('SELESAI', BsVariant.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BsRadius.lg),
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(t.type.icon, color: t.type.color),
          const SizedBox(width: 8),
          Text(
            t.type.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          BsBadge(text: text, variant: variant, pill: true),
        ],
      ),
    );
  }
}
