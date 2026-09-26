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

        return OceanSecret(
        id: data['id'],
        senderUid: data['senderUid'],
        body: data['body'] ?? '',
        kind: data['kind'] == 'audio' ? SecretKind.audio : SecretKind.text,
        drift: data['drift'] ?? 'Trôi vô định',
        hearts: (data['hearts'] as num?)?.toInt() ?? 0,
        isLiked: (data['likedUserIds'] as List<dynamic>?)?.contains(currentUserId) ?? false,
        palette: parsedPalette.isNotEmpty ? parsedPalette : const [0xFF60A5FA, 0xFFFBBF24],
        audioUrl: data['audioUrl'] as String?,
        duration: data['durationSeconds'] != null 
            ? Duration(seconds: (data['durationSeconds'] as num).toInt()) 
            : null,
        seed: (data['seed'] as num?)?.toDouble(),
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
      final List<dynamic> rawReplies = (data['replies'] as List<dynamic>?) ?? [];
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
}