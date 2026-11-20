import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../core/app_exception.dart';
import '../core/utils/route_utils.dart';
import '../models/activity.dart';
import '../models/app_user.dart';
import '../models/backup_summary.dart';
import '../models/comment.dart';
import '../models/session_user.dart';
import 'key_value_store.dart';
import 'seed_data.dart';

/// Database lokal Lariku: pengganti backend.
///
/// Seluruh data dimuat ke memori saat [init], lalu setiap perubahan ditulis
/// kembali ke [KeyValueStore] (di web: localStorage) sebagai teks JSON.
/// Satu koleksi = satu kunci, dengan awalan `lariku_`:
///
/// | Kunci                | Isi                                           |
/// |----------------------|-----------------------------------------------|
/// | `lariku_users`       | daftar profil pengguna                        |
/// | `lariku_credentials` | email -> {uid, salt, hash kata sandi}         |
/// | `lariku_activities`  | daftar aktivitas (rute dipadatkan)            |
/// | `lariku_comments`    | ID aktivitas -> daftar komentar               |
/// | `lariku_follows`     | daftar pasangan "pengikut|diikuti"            |
/// | `lariku_session`     | UID akun yang sedang masuk                    |
/// | `lariku_seed_version`| versi data contoh yang sudah dimuat           |
///
/// Kelas ini sengaja tidak memakai Flutter, sehingga bisa diuji dengan
/// `MemoryStore` tanpa emulator.
class LocalDb {
  LocalDb({this._store, DateTime Function()? now, math.Random? random})
    : _now = now ?? DateTime.now,
      _random = random ?? math.Random();

  /// Instans yang dipakai seluruh aplikasi. Panggil [init] sekali di `main`.
  static final LocalDb instance = LocalDb();

  /// Jumlah titik rute maksimal per aktivitas yang disimpan.
  static const int maxRoutePoints = 500;

  /// Awalan semua kunci di penyimpanan.
  static const String keyPrefix = 'lariku_';

  static const String _kUsers = 'users';
  static const String _kCredentials = 'credentials';
  static const String _kActivities = 'activities';
  static const String _kComments = 'comments';
  static const String _kFollows = 'follows';
  static const String _kSession = 'session';
  static const String _kSeedVersion = 'seed_version';

