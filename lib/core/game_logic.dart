import 'dart:math' as math;

enum SecretKind { text, audio }

class OceanSecret {
  OceanSecret({
    required this.body,
    required this.kind,
    required this.drift,
    required this.hearts,
    required this.palette,
    this.duration,
    this.isLiked = false,
    double? seed,
  }) : seed = seed ?? math.Random().nextDouble() * 100;

  final String body;
  final SecretKind kind;
  final String drift;
  final Duration? duration;
  final List<int> palette;
  final double seed;
  int hearts;
  bool isLiked;
}

List<OceanSecret> createInitialSecrets() {
  return [
    OceanSecret(
      body: 'Hôm nay mình thấy nhẹ hơn khi viết ra được điều này.',
      kind: SecretKind.text,
      drift: 'Vớt được gần đảo nhỏ',
      hearts: 18,
      palette: const [0xFF2DD4BF, 0xFFFF8A7A],
    ),
    OceanSecret(
      body: 'Mình không cần ai trả lời, chỉ muốn có một nơi được nói thật.',
      kind: SecretKind.text,
      drift: 'Đang trôi ở vùng biển khuya',
      hearts: 31,
      palette: const [0xFF60A5FA, 0xFFFBBF24],
    ),
    OceanSecret(
      body: 'Một đoạn audio ẩn danh',
      kind: SecretKind.audio,
      drift: 'Sóng mang từ phía đông',
      duration: const Duration(seconds: 42),
      hearts: 12,
      palette: const [0xFFA7F3D0, 0xFFFFB4A8],
    ),
  ];
}

String formatSecretDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  return '$minutes:$seconds';
}
