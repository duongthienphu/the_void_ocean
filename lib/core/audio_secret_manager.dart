import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class AudioSecretManager {
  // Biến Player có thể null để hủy và khởi tạo lại liên tục
  AudioPlayer? _audioPlayer;

  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  /// 1. TẠI SINH PLAYER: Hủy con cũ (nếu có) và tạo mới hoàn toàn
  Future<void> initAudio({
    required String url,
    required Function() onStateChanged,
  }) async {
    try {
      // BƯỚC 1: TỰ HỦY - Tiêu diệt player cũ cùng toàn bộ listener để làm sạch bộ nhớ
      await disposePlayer();

      // BƯỚC 2: TÁI SINH - Khởi tạo con Player mới tinh
      _audioPlayer = AudioPlayer();
      isPlaying = false;
      currentPosition = Duration.zero;
      totalDuration = Duration.zero;
      onStateChanged(); 

      // BƯỚC 3: Thiết lập nguồn phát và lắng nghe luồng mới
      String cleanedUrl = url.replaceAll('"', '').replaceAll('%22', '').trim();
      await _audioPlayer!.setSourceUrl(cleanedUrl);

      _stateSub = _audioPlayer!.onPlayerStateChanged.listen((state) {
        isPlaying = (state == PlayerState.playing);
        onStateChanged(); 
      });

      _positionSub = _audioPlayer!.onPositionChanged.listen((position) {
        currentPosition = position;
        onStateChanged();
      });

      _durationSub = _audioPlayer!.onDurationChanged.listen((duration) {
        totalDuration = duration;
        onStateChanged();
      });
    } catch (e) {
      print("Lỗi khởi tạo tái sinh AudioPlayer: $e");
    }
  }

  /// 2. Bật/tắt phát nhạc
  Future<void> togglePlay() async {
    if (_audioPlayer == null) return;
    if (isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.resume();
    }
  }

  /// 3. Tua nhạc
  Future<void> seek(Duration position) async {
    if (_audioPlayer == null) return;
    try {
      await _audioPlayer!.seek(position);
    } catch (e) {
      print("Lỗi tua nhạc: $e");
    }
  }

  /// 4. HÀM TỰ HỦY LỆNH VỚT: Hủy cứng player cũ ngay khi bấm vớt chai mới
  Future<void> disposePlayer() async {
    try {
      await _stateSub?.cancel();
      await _positionSub?.cancel();
      await _durationSub?.cancel();
      _stateSub = null;
      _positionSub = null;
      _durationSub = null;

      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }
      isPlaying = false;
      currentPosition = Duration.zero;
      totalDuration = Duration.zero;
    } catch (e) {
      print("Lỗi khi tiêu diệt AudioPlayer: $e");
    }
  }

  void dispose() {
    disposePlayer();
  }
}