  static const List<String> _dataKeys = <String>[
    _kUsers,
    _kCredentials,
    _kActivities,
    _kComments,
    _kFollows,
    _kSession,
  ];

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String value) => _emailRegex.hasMatch(value.trim());

  KeyValueStore? _store;
  final DateTime Function() _now;
  final math.Random _random;

  // ---- Keadaan di memori ----
  final Map<String, AppUser> _users = <String, AppUser>{};
  final Map<String, _Credential> _credentials = <String, _Credential>{};
  final List<Activity> _activities = <Activity>[];
  final Map<String, List<Comment>> _comments = <String, List<Comment>>{};
  final Set<String> _follows = <String>{};
  String? _sessionUid;

  // ---- Penulisan ke penyimpanan ----
  final Set<String> _dirty = <String>{};
  Future<void> _flushChain = Future<void>.value();

  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  KeyValueStore get _requireStore {
    final s = _store;
    if (s == null) {
      throw StateError('LocalDb belum dimulai. Panggil init() lebih dulu.');
    }
    return s;
  }

  String _k(String name) => '$keyPrefix$name';

  // =====================================================================
  // Memulai

  /// Memuat data dari penyimpanan. Bila penyimpanan masih kosong (pertama
  /// kali dipakai), data contoh dimuat dan langsung disimpan.
  ///
  /// Bila isi penyimpanan rusak (misalnya JSON diubah manual dan tidak valid),
  /// database dimulai ulang dari data contoh.
  Future<void> init({KeyValueStore? store, bool seed = true}) async {
    if (store != null) _store = store;
    final s = _requireStore;

    _clearMemory();
    _dirty.clear();
    _flushChain = Future<void>.value();

    final raw = <String, String?>{
      for (final name in _dataKeys) name: await s.read(_k(name)),
    };

    final fresh = raw[_kUsers] == null && raw[_kActivities] == null;
    var needsRewrite = false;

    if (fresh) {
      if (seed) _applySeed();
      needsRewrite = true;
    } else if (!_load(raw)) {
      if (seed) _applySeed();
      needsRewrite = true;
    }

    if (needsRewrite) {
      _dirty.addAll(_dataKeys);
      await _flush();
      await s.write(_k(_kSeedVersion), '${SeedData.version}');
    }
    _notify();
  }

  bool _load(Map<String, String?> raw) {
    try {
      _adopt(
        _Snapshot.parse(
          users: _decodeList(raw[_kUsers]),
          credentials: _decodeMap(raw[_kCredentials]),
          activities: _decodeList(raw[_kActivities]),
          comments: _decodeMap(raw[_kComments]),
          follows: _decodeList(raw[_kFollows]),
        ),
      );

      final session = raw[_kSession];
      if (session != null && _users.containsKey(session)) {
        _sessionUid = session;
      }
      return true;
    } catch (_) {
      _clearMemory();
      return false;
    }
  }

  /// Mengganti seluruh isi memori dengan [snapshot] (sesi login dikosongkan).
  void _adopt(_Snapshot snapshot) {
    _clearMemory();
    _users.addAll(snapshot.users);
    _credentials.addAll(snapshot.credentials);
    _activities.addAll(snapshot.activities);
    _comments.addAll(snapshot.comments);
    _follows.addAll(snapshot.follows);
  }

  static List<dynamic> _decodeList(String? text) {
    if (text == null) return <dynamic>[];
    return jsonDecode(text) as List<dynamic>;
  }

  static Map<String, dynamic> _decodeMap(String? text) {
    if (text == null) return <String, dynamic>{};
    return jsonDecode(text) as Map<String, dynamic>;
  }

  void _clearMemory() {
    _users.clear();
    _credentials.clear();
    _activities.clear();
    _comments.clear();
    _follows.clear();
    _sessionUid = null;
  }

  void _applySeed() {
    final bundle = SeedData.build(_now());
    for (final u in bundle.users) {
      _users[u.uid] = u;
    }
    _activities.addAll(bundle.activities);
    bundle.comments.forEach((id, list) {
      _comments[id] = List<Comment>.of(list);
    });
    _follows.addAll(bundle.follows);
  }

  /// Menghapus semua data lalu (bila [seed]) memuat ulang data contoh.
  /// Sesi login ikut dihapus.
  Future<void> resetAll({bool seed = true}) async {
    _clearMemory();
    _dirty.clear();
    if (seed) _applySeed();
    _notify();

    _dirty.addAll(_dataKeys);
    await _flush();
    await _requireStore.write(_k(_kSeedVersion), '${SeedData.version}');
  }

  // =====================================================================
  // Akun

  SessionUser? get currentUser {
    final uid = _sessionUid;
    if (uid == null) return null;
    final user = _users[uid];
    if (user == null) return null;
    return SessionUser(
      uid: uid,
      email: _emailOf(uid),
      displayName: user.displayName,
    );
  }

  String _emailOf(String uid) {
    for (final entry in _credentials.entries) {
      if (entry.value.uid == uid) return entry.key;
    }
    return '';
  }

  /// Membuat akun baru lalu langsung masuk.
  Future<SessionUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty) {
      throw const AppException('Nama tidak boleh kosong.');
    }
    if (!isValidEmail(cleanEmail)) {
      throw const AppException('Format email tidak valid.');
    }
    if (password.length < 6) {
      throw const AppException(
        'Kata sandi terlalu lemah (minimal 6 karakter).',
      );
    }
    if (_credentials.containsKey(cleanEmail)) {
      throw const AppException('Email sudah terdaftar. Silakan masuk.');
    }

    final uid = _newId(_users.containsKey);
    final salt = _newId((_) => false);
    final previousSession = _sessionUid;

    _users[uid] = AppUser(uid: uid, displayName: cleanName, createdAt: _now());
    _credentials[cleanEmail] = _Credential(
      uid: uid,
      salt: salt,
      hash: _hash(salt, password),
    );
    _sessionUid = uid;

    try {
      await _commit(<String>{_kUsers, _kCredentials, _kSession});
    } catch (_) {
      _users.remove(uid);
      _credentials.remove(cleanEmail);
      _sessionUid = previousSession;
      _notify();
      rethrow;
    }
    return SessionUser(uid: uid, email: cleanEmail, displayName: cleanName);
  }

  Future<SessionUser> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!isValidEmail(cleanEmail)) {
      throw const AppException('Format email tidak valid.');
    }
    final cred = _credentials[cleanEmail];
    if (cred == null || cred.hash != _hash(cred.salt, password)) {
      throw const AppException('Email atau kata sandi salah.');
    }
    final user = _users[cred.uid];
    if (user == null) {
      throw const AppException('Email atau kata sandi salah.');
    }

    _sessionUid = cred.uid;
    await _commit(<String>{_kSession});
    return SessionUser(
      uid: cred.uid,
      email: cleanEmail,
      displayName: user.displayName,
    );
  }

  Future<void> logout() async {
    if (_sessionUid == null) return;
    _sessionUid = null;
    await _commit(<String>{_kSession});
  }

  /// Mengubah nama tampilan akun yang sedang masuk (bila belum sama).
  Future<void> updateDisplayName(String name) async {
    final me = currentUser;
    if (me == null) return;
    final clean = name.trim();
    if (clean.isEmpty || clean == me.displayName) return;
    await updateProfile(
      uid: me.uid,
      displayName: clean,
      bio: _users[me.uid]?.bio ?? '',
    );
  }

  /// Kata sandi tidak disimpan polos, tetapi di-hash dengan garam.
  /// Ini hanya untuk kerapian: data localStorage tetap bisa dibaca dan diubah
  /// siapa pun yang memegang browser/perangkat ini.
  String _hash(String salt, String password) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  // =====================================================================
  // Pengguna

  AppUser? userById(String uid) => _users[uid];

  /// Mencari pengguna yang namanya memuat [keyword]. Kata kunci kosong
  /// menampilkan 20 pengguna yang paling baru mendaftar.
  List<AppUser> searchUsers(String keyword) {
    final q = keyword.trim().toLowerCase();
    final all = _users.values.toList();

    if (q.isEmpty) {
      all.sort((a, b) {
        final byDate = (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          a.createdAt?.millisecondsSinceEpoch ?? 0,
        );
        return byDate != 0 ? byDate : a.uid.compareTo(b.uid);
      });
      return all.take(20).toList();
    }

    final found =
        all.where((u) => u.displayName.toLowerCase().contains(q)).toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
    return found.take(20).toList();
  }

  /// Mengubah profil, lalu menyalin nama baru ke semua aktivitas dan komentar
  /// milik pengguna itu (nama pembuat disimpan di tiap aktivitas/komentar).
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String bio,
  }) async {
    final user = _users[uid];
    if (user == null) throw const AppException('Akun tidak ditemukan.');
    final name = displayName.trim();
    if (name.isEmpty) throw const AppException('Nama tidak boleh kosong.');

    _users[uid] = user.copyWith(displayName: name, bio: bio.trim());
    for (var i = 0; i < _activities.length; i++) {
      if (_activities[i].userId == uid) {
        _activities[i] = _activities[i].copyWith(userName: name);
      }
    }
    for (final list in _comments.values) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].userId == uid) list[i] = list[i].copyWith(userName: name);
      }
    }
    await _commit(<String>{_kUsers, _kActivities, _kComments});
  }

  /// Batas ukuran foto profil (jumlah karakter base64, sekitar 220 KB).
  static const int maxPhotoChars = 300000;

  /// Mengganti foto profil. [photo] berupa teks base64; null menghapus foto.
  Future<void> setUserPhoto(String uid, String? photo) async {
    final user = _users[uid];
    if (user == null) throw const AppException('Akun tidak ditemukan.');
    if (photo != null && photo.length > maxPhotoChars) {
      throw const AppException('Foto terlalu besar. Pilih foto lain.');
    }
    _users[uid] = user.copyWith(photo: photo, clearPhoto: photo == null);
    await _commit(<String>{_kUsers});
  }

  // =====================================================================
  // Aktivitas

  int _activityIndex(String id) => _activities.indexWhere((a) => a.id == id);

  Activity _withCount(Activity a) =>
      a.copyWith(commentsCount: _comments[a.id]?.length ?? 0);

  /// Semua aktivitas, terbaru di atas. Jumlah komentar dihitung di sini.
  List<Activity> allActivities() {
    final list = _activities.map(_withCount).toList();
    list.sort((a, b) {
      final byTime = b.startTime.compareTo(a.startTime);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return list;
  }

  Activity? activityById(String id) {
    final i = _activityIndex(id);
    return i < 0 ? null : _withCount(_activities[i]);
  }

  /// Menyimpan aktivitas baru dan mengembalikan ID-nya. ID, kudos, dan jumlah
  /// komentar pada [draft] diabaikan. Rute disederhanakan agar hemat tempat.
  Future<String> addActivity(Activity draft) async {
    if (!_users.containsKey(draft.userId)) {
      throw const AppException('Akun tidak ditemukan. Silakan masuk kembali.');
    }

    final id = _newId((candidate) => _activityIndex(candidate) >= 0);
    // Dibulatkan seperti saat disimpan, supaya isi memori sama dengan isi
    // penyimpanan.
    final route = RouteUtils.decode(
      RouteUtils.encode(
        RouteUtils.simplify(draft.route, maxPoints: maxRoutePoints),
      ),
    );

    _activities.add(
      Activity(
        id: id,
        userId: draft.userId,
        userName: draft.userName,
        title: draft.title,
        type: draft.type,
        description: draft.description,
        distanceM: draft.distanceM,
        durationS: draft.durationS,
        startTime: draft.startTime,
        route: route,
      ),
    );

    try {
      await _commit(<String>{_kActivities});
    } catch (_) {
      _activities.removeWhere((a) => a.id == id);
      _notify();
      rethrow;
    }
    return id;
  }

  /// Menghapus aktivitas beserta semua komentarnya.
  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    _comments.remove(id);
    await _commit(<String>{_kActivities, _kComments});
  }

  /// Memberi ([give] = true) atau mencabut kudos.
  Future<void> setKudos({
    required String activityId,
    required String uid,
    required bool give,
  }) async {
    final i = _activityIndex(activityId);
    if (i < 0) throw const AppException(_missingActivity);

    final current = _activities[i];
    final has = current.kudosBy.contains(uid);
    if (give == has) return;

    final next = List<String>.of(current.kudosBy);
    if (give) {
      next.add(uid);
    } else {
      next.remove(uid);
    }
    _activities[i] = current.copyWith(kudosBy: next);
    await _commit(<String>{_kActivities});
  }

  static const String _missingActivity =
      'Aktivitas tidak ditemukan (mungkin sudah dihapus).';

  // =====================================================================
  // Komentar

  /// Komentar sebuah aktivitas, yang terlama di atas.
  List<Comment> commentsFor(String activityId) {
    return List<Comment>.of(_comments[activityId] ?? const <Comment>[]);
  }

  Future<void> addComment({
    required String activityId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      throw const AppException('Komentar tidak boleh kosong.');
    }
    if (_activityIndex(activityId) < 0) {
      throw const AppException(_missingActivity);
    }

    final id = _newId(
      (candidate) =>
          _comments.values.any((l) => l.any((c) => c.id == candidate)),
    );
    _comments
        .putIfAbsent(activityId, () => <Comment>[])
        .add(
          Comment(
            id: id,
            userId: userId,
            userName: userName,
            text: clean,
            createdAt: _now(),
          ),
        );
    await _commit(<String>{_kComments});
  }

  Future<void> deleteComment({
    required String activityId,
    required String commentId,
  }) async {
    final list = _comments[activityId];
    if (list == null) return;
    list.removeWhere((c) => c.id == commentId);
    if (list.isEmpty) _comments.remove(activityId);
    await _commit(<String>{_kComments});
  }

  // =====================================================================
  // Mengikuti

  Future<void> setFollow({
    required String me,
    required String target,
    required bool follow,
  }) async {
    if (me == target) return;
    final key = '$me|$target';
    final changed = follow ? _follows.add(key) : _follows.remove(key);
    if (!changed) return;
    await _commit(<String>{_kFollows});
  }

  /// UID yang diikuti oleh [uid].
  Set<String> followingOf(String uid) {
    final prefix = '$uid|';
    return <String>{
      for (final key in _follows)
        if (key.startsWith(prefix)) key.substring(prefix.length),
    };
  }

  /// UID yang mengikuti [uid].
  Set<String> followersOf(String uid) {
    final suffix = '|$uid';
    return <String>{
      for (final key in _follows)
        if (key.endsWith(suffix)) key.substring(0, key.length - suffix.length),
    };
  }

  int followersCount(String uid) {
    final suffix = '|$uid';
    return _follows.where((key) => key.endsWith(suffix)).length;
  }

  int followingCount(String uid) {
    final prefix = '$uid|';
    return _follows.where((key) => key.startsWith(prefix)).length;
  }

  // =====================================================================
  // Cadangan

  /// Pengenal aplikasi di dalam berkas cadangan.
  static const String backupApp = 'lariku';

  /// Versi format berkas cadangan yang dibuat dan dipahami kelas ini.
  static const int backupFormat = 1;

  static const String _unreadableBackup =
      'Berkas cadangan tidak dapat dibaca. Pastikan isinya utuh dan berasal '
      'dari Lariku.';

  static const String _damagedBackup =
      'Isi cadangan rusak atau tidak lengkap, sehingga tidak dipulihkan. '
      'Data yang sekarang tidak diubah.';

  /// Seluruh data (akun, aktivitas, komentar, pengikut) sebagai teks JSON.
  /// Sesi login tidak ikut: setelah dipulihkan pengguna masuk kembali.
  String exportJson() {
    return jsonEncode(<String, dynamic>{
      'app': backupApp,
      'format': backupFormat,
      'exportedAt': _now().toUtc().toIso8601String(),
      'data': <String, dynamic>{
        for (final name in _dataKeys)
          if (name != _kSession) name: _collection(name),
      },
    });
  }

  /// Memeriksa teks cadangan dan menghitung isinya tanpa mengubah apa pun.
  /// Melempar [AppException] bila cadangan tidak valid.
  static BackupSummary inspectBackup(String text) => _parseBackup(text).summary;

  /// Mengganti SEMUA data yang sekarang dengan isi cadangan [text], lalu keluar
  /// dari akun (sesi login tidak ikut dicadangkan).
  ///
  /// Cadangan diperiksa lebih dulu. Bila tidak valid, atau bila penyimpanan
  /// gagal, data yang sekarang dibiarkan seperti semula.
  Future<BackupSummary> importJson(String text) async {
    final backup = _parseBackup(text);
    final summary = backup.summary;
    final previous = _snapshotNow();
    final previousSession = _sessionUid;

    _adopt(backup.snapshot);
    try {
      await _commit(_dataKeys.toSet());
    } catch (_) {
      _adopt(previous);
      _sessionUid = previousSession;
      _notify();
      try {
        // Tulis ulang isi lama supaya penyimpanan tidak tinggal setengah jadi.
        await _flush();
      } catch (_) {
        // Dicoba lagi pada penyimpanan berikutnya.
      }
      rethrow;
    }
    return summary;
  }

  /// Salinan isi memori (elemennya tidak berubah, jadi cukup menyalin wadah).
  _Snapshot _snapshotNow() {
    return _Snapshot(
      users: Map<String, AppUser>.of(_users),
      credentials: Map<String, _Credential>.of(_credentials),
      activities: List<Activity>.of(_activities),
      comments: <String, List<Comment>>{
        for (final e in _comments.entries) e.key: List<Comment>.of(e.value),
      },
      follows: Set<String>.of(_follows),
    );
  }

  static _Backup _parseBackup(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } catch (_) {
      throw const AppException(_unreadableBackup);
    }
    if (root is! Map<String, dynamic> || root['app'] != backupApp) {
      throw const AppException('Berkas ini bukan cadangan Lariku.');
    }

    final format = root['format'];
    if (format is num && format > backupFormat) {
      throw const AppException(
        'Cadangan ini dibuat oleh versi Lariku yang lebih baru dan belum bisa '
        'dipulihkan di sini.',
      );
    }
    if (format != backupFormat) throw const AppException(_damagedBackup);

    try {
      final data = root['data'] as Map<String, dynamic>;
      final snapshot = _Snapshot.parse(
        users: data[_kUsers] as List<dynamic>,
        credentials: data[_kCredentials] as Map<String, dynamic>,
        activities: data[_kActivities] as List<dynamic>,
        comments: data[_kComments] as Map<String, dynamic>,
        follows: data[_kFollows] as List<dynamic>,
      );
      final exported = root['exportedAt'];
      return _Backup(
        snapshot,
        exported is String ? DateTime.tryParse(exported)?.toLocal() : null,
      );
    } catch (_) {
      throw const AppException(_damagedBackup);
    }
  }

  // =====================================================================
  // Pengamatan perubahan

  /// Aliran yang langsung mengirim nilai [read] saat didengarkan, lalu
  /// mengirim ulang setiap kali data berubah (seperti aliran data waktu nyata
  /// milik database server). Setiap pendengar mendapat alirannya sendiri.
  Stream<T> watch<T>(T Function() read) {
    return Stream<T>.multi((MultiStreamController<T> controller) {
      void emit() {
        try {
          controller.add(read());
        } catch (e, st) {
          controller.addError(e, st);
        }
      }

      emit();
      final StreamSubscription<void> sub = _changes.stream.listen(
        (_) => emit(),
      );
      controller.onCancel = sub.cancel;
    });
  }

  void _notify() => _changes.add(null);

  // =====================================================================
  // Menyimpan

  /// Menandai [keys] perlu ditulis, memberi tahu pendengar, lalu menulis.
  Future<void> _commit(Set<String> keys) {
    _dirty.addAll(keys);
    _notify();
    return _flush();
  }

  /// Penulisan dirantai supaya tidak pernah ada dua penulisan yang berjalan
  /// bersamaan dan urutannya selalu sama dengan urutan perubahan.
  Future<void> _flush() {
    final next = _flushChain
        .catchError((Object _) {})
        .then((_) => _writeDirty());
    _flushChain = next;
    return next;
  }

  Future<void> _writeDirty() async {
    final keys = _dirty.toList();
    _dirty.clear();
    try {
      for (final name in keys) {
        await _writeKey(name);
      }
    } catch (e) {
      _dirty.addAll(keys); // dicoba lagi pada penyimpanan berikutnya
      if (e is AppException) rethrow;
      throw AppException(
        'Data tidak dapat disimpan di perangkat. Penyimpanan mungkin penuh '
        'atau diblokir browser ($e).',
      );
    }
  }

  /// Isi satu koleksi dalam bentuk yang siap diubah menjadi JSON.
  /// Dipakai oleh penyimpanan ([_writeKey]) dan oleh [exportJson], sehingga
  /// isi cadangan selalu sama dengan isi penyimpanan.
  Object? _collection(String name) => switch (name) {
    _kUsers => _users.values.map((u) => u.toJson()).toList(),
    _kCredentials => _credentials.map(
      (email, c) => MapEntry(email, c.toJson()),
    ),
    _kActivities => _activities.map((a) => a.toJson()).toList(),
    _kComments => _comments.map(
      (id, list) => MapEntry(id, list.map((c) => c.toJson()).toList()),
    ),
    _kFollows => _follows.toList()..sort(),
    _ => null,
  };

  Future<void> _writeKey(String name) async {
    final s = _requireStore;
    final collection = _collection(name);
    final String? value = name == _kSession
        ? _sessionUid
        : (collection == null ? null : jsonEncode(collection));

    if (value == null) {
      await s.remove(_k(name));
    } else {
      await s.write(_k(name), value);
    }
  }

  /// ID unik pendek: waktu (basis 36) + angka acak (basis 36).
  String _newId(bool Function(String id) exists) {
    while (true) {
      final time = _now().microsecondsSinceEpoch.toRadixString(36);
      final rand = _random.nextInt(0x7fffffff).toRadixString(36);
      final id = '$time$rand';
      if (!exists(id)) return id;
    }
  }
}

