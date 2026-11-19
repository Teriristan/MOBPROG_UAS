/// Akun yang sedang masuk (sesi login yang diingat di perangkat ini).
class SessionUser {
  const SessionUser({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  final String uid;
  final String email;
  final String displayName;
}
