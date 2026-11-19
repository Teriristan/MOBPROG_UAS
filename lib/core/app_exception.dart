/// Kesalahan yang pesannya boleh langsung ditampilkan kepada pengguna,
/// misalnya "Email sudah terdaftar. Silakan masuk."
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
