import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/bootstrap_theme.dart';
import '../data/local_db.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.radius = 20, this.uid});

  final String name;
  final double radius;

  final String? uid;

  static const List<Color> _palette = [
    BsColors.primary,
    BsColors.success,
    BsColors.danger,
    BsColors.secondary,
    BsColors.dark,
    BsColors.purple,
  ];

  static final Map<String, Uint8List> _decoded = <String, Uint8List>{};

  static Uint8List? _decode(String? base64Text) {
    if (base64Text == null || base64Text.isEmpty) return null;
    final cached = _decoded[base64Text];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(base64Text);
      if (_decoded.length >= 40) _decoded.clear();
      _decoded[base64Text] = bytes;
      return bytes;
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = uid;
    if (id == null) return _initials();

    final db = LocalDb.instance;
    return StreamBuilder<String?>(
      initialData: db.userById(id)?.photo,
      stream: db.watch<String?>(() => db.userById(id)?.photo),
      builder: (context, snap) {
        final bytes = _decode(snap.data);
        if (bytes == null) return _initials();
        return CircleAvatar(
          radius: radius,
          backgroundColor: BsColors.secondary,
          backgroundImage: MemoryImage(bytes),
        );
      },
    );
  }

  Widget _initials() {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final seed = trimmed.codeUnits.fold<int>(0, (sum, c) => sum + c);

    return CircleAvatar(
      radius: radius,
      backgroundColor: _palette[seed % _palette.length],
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
