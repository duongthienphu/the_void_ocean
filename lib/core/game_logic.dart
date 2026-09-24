import 'dart:math' as math;

enum SecretKind { text, audio }

const List<String> oceanDriftPool = [
  // Chủ đề: Địa danh, hòn đảo (Giống câu mẫu của bạn)
  'Vớt được gần đảo nhỏ',
  'Trôi dạt qua rặng san hô khuất',
  'Dạt vào bờ cát của Đảo Không Người',
  'Mắc kẹt giữa khe đá hải đăng',
  'Tìm thấy sát vách đá vọng âm',
  'Vớt được nơi eo biển lộng gió',
  'Trôi ngang qua bến cảng ngái ngủ',
  
  // Chủ đề: Thời gian và Không gian tâm trạng
  'Đang trôi ở vùng biển khuya',
  'Vớt được lúc thủy triều lên',
  'Bồng bềnh giữa làn sương ban sớm',
  'Nằm lặng im dưới ánh trăng tàn',
  'Trôi dạt qua vùng biển không tên',
  'Tìm thấy khi hoàng hôn buông xuống',
  
  // Chủ đề: Hướng gió và Dòng hải lưu
  'Sóng mang từ phía đông',
  'Theo dòng hải lưu ấm trôi về',
  'Bị cuốn đi bởi một trận gió chướng',
  'Nương theo cơn bão đêm qua',
  'Dòng nước ngầm đẩy tới từ phía nam',
  
  // Chủ đề: Trạng thái bí ẩn
  'Chìm sâu dưới tầng biển lặng',
  'Trôi vô định ngoài đại dương xa',
  'Vừa thoát khỏi một xoáy nước nhỏ',
  'Lấp ló sau những ngọn sóng bạc đầu',
];

class OceanSecret {
  OceanSecret({
    required this.id,
    required this.senderUid,
    required this.body,
    required this.kind,
    required this.drift,
    required this.hearts,
    required this.palette,
    this.duration,
    this.audioUrl,
    this.isLiked = false,
    double? seed,
  }) : seed = seed ?? math.Random().nextDouble() * 100;

  final String id;
  final String senderUid;
  final String body;
  final SecretKind kind;
  final String drift;
  final Duration? duration;
  final String? audioUrl;
  final List<int> palette;
  final double seed;
  int hearts;
  bool isLiked;
  factory OceanSecret.fromFirestore(Map<String, dynamic> data, String docId, {String? currentUserId}) {
    final List<dynamic> rawPalette = data['palette'] as List<dynamic>? ?? [0xFF5EEAD4, 0xFFFFA79A];
    final List<dynamic> likedUsers = data['likedUserIds'] as List<dynamic>? ?? [];

    return OceanSecret(
      id: docId,
      senderUid: data['senderUid'] ?? '',
      body: data['body'] ?? '',
      kind: data['kind'] == 'audio' ? SecretKind.audio : SecretKind.text,
      drift: data['drift'] ?? 'Vừa thả xuống dòng sâu',
      hearts: (data['hearts'] as num?)?.toInt() ?? 0,
      palette: rawPalette.map((e) => (e as num).toInt()).toList(),
      seed: (data['seed'] as num?)?.toDouble(),
      duration: data['durationSeconds'] != null 
          ? Duration(seconds: (data['durationSeconds'] as num).toInt()) 
          : null,
      audioUrl: data['audioUrl'] as String?,
      isLiked: currentUserId != null && likedUsers.contains(currentUserId),
    );
  }
}

List<OceanSecret> createInitialSecrets() {
  return [
  ];
}

String formatSecretDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  return '$minutes:$seconds';
}
