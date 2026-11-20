/// Profil pengguna (disimpan di localStorage pada kunci `lariku_users`).
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    this.bio = '',
    this.photo,
    this.createdAt,
  });

  final String uid;
  final String displayName;
  final String bio;

  /// Foto profil (JPEG/PNG) dalam bentuk teks base64. Null = belum ada foto.
  final String? photo;
  final DateTime? createdAt;

  AppUser copyWith({
    String? displayName,
    String? bio,
    String? photo,
    bool clearPhoto = false,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      photo: clearPhoto ? null : (photo ?? this.photo),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'bio': bio,
      if (photo != null) 'photo': photo,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return AppUser(
      uid: json['uid'] as String,
      displayName: (json['displayName'] as String?) ?? 'Pengguna',
      bio: (json['bio'] as String?) ?? '',
      photo: json['photo'] as String?,
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : null,
    );
  }
}