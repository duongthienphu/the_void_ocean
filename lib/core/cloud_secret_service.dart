 import 'dart:math' as math;
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'game_logic.dart';

class CloudSecretService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<OceanSecret?> fishRandomSecret({required String currentUserId}) async {
    final userRef = _firestore.collection('users').doc(currentUserId);
    try {
      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        throw Exception('Không tìm thấy dữ liệu người dùng.');
      }
      final userData = userSnap.data() ?? {};
      final int currentCount = (userData['dailyFishedCount'] as num?)?.toInt() ?? 0;
      final Timestamp? lastDateTs = userData['lastFishedDate'] as Timestamp?;
      final DateTime? lastDate = lastDateTs?.toDate();

      final now = DateTime.now();
      final bool isSameDay = lastDate != null &&
          lastDate.year == now.year &&
          lastDate.month == now.month &&
          lastDate.day == now.day;

      if (isSameDay && currentCount >= 15) {
        throw Exception('Hôm nay bạn đã vớt đủ 15 thông điệp rồi, hãy quay lại vào ngày mai!');
      }
      final double randomSeed = math.Random().nextDouble() * 100;
      var querySnapshot = await _firestore
          .collection('secrets')
          .where('seed', isGreaterThanOrEqualTo: randomSeed)
          .orderBy('seed', descending: false)
          .limit(5) 
          .get();
      
      var eligibleDocs = querySnapshot.docs
          .where((d) => d.data()['senderUid'] != currentUserId)
          .toList();

      if (eligibleDocs.isEmpty) {
        querySnapshot = await _firestore
            .collection('secrets')
            .where('seed', isLessThan: randomSeed)
            .orderBy('seed', descending: true)
            .limit(5)
            .get();
            eligibleDocs = querySnapshot.docs
            .where((d) => d.data()['senderUid'] != currentUserId)
            .toList();
      }
      if (eligibleDocs.isEmpty) {
        return null; // Không có bài nào hợp lệ -> Không trừ lượt
      }
      final doc = eligibleDocs.first;
      final data = doc.data();

      await userRef.update({
        'dailyFishedCount': isSameDay ? (currentCount + 1) : 1,
        'lastFishedDate': FieldValue.serverTimestamp(),
      });
      final List<dynamic> rawPalette = data['palette'] ?? [];
      final List<int> parsedPalette = rawPalette.map((e) {
        if (e is String) {
          // Nếu lỡ tay nhập String dạng "4284402388" trên console thì chuyển về int
          return int.tryParse(e) ?? 0xFF60A5FA;
        }
        return (e as num).toInt();
      }).toList();

