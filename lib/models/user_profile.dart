class UserProfile {
  final String name;
  final String username;
  final String bio;
  final String city;

  const UserProfile({
    required this.name,
    required this.username,
    required this.bio,
    required this.city,
  });

  UserProfile copyWith({
    String? name,
    String? username,
    String? bio,
    String? city,
  }) {
    return UserProfile(
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      city: city ?? this.city,
    );
  }
}