import '../data/local_db.dart';
import '../models/comment.dart';

class SocialService {
  SocialService({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;

  Future<void> setKudos({
    required String activityId,
    required String uid,
    required bool give,
  }) {
    return _db.setKudos(activityId: activityId, uid: uid, give: give);
  }

  Stream<List<Comment>> watchComments(String activityId) {
    return _db.watch<List<Comment>>(() => _db.commentsFor(activityId));
  }

  Future<void> addComment({
    required String activityId,
    required String userId,
    required String userName,
    required String text,
  }) {
    return _db.addComment(
      activityId: activityId,
      userId: userId,
      userName: userName,
      text: text,
    );
  }

  Future<void> deleteComment({
    required String activityId,
    required String commentId,
  }) {
    return _db.deleteComment(activityId: activityId, commentId: commentId);
  }
}
