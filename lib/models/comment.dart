/// Komentar pada sebuah aktivitas
/// (disimpan di localStorage pada kunci `lariku_comments`).
class Comment {
  const Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  Comment copyWith({String? userName}) {
    return Comment(
      id: id,
      userId: userId,
      userName: userName ?? this.userName,
      text: text,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      userId: (json['userId'] as String?) ?? '',
      userName: (json['userName'] as String?) ?? 'Pengguna',
      text: (json['text'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['createdAt'] as num?) ?? 0).toInt(),
      ),
    );
  }
}