/// Isi database yang sudah diperiksa seluruhnya, tetapi belum dipasang ke
/// memori. Pemasangan baru dilakukan bila semua bagian berhasil dibaca,
/// sehingga data rusak tidak pernah menimpa data yang sedang dipakai.
class _Snapshot {
  const _Snapshot({
    required this.users,
    required this.credentials,
    required this.activities,
    required this.comments,
    required this.follows,
  });

  factory _Snapshot.parse({
    required List<dynamic> users,
    required Map<String, dynamic> credentials,
    required List<dynamic> activities,
    required Map<String, dynamic> comments,
    required List<dynamic> follows,
  }) {
    final parsedUsers = <String, AppUser>{};
    for (final item in users) {
      final user = AppUser.fromJson(item as Map<String, dynamic>);
      parsedUsers[user.uid] = user;
    }

    return _Snapshot(
      users: parsedUsers,
      credentials: credentials.map(
        (email, value) => MapEntry(
          email,
          _Credential.fromJson(value as Map<String, dynamic>),
        ),
      ),
      activities: <Activity>[
        for (final item in activities)
          Activity.fromJson(item as Map<String, dynamic>),
      ],
      comments: comments.map(
        (activityId, value) => MapEntry(activityId, <Comment>[
          for (final c in value as List<dynamic>)
            Comment.fromJson(c as Map<String, dynamic>),
        ]),
      ),
      follows: follows.whereType<String>().toSet(),
    );
  }

  final Map<String, AppUser> users;
  final Map<String, _Credential> credentials;
  final List<Activity> activities;
  final Map<String, List<Comment>> comments;
  final Set<String> follows;
}

/// Hasil membaca berkas cadangan.
class _Backup {
  const _Backup(this.snapshot, this.exportedAt);

  final _Snapshot snapshot;
  final DateTime? exportedAt;

  BackupSummary get summary {
    var commentCount = 0;
    for (final list in snapshot.comments.values) {
      commentCount += list.length;
    }
    return BackupSummary(
      users: snapshot.users.length,
      activities: snapshot.activities.length,
      comments: commentCount,
      follows: snapshot.follows.length,
      exportedAt: exportedAt,
    );
  }
}

class _Credential {
  const _Credential({
    required this.uid,
    required this.salt,
    required this.hash,
  });

  final String uid;
  final String salt;
  final String hash;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'uid': uid, 'salt': salt, 'hash': hash};
  }

  factory _Credential.fromJson(Map<String, dynamic> json) {
    return _Credential(
      uid: json['uid'] as String,
      salt: json['salt'] as String,
      hash: json['hash'] as String,
    );
  }
}