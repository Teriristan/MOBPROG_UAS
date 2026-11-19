/// Profil pengguna (disimpan di localStorage pada kunci `lariku_users`).
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    this.bio = '',
    this.createdAt,
  });

  final String uid;
  final String displayName;
  final String bio;
  final DateTime? createdAt;

  AppUser copyWith({String? displayName, String? bio}) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'bio': bio,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return AppUser(
      uid: json['uid'] as String,
      displayName: (json['displayName'] as String?) ?? 'Pengguna',
      bio: (json['bio'] as String?) ?? '',
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : null,
    );
  }
}
