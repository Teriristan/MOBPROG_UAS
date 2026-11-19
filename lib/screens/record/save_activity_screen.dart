import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../core/utils/route_utils.dart';
import '../../models/activity.dart';
import '../../models/activity_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/bs/bs_alert.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_text_field.dart';
import '../../widgets/route_map.dart';
import '../../widgets/stat_tile.dart';

/// Layar setelah perekaman selesai: beri judul, catatan, lalu simpan.
class SaveActivityScreen extends StatefulWidget {
  const SaveActivityScreen({super.key});

  @override
  State<SaveActivityScreen> createState() => _SaveActivityScreenState();
}

class _SaveActivityScreenState extends State<SaveActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descC = TextEditingController();
  late final TextEditingController _titleC;

  // Salinan data rekaman, supaya tampilan tidak berubah saat provider
  // di-reset setelah disimpan.
  late final List<LatLng> _route;
  late final double _distanceM;
  late final int _durationS;
  late final DateTime _startedAt;
  late ActivityType _type;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = context.read<TrackingProvider>();
    _route = List<LatLng>.of(t.route);
    _distanceM = t.distanceM;
    _durationS = t.elapsedS;
    _startedAt = t.startedAt ?? DateTime.now();
    _type = t.type;
    _titleC = TextEditingController(text: _defaultTitle(_type));
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    super.dispose();
  }

  /// Contoh: "Lari Pagi", "Sepeda Sore".
  String _defaultTitle(ActivityType type) {
    final h = _startedAt.hour;
    final part = h < 11
        ? 'Pagi'
        : (h < 15 ? 'Siang' : (h < 18 ? 'Sore' : 'Malam'));
    return '${type.label} $part';
  }

  void _changeType(ActivityType next) {
    final wasDefault = _titleC.text == _defaultTitle(_type);
    setState(() {
      _type = next;
      if (wasDefault) _titleC.text = _defaultTitle(next);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final tracking = context.read<TrackingProvider>();
    final auth = context.read<AuthProvider>();
    final nav = context.read<NavProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final activity = Activity(
        id: '',
        userId: uid,
        userName: auth.displayName,
        title: _titleC.text.trim(),
        type: _type,
        description: _descC.text.trim(),
        distanceM: _distanceM,
        durationS: _durationS,
        startTime: _startedAt,
        route: RouteUtils.simplify(_route),
      );
      await ActivityService().create(activity);

      tracking.reset();
      nav.go(0);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Aktivitas berhasil disimpan.')),
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

  Future<void> _discard() async {
    final tracking = context.read<TrackingProvider>();
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
    if (ok != true) return;

    tracking.reset();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BsAppBar(title: 'Simpan Aktivitas'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(BsRadius.md),
            child: SizedBox(
              height: 200,
              child: RouteMap(
                route: _route,
                fitRoute: true,
                interactive: false,
                showEndpoints: true,
                color: _type.color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          BsCard(
            child: ActivityStatsRow(
              distanceM: _distanceM,
              durationS: _durationS,
              type: _type,
              big: true,
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BsTextField(
                  controller: _titleC,
                  label: 'Judul aktivitas',
                  prefixIcon: Icons.title,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Judul wajib diisi'
                      : null,
                ),
                const SizedBox(height: 4),
                BsTextField(
                  controller: _descC,
                  label: 'Catatan (opsional)',
                  hint: 'Bagaimana rasanya hari ini?',
                  prefixIcon: Icons.notes,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  maxLength: 200,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Jenis aktivitas',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final type in ActivityType.values)
                ChoiceChip(
                  avatar: Icon(
                    type.icon,
                    size: 18,
                    color: _type == type ? Colors.white : type.color,
                  ),
                  label: Text(type.label),
                  selected: _type == type,
                  selectedColor: type.color,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _type == type ? Colors.white : BsColors.body,
                  ),
                  onSelected: _saving ? null : (_) => _changeType(type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            BsAlert(
              message: _error!,
              variant: BsVariant.danger,
              icon: Icons.error_outline,
            ),
            const SizedBox(height: 12),
          ],
          BsButton(
            label: 'Simpan aktivitas',
            icon: Icons.check,
            block: true,
            loading: _saving,
            onPressed: _save,
          ),
          const SizedBox(height: 8),
          BsButton(
            label: 'Buang rekaman',
            icon: Icons.delete_outline,
            variant: BsVariant.danger,
            outline: true,
            block: true,
            onPressed: _saving ? null : _discard,
          ),
        ],
      ),
    );
  }
}
