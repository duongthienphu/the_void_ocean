 import 'dart:math' as math;
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'game_logic.dart';

class CloudSecretService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<OceanSecret?> fishRandomSecret({required String currentUserId}) async {
    try {
      final double randomSeed = math.Random().nextDouble() * 100;
      var querySnapshot = await _firestore
          .collection('secrets')
          .where('senderUid', isNotEqualTo: currentUserId)
          .where('seed', isGreaterThanOrEqualTo: randomSeed)
          .orderBy('seed', descending: false)
          .limit(1) // Khống chế mỗi lần chỉ hiện đúng 1 thông điệp như Phú thống nhất
          .get();

      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _firestore
            .collection('secrets')
            .where('senderUid', isNotEqualTo: currentUserId)
            .where('seed', isLessThan: randomSeed)
            .orderBy('seed', descending: true)
            .limit(1)
            .get();
      }
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
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
          body: data['body'] ?? '', //
          kind: data['kind'] == 'audio' ? SecretKind.audio : SecretKind.text, //
          drift: data['drift'] ?? 'Trôi vô định', //
          hearts: (data['hearts'] as num?)?.toInt() ?? 0, //
          palette: parsedPalette.isNotEmpty ? parsedPalette : const [0xFF60A5FA, 0xFFFBBF24], //
          audioUrl: data['audioUrl'] as String?,
          duration: data['durationSeconds'] != null 
              ? Duration(seconds: (data['durationSeconds'] as num).toInt()) 
              : null, //
          seed: (data['seed'] as num?)?.toDouble(), //
        );
      }
      return null;
    } catch (e) {
      print('Lỗi thực thi thuật toán vớt chai: $e');
      return null;
    }
  }
}