        return OceanSecret.fromFirestore(
        data,
        doc.id,
        currentUserId: currentUserId,
      );
    } catch (e) {
      rethrow;
    }
  }
  Future<void> toggleSecretLike({
    required String secretId,
    required String userId,
    required bool isLiked,
  }) async {
    final secretRef = _firestore.collection('secrets').doc(secretId);
    await secretRef.update({
      'hearts': FieldValue.increment(isLiked ? 1 : -1),
      'likedUserIds': isLiked
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }
  Future<void> sendComfortReply({
    required String secretId,
    required String senderUid,
    required String text,
  }) async {
    final docRef = _firestore.collection('secrets').doc(secretId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Chai thư đã trôi dạt mất khỏi vùng biển này.');
      }

      final data = snapshot.data() ?? {};
      final List<dynamic> rawReplies = List.from((data['replies'] as List<dynamic>?) ?? []);
      final int currentCount = (data['repliesCount'] as num?)?.toInt() ?? rawReplies.length;

      // 1. Kiểm tra giới hạn 3 mẩu giấy
      if (currentCount >= 3) {
        throw Exception('Chiếc chai này đã đầy ắp 3 mẩu giấy an ủi rồi.');
      }

      // 2. Kiểm tra xem người này đã từng gửi chưa
      final bool alreadyReplied = rawReplies.any(
        (item) => item is Map && item['senderUid'] == senderUid,
      );
      if (alreadyReplied) {
        throw Exception('Bạn đã gửi mẩu giấy an ủi vào chai này rồi.');
      }

      // 3. Đẩy mẩu giấy mới vào mảng và tăng biến đếm
      final newReply = {
        'senderUid': senderUid,
        'text': text,
        'createdAt': Timestamp.now(),
      };

      transaction.update(docRef, {
        'replies': FieldValue.arrayUnion([newReply]),
        'repliesCount': FieldValue.increment(1),
      });
    });
  }
  Future<void> deleteSecret({
    required String secretId,
    required String userId,
    required int sizeInBytes,
  }) async {
    final secretRef = _firestore.collection('secrets').doc(secretId);
    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final secretSnap = await transaction.get(secretRef);
      if (!secretSnap.exists) return;

      final userSnap = await transaction.get(userRef);
      if (userSnap.exists) {
        final currentAvailable = (userSnap.data()?['availableStorageBytes'] as num?)?.toInt() ?? 0;
        final currentPosts = (userSnap.data()?['postsCount'] as num?)?.toInt() ?? 1;

        transaction.update(userRef, {
          'availableStorageBytes': currentAvailable + sizeInBytes,
          'postsCount': math.max(0, currentPosts - 1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.delete(secretRef);
    });
  }
Future<void> removeReplyAsOwner({
    required String secretId,
    required String ownerUid,
    required int replyIndex,
  }) async {
    final docRef = _firestore.collection('secrets').doc(secretId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Chai thư đã trôi dạt mất khỏi vùng biển này.');
      }

      final data = snapshot.data() ?? {};
      if (data['senderUid'] != ownerUid) {
        throw Exception('Bạn không phải chủ sở hữu của chiếc chai này.');
      }

      final List<dynamic> rawReplies = List.from(data['replies'] as List<dynamic>? ?? []);
      if (replyIndex < 0 || replyIndex >= rawReplies.length) {
        throw Exception('Mẩu giấy này không còn tồn tại.');
      }

      // Xóa phần tử tại vị trí index
      rawReplies.removeAt(replyIndex);

      transaction.update(docRef, {
        'replies': rawReplies,
        'repliesCount': rawReplies.length,
      });
    });
  }
  Future<void> removeReplyAsSender({
    required String secretId,
    required String senderUid,
  }) async {
    final docRef = _firestore.collection('secrets').doc(secretId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Chai thư đã trôi dạt mất khỏi vùng biển này.');
      }

      final data = snapshot.data() ?? {};
      final List<dynamic> rawReplies = List.from(data['replies'] as List<dynamic>? ?? []);

      // Lọc bỏ mẩu giấy do chính user này gửi
      final updatedReplies = rawReplies.where((item) {
        if (item is Map) {
          return item['senderUid'] != senderUid;
        }
        return true;
      }).toList();

      if (updatedReplies.length == rawReplies.length) {
        throw Exception('Bạn chưa gửi mẩu giấy nào vào chiếc chai này.');
      }

      transaction.update(docRef, {
        'replies': updatedReplies,
        'repliesCount': updatedReplies.length,
      });
    });
  }
  Future<void> updateComfortReplyAsSender({
    required String secretId,
    required String senderUid,
    required String newText,
  }) async {
    final docRef = _firestore.collection('secrets').doc(secretId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Chai thư đã trôi dạt mất khỏi vùng biển này.');
      }

      final data = snapshot.data() ?? {};
      final List<dynamic> rawReplies = List.from(data['replies'] as List<dynamic>? ?? []);

      int targetIndex = -1;
      for (int i = 0; i < rawReplies.length; i++) {
        if (rawReplies[i] is Map && rawReplies[i]['senderUid'] == senderUid) {
          targetIndex = i;
          break;
        }
      }

      if (targetIndex == -1) {
        throw Exception('Không tìm thấy mẩu giấy của bạn để cập nhật.');
      }

      rawReplies[targetIndex] = {
        'senderUid': senderUid,
        'text': newText,
        'createdAt': Timestamp.now(),
      };

      transaction.update(docRef, {
        'replies': rawReplies,
      });
    });
  }
}