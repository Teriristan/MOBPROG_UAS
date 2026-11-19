/// Penyimpanan kunci-nilai bertipe teks.
///
/// Di aplikasi diwujudkan oleh `PrefsStore` (localStorage di web, penyimpanan
/// lokal aplikasi di Android). Di pengujian diganti [MemoryStore].
abstract interface class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

/// Penyimpanan di memori: isinya hilang saat aplikasi ditutup.
/// Dipakai oleh pengujian.
class MemoryStore implements KeyValueStore {
  /// Isi penyimpanan, boleh diperiksa langsung oleh pengujian.
  final Map<String, String> data = <String, String>{};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }
}
