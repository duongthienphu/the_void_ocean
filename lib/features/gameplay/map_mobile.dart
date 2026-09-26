import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ocean/core/game_logic.dart';
import 'package:ocean/core/cloud_secret_service.dart';
import 'package:ocean/core/audio_secret_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ocean/models/app_user.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ocean/core/moderation_dialog.dart';
import 'package:ocean/core/ocean_snackbar.dart';

class OceanMobileScreen extends StatefulWidget {
  const OceanMobileScreen({super.key});
  @override
  State<OceanMobileScreen> createState() => _OceanMobileScreenState();
}

class _OceanMobileScreenState extends State<OceanMobileScreen>
    with SingleTickerProviderStateMixin {

  AppUser? _currentUser;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  final _textController = TextEditingController();
  final _bubbles = List.generate(24, (_) => _Bubble());
  late final AnimationController _oceanController;
  late final List<OceanSecret> _secrets;
  final CloudSecretService _cloudSecretService = CloudSecretService();
  final AudioSecretManager _globalAudioManager = AudioSecretManager();

  // Quản lý Tab hiện tại trên Mobile (0: Home/Vớt, 1: Gieo, 2: User)
  int _currentTab = 0;

  // Trạng thái UI cho luồng Vớt tâm sự
  OceanSecret? _currentFishedSecret;
  int get _fishedCountToday {
    if (_currentUser == null) return 0;
    final lastDate = _currentUser!.lastFishedDate.toDate();
    final now = DateTime.now();
    final bool isSameDay = lastDate.year == now.year &&
        lastDate.month == now.month &&
        lastDate.day == now.day;

    // Nếu khác ngày hôm nay -> Tự động tính là 0 lượt
    return isSameDay ? _currentUser!.dailyFishedCount : 0;
  }
  final int _maxFishPerDay = 30;

  SecretKind _draftKind = SecretKind.text;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _isRecording = false;
Timer? _cooldownTimer;
final ValueNotifier<int> _cooldownNotifier = ValueNotifier<int>(0);
  @override
  void initState() {
    super.initState();
    _secrets = createInitialSecrets();
    _oceanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null && mounted) {
          setState(() {
            _currentUser = AppUser.fromFirestore(snapshot.data()!, snapshot.id);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _recordingTimer?.cancel();
    _textController.dispose();
    _oceanController.dispose();
    _globalAudioManager.dispose();
    _cooldownTimer?.cancel();
    _cooldownNotifier.dispose();
    super.dispose();
  }

  void _showOceanSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
  showOceanSnackBar(context, message, isError: isError);
}

  void _startCooldown([int seconds = 30]) {
    _cooldownNotifier.value = seconds;

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownNotifier.value > 1) {
        _cooldownNotifier.value--;
      } else {
        timer.cancel();
        _cooldownNotifier.value = 0;
      }
    });
  }

  void _changeDraftKind(SecretKind kind) {
    if (kind == SecretKind.text) {
      _recordingTimer?.cancel();
      _recordingTimer = null;
    }
    setState(() {
      _draftKind = kind;
      if (kind == SecretKind.text) {
        _isRecording = false;
      }
    });
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording(keepDuration: true);
      return;
    }
    setState(() {
      _recordingSeconds = 0;
      _isRecording = true;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
    });
  }

  void _stopRecording({required bool keepDuration}) {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (mounted) {
      setState(() {
        _isRecording = false;
        if (!keepDuration) {
          _recordingSeconds = 0;
        }
      });
    }
  }

  Future<void> _throwSecret() async {
    if (_cooldownNotifier.value > 0) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentUser == null) {
      _showOceanSnackBar('Vui lòng đăng nhập lại để thả tâm sự.', isError: true);
      return;
    }

    // Xử lý riêng nhánh Text
    if (_draftKind == SecretKind.text) {
      final textContent = _textController.text.trim();
      final contentBytes = utf8.encode(textContent).length;

      // Kiểm tra dung lượng kho chứa
      if (_currentUser!.availableStorageBytes < contentBytes) {
        _showOceanSnackBar('Kho chứa đại dương của bạn đã đầy!', isError: true);
        return;
      }
      _startCooldown(30);

      // Hiển thị vòng xoay chờ xử lý
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
        ),
      );

      try {
        final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable('moderateContent');

        final result = await callable.call({'text': textContent});
        final bool isValid = result.data['isValid'] == true;
        final String category = result.data['category'] ?? 'none';
        final String reason = result.data['reason'] ?? '';

        // Nếu nội dung vi phạm tiêu chuẩn cộng đồng -> Chặn ngay
        if (!isValid) {
          if (mounted) Navigator.of(context).pop(); // Tắt vòng xoay loading
          if (mounted) {
            await showModerationAlert(
              context: context,
              category: category,
              reason: reason,
            );
          }
          return; // Dừng lại hoàn toàn, không lưu vào Firestore
        }
        final firestore = FirebaseFirestore.instance;
        final userRef = firestore.collection('users').doc(user.uid);
        final newSecretRef = firestore.collection('secrets').doc();

        // Transaction đồng thời ghi document mới và cập nhật user
        await firestore.runTransaction((transaction) async {
          final userSnapshot = await transaction.get(userRef);
          if (!userSnapshot.exists) {
            throw Exception('Không tìm thấy tài khoản cư dân.');
          }

          final currentAvailable = (userSnapshot.data()?['availableStorageBytes'] as num?)?.toInt() ?? 0;
          final currentPosts = (userSnapshot.data()?['postsCount'] as num?)?.toInt() ?? 0;

          if (currentAvailable < contentBytes) {
            throw Exception('Dung lượng không đủ để gieo thêm tâm sự.');
          }

          final randomDrift = getRandomDrift();
          final randomPalette = getRandomPalette();
          // 1. Tạo document mới trong collection 'secrets'
          transaction.set(newSecretRef, {
            'id': newSecretRef.id,
            'senderUid': user.uid,
            'kind': 'text',
            'body': textContent,
            'audioUrl': null,
            'durationSeconds': 0,
            'sizeInBytes': contentBytes,
            'hearts': 0,
            'likedUserIds': [],
            'palette': randomPalette,
            'seed': math.Random().nextDouble() * 100,
            'drift': randomDrift,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 2. Trừ dung lượng và tăng postsCount ở document 'users'
          transaction.update(userRef, {
            'availableStorageBytes': currentAvailable - contentBytes,
            'postsCount': currentPosts + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

        if (mounted) Navigator.of(context).pop(); // Tắt loading

        // Đưa vào danh sách xem lại tạm thời trên UI và xóa ô nhập
        final localSecret = OceanSecret(
          id: newSecretRef.id,
          senderUid: user.uid,
          body: textContent,
          kind: SecretKind.text,
          drift: 'Vừa thả xuống dòng sâu di động',
          hearts: 0,
          palette: const [0xFF5EEAD4, 0xFFFFA79A],
        );

        setState(() {
          _secrets.insert(0, localSecret);
        });
        _textController.clear();

        if (mounted) {
          _showOceanSnackBar('Đã thả tâm sự vào đại dương (-$contentBytes bytes).');
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        _showOceanSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
      return;
    }

    // Nhánh Audio giữ nguyên logic cũ
    final secret = OceanSecret(
      id: '001',
      senderUid: user.uid,
      body: 'Một đoạn audio ẩn danh mới gieo',
      kind: SecretKind.audio,
      drift: 'Vừa trôi khỏi mạn thuyền',
      duration: Duration(seconds: _recordingSeconds),
      hearts: 0,
      palette: const [0xFFFBBF24, 0xFFA7F3D0],
    );

    _recordingTimer?.cancel();
    _recordingTimer = null;

    setState(() {
      _secrets.insert(0, secret);
      _isRecording = false;
      _recordingSeconds = 0;
    });
    _showOceanSnackBar('Đã thả audio vào đại dương.');
  }

  Future<void> _toggleHeart(OceanSecret secret) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showOceanSnackBar('Vui lòng đăng nhập để gửi tim.', isError: true);
      return;
    }

    // 1. Cập nhật UI ngay lập tức
    setState(() {
      secret.isLiked = !secret.isLiked;
      secret.hearts += secret.isLiked ? 1 : -1;
    });

    // 2. Đồng bộ Firestore chạy nền
    try {
      await _cloudSecretService.toggleSecretLike(
        secretId: secret.id,
        userId: user.uid,
        isLiked: secret.isLiked,
      );
    } catch (_) {
      // Revert lại nếu có lỗi mạng
      if (mounted) {
        setState(() {
          secret.isLiked = !secret.isLiked;
          secret.hearts += secret.isLiked ? 1 : -1;
        });
        _showOceanSnackBar('Không thể gửi tim, vui lòng thử lại.', isError: true);
      }
    }
  }

  // Logic UI xử lý vớt ngẫu nhiên 1 tâm sự (Tối đa 15 lần/ngày)
  Future<void> _fishRandomSecret() async {
    await _globalAudioManager.disposePlayer();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showOceanSnackBar('Vui lòng đăng nhập để vớt tâm sự.', isError: true);
      return;
    }

    await _globalAudioManager.disposePlayer();
    final String currentUserId = user.uid;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
      ),
    );
    try {
      // 3. Gọi hàm thuật toán vớt chai từ CloudSecretService về
      final OceanSecret? fishedSecret = await _cloudSecretService.fishRandomSecret(
        currentUserId: currentUserId,
      );

      // Tắt Loading sau khi Firestore phản hồi xong dữ liệu
      if (mounted) Navigator.of(context).pop();

      // 4. Xử lý kết quả trả về để đưa ra giao diện công khai
      if (fishedSecret == null) {
        if (mounted) {
          _showOceanSnackBar('Đại dương hôm nay lặng sóng, không vớt được chai nào của người lạ rồi!');
        }
      } else {
        // Vớt thành công -> Cập nhật Object vào UI để widget _SecretBottleCard tự động vẽ
        setState(() {
          _currentFishedSecret = fishedSecret;
        });
      }
    } catch (e) {
      // Tắt Loading nếu lỡ xảy ra lỗi hệ thống hoặc chạm ngưỡng 15 lượt
      if (mounted) Navigator.of(context).pop();
      _showOceanSnackBar(
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Nền biển động chạy 60 FPS được cô lập hoàn toàn ở đây
          _AnimatedOcean(
            controller: _oceanController,
            bubbles: _bubbles,
          ),

          // 2. Nội dung UI tĩnh nằm đè lên trên, KHÔNG BỊ BUILD LẠI theo nhịp sóng
          SafeArea(
            child: Column(
              children: [
                const _MobileTopBar(),
                Expanded(
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      _OceanHomeTab(
                        currentUser: _currentUser,
                        fishedCountToday: _fishedCountToday,
                        maxFishPerDay: _maxFishPerDay,
                        currentFishedSecret: _currentFishedSecret,
                        oceanController: _oceanController,
                        audioManager: _globalAudioManager,
                        onFish: _fishRandomSecret,
                        onToggleHeart: () {
                          if (_currentFishedSecret != null) {
                            _toggleHeart(_currentFishedSecret!);
                          }
                        },
                      ),
                      _OceanGieoTab(
                        currentUser: _currentUser,
                        secrets: _secrets,
                        oceanController: _oceanController,
                        audioManager: _globalAudioManager,
                        textController: _textController,
                        draftKind: _draftKind,
                        recordingSeconds: _recordingSeconds,
                        isRecording: _isRecording,
                        cooldownNotifier: _cooldownNotifier,
                        onKindChanged: _changeDraftKind,
                        onToggleRecording: _toggleRecording,
                        onThrow: _throwSecret,
                        onToggleHeart: _toggleHeart,
                      ),
                      _OceanUserTab(currentUser: _currentUser),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        backgroundColor: const Color(0xFF071820).withValues(alpha: 0.96),
        selectedItemColor: const Color(0xFF5EEAD4),
        unselectedItemColor: Colors.white38,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sailing_outlined),
            activeIcon: Icon(Icons.sailing),
            label: 'Vớt tâm sự',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.blur_on),
            activeIcon: Icon(Icons.blur_circular),
            label: 'Gieo tâm sự',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.face_outlined),
            activeIcon: Icon(Icons.face),
            label: 'Cư dân',
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// TAB 0: HOME / VỚT TÂM SỰ
// =====================================================================
class _OceanHomeTab extends StatelessWidget {
  final int fishedCountToday;
  final int maxFishPerDay;
  final OceanSecret? currentFishedSecret;
  final AnimationController oceanController;
  final AudioSecretManager audioManager;
  final VoidCallback onFish;
  final VoidCallback onToggleHeart;
  final AppUser? currentUser;

  const _OceanHomeTab({
    required this.fishedCountToday,
    required this.maxFishPerDay,
    required this.currentFishedSecret,
    required this.oceanController,
    required this.audioManager,
    required this.onFish,
    required this.onToggleHeart,
    required this.currentUser
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bubble_chart_outlined, size: 14, color: Color(0xFF5EEAD4)),
                    const SizedBox(width: 6),
                    Text(
                      'Hôm nay: $fishedCountToday/$maxFishPerDay lần vớt',
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Expanded(
            flex: 4,
            child: Center(
              child: currentFishedSecret == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.all_inclusive,
                          size: 64,
                          color: const Color(0xFF2DD4BF).withValues(alpha: 0.22),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Mặt nước lặng tờ... Hãy thử vớt một điều ước.',
                          style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'CHAI THỦY TINH VỪA VỚT:',
                              style: TextStyle(color: Color(0xFF5EEAD4), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                            ),
                          ),
                          _SecretBottleCard(
                            key: ValueKey(currentFishedSecret!.id),
                            secret: currentFishedSecret!,
                            controller: oceanController,
                            audioManager: audioManager,
                            onHeart: onToggleHeart,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onFish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5EEAD4),
                foregroundColor: const Color(0xFF06211D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.anchor),
              label: const Text('Vớt 1 tâm sự ngẫu nhiên', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// =====================================================================
// TAB 1: GIEO TÂM SỰ
// =====================================================================
class _OceanGieoTab extends StatelessWidget {
  final AppUser? currentUser;
  final List<OceanSecret> secrets;
  final AnimationController oceanController;
  final AudioSecretManager audioManager;
  final TextEditingController textController;
  final SecretKind draftKind;
  final int recordingSeconds;
  final bool isRecording;
  final ValueChanged<SecretKind> onKindChanged;
  final VoidCallback onToggleRecording;
  final VoidCallback onThrow;
  final void Function(OceanSecret) onToggleHeart;
final ValueNotifier<int> cooldownNotifier;

  const _OceanGieoTab({
    this.currentUser,
    required this.secrets,
    required this.oceanController,
    required this.audioManager,
    required this.textController,
    required this.draftKind,
    required this.recordingSeconds,
    required this.isRecording,
    required this.onKindChanged,
    required this.onToggleRecording,
    required this.onThrow,
    required this.onToggleHeart,
    required this.cooldownNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final double maxStorageBytes = (currentUser?.maxStorageBytes ?? 20971520).toDouble();
    final double availableStorageBytes = (currentUser?.availableStorageBytes ?? 20971520).toDouble();
    final double usedStorageBytes = (maxStorageBytes - availableStorageBytes).clamp(0.0, maxStorageBytes);
    final double usagePercent = maxStorageBytes > 0 ? (usedStorageBytes / maxStorageBytes) : 0.0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF071820).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kho chứa đại dương', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF99F6E4))),
                  Text(
                    'Tối đa: ${maxStorageBytes.toInt()} B',
                    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: usagePercent,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  color: const Color(0xFFFFA79A),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Đã lưu: ${usedStorageBytes.toInt()} B', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  Text('Còn trống: ${availableStorageBytes.toInt()} B', style: const TextStyle(color: Color(0xFFFFA79A), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: currentUser == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF5EEAD4)))
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('secrets')
                      .where('senderUid', isEqualTo: currentUser!.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Bạn chưa gieo tâm sự nào xuống biển...',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final secret = OceanSecret.fromFirestore(
                          docs[index].data(),
                          docs[index].id,
                          currentUserId: currentUser!.uid,
                        );

                        return _SecretBottleCard(
                          key: ValueKey(secret.id),
                          secret: secret,
                          controller: oceanController,
                          audioManager: audioManager,
                          onHeart: () => onToggleHeart(secret),
                        );
                      },
                    );
                  },
                ),
        ),
        _MobileComposer(
          draftKind: draftKind,
          textController: textController,
          recordingSeconds: recordingSeconds,
          isRecording: isRecording,
          cooldownNotifier: cooldownNotifier,
          onKindChanged: onKindChanged,
          onToggleRecording: onToggleRecording,
          onThrow: onThrow,
        ),
      ],
    );
  }
}

// =====================================================================
// TAB 2: CƯ DÂN 
// =====================================================================
class _OceanUserTab extends StatelessWidget {
  final AppUser? currentUser;

  const _OceanUserTab({this.currentUser});

  // 1. Đổi mật khẩu qua Gmail
  void _handleResetPassword(BuildContext context, String? email) {
    if (email == null || email.isEmpty) {
      showOceanSnackBar(context, 'Không tìm thấy địa chỉ email của bạn.', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF071820),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Đổi mật mã truy cập', style: TextStyle(color: Color(0xFF5EEAD4), fontWeight: FontWeight.bold)),
        content: Text(
          'Nhân viên cá sẽ gửi liên kết đặt lại mật khẩu đến:\n$email\n\nBạn có muốn tiếp tục?',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (context.mounted) {
                  showOceanSnackBar(context, 'Nhân viên cá đã gửi thư đặt lại mật khẩu tới $email');
                }
              } catch (e) {
                if (context.mounted) {
                  showOceanSnackBar(context, e.toString().replaceAll('Exception: ', ''), isError: true);
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5EEAD4),
              foregroundColor: const Color(0xFF06211D),
            ),
            child: const Text('Gửi liên kết', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 2. Đổi Email (Cần xác thực mật khẩu hiện tại)
  void _handleChangeEmail(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF071820),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Thay đổi Email cư dân', style: TextStyle(color: Color(0xFF5EEAD4), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập email mới và mật khẩu hiện tại để xác nhận đổi thông tin:',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: newEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Email mới',
                prefixIcon: Icon(Icons.mail_outline, color: Color(0xFF5EEAD4), size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Mật khẩu hiện tại',
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF5EEAD4), size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            onPressed: () async {
              final newEmail = newEmailController.text.trim();
              final password = passwordController.text.trim();

              if (newEmail.isEmpty || password.isEmpty) {
                showOceanSnackBar(context, 'Vui lòng điền đủ email mới và mật khẩu.', isError: true);
                return;
              }

              Navigator.of(ctx).pop();

              try {
                // Re-authenticate
                final cred = EmailAuthProvider.credential(email: user.email!, password: password);
                await user.reauthenticateWithCredential(cred);

                // Gửi xác thực đổi email
                await user.verifyBeforeUpdateEmail(newEmail);

                // Cập nhật trường email trong document users
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'email': newEmail,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  showOceanSnackBar(context, 'Nhân viên cá đã gửi liên kết xác nhận tới $newEmail. Vui lòng kiểm tra hộp thư.');
                }
              } catch (e) {
                if (context.mounted) {
                  showOceanSnackBar(context, e.toString().replaceAll('Exception: ', ''), isError: true);
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5EEAD4),
              foregroundColor: const Color(0xFF06211D),
            ),
            child: const Text('Cập nhật', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 3. Đăng xuất
  void _handleSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF071820),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Rời khỏi đại dương?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bạn sẽ cần đăng nhập lại vào lần truy cập tiếp theo.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ở lại', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FirebaseAuth.instance.signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFA79A),
              foregroundColor: const Color(0xFF2B0B08),
            ),
            child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 4. Xóa vĩnh viễn tài khoản (Xác thực mật khẩu + Xóa Firestore + Xóa Auth)
  void _handleDeleteAccount(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF160A08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        title: const Text('Xác nhận xóa tài khoản', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hành động này sẽ xóa vĩnh viễn tài khoản, dữ liệu kho chứa và nhấn chìm toàn bộ tâm sự của bạn xuống đáy biển sâu không thể khôi phục.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Nhập mật khẩu hiện tại để xóa',
                prefixIcon: Icon(Icons.key, color: Color(0xFFFFA79A), size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy bỏ', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                showOceanSnackBar(context, 'Vui lòng nhập mật khẩu xác nhận.', isError: true);
                return;
              }

              Navigator.of(ctx).pop();

              try {
                // Bước 1: Re-authenticate
                final cred = EmailAuthProvider.credential(email: user.email!, password: password);
                await user.reauthenticateWithCredential(cred);
                final firestore = FirebaseFirestore.instance;

                // Bước 2: Dọn dẹp bài viết
                final secretsSnapshot = await firestore
                    .collection('secrets')
                    .where('senderUid', isEqualTo: user.uid)
                    .get();
                final batch = firestore.batch();
                for (final doc in secretsSnapshot.docs) {
                  batch.delete(doc.reference);
                }

                // Bước 3: Dọn dẹp tài liệu user trên Firestore
                final userDocRef = firestore.collection('users').doc(user.uid);
                batch.delete(userDocRef);
                await batch.commit();

                // Bước 4: Xóa vĩnh viễn user khỏi Firebase Auth
                await user.delete();

                if (context.mounted) {
                  showOceanSnackBar(context, 'Tài khoản của bạn đã được xóa hoàn toàn. Chúc bạn luôn hạnh phúc!');
                }
              } catch (e) {
                if (context.mounted) {
                  showOceanSnackBar(context, e.toString().replaceAll('Exception: ', ''), isError: true);
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa vĩnh viễn', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String userEmail = user?.email ?? 'Chưa xác thực email';
    final int postsCount = currentUser?.postsCount ?? 0;
    final double maxBytes = (currentUser?.maxStorageBytes ?? 20971520).toDouble();
    final double availableBytes = (currentUser?.availableStorageBytes ?? 20971520).toDouble();
    final double usedB = ((maxBytes - availableBytes)).clamp(0.0, maxBytes / 1024);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thẻ hồ sơ
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF071820).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5EEAD4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF5EEAD4).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF5EEAD4), size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cư dân ẩn danh', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 3),
                          Text(
                            userEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('Tâm sự đã gieo', '$postsCount bài', const Color(0xFF5EEAD4)),
                      Container(width: 1, height: 26, color: Colors.white12),
                      _buildMiniStat('Dung lượng dùng', '${usedB.toStringAsFixed(1)} B', const Color(0xFFFFA79A)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Tài khoản & Bảo mật
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'TÀI KHOẢN VÀ BẢO MẬT',
              style: TextStyle(color: Color(0xFF99F6E4), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF071820).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFF5EEAD4), size: 22),
                  title: const Text('Thay đổi mật khẩu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Gửi email đặt lại mã khóa bí mật', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
                  onTap: () => _handleResetPassword(context, user?.email),
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF5EEAD4), size: 22),
                  title: const Text('Thay đổi email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Cập nhật hòm thư liên lạc mới', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
                  onTap: () => _handleChangeEmail(context),
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFFFA79A), size: 22),
                  title: const Text('Đăng xuất tài khoản', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFFFA79A))),
                  subtitle: const Text('Tạm ngưng kết nối với làn sóng biển', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
                  onTap: () => _handleSignOut(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Khu vực nguy hiểm
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF160A08).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                    SizedBox(width: 8),
                    Text('Khu vực nguy hiểm', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Khi xóa tài khoản, tất cả tâm sự trôi dạt và dung lượng kho chứa sẽ bị nhấn chìm vĩnh viễn dưới đáy biển.',
                  style: TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleDeleteAccount(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFA79A),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 0.8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: const Text('Xóa tài khoản vĩnh viễn', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// CÁC CLASS HELPER BÊN DƯỚI ĐÃ ĐƯỢC ĐẨY RA NGOÀI NGANG HÀNG CLASS CHÍNH
// ---------------------------------------------------------------------

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF071820).withValues(alpha: 0.92), // Nền xanh đen nổi bật
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF5EEAD4).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(
              Icons.water_drop_outlined,
              color: Color(0xFF99F6E4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đại dương',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'và những chú cá con',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const HologramText('Made by Duong Thien Phu'),
        ],
      ),
    );
  }
}

class _MobileComposer extends StatelessWidget {
  const _MobileComposer({
    required this.draftKind,
    required this.textController,
    required this.recordingSeconds,
    required this.isRecording,
    required this.onKindChanged,
    required this.onToggleRecording,
    required this.onThrow,
    required this.cooldownNotifier,
  });

  final SecretKind draftKind;
  final TextEditingController textController;
  final int recordingSeconds;
  final bool isRecording;
  final ValueChanged<SecretKind> onKindChanged;
  final VoidCallback onToggleRecording;
  final VoidCallback onThrow;
  final ValueNotifier<int> cooldownNotifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF071820).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _DraftKindButton(
                label: 'Text',
                icon: Icons.notes_outlined,
                selected: draftKind == SecretKind.text,
                onTap: () => onKindChanged(SecretKind.text),
              ),
              const SizedBox(width: 8),
              _DraftKindButton(
                label: 'Audio',
                icon: Icons.mic_none,
                selected: false,
                isDisabled: true,
                onTap: () {
                  showOceanSnackBar(
                    context,
                    'Tính năng gieo tâm sự bằng giọng nói đang được hoàn thiện.',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 1. Ô NHẬP TEXT GIỮ NGUYÊN UI & GIỚI HẠN 5000 KÝ TỰ
          if (draftKind == SecretKind.text)
            TextField(
              controller: textController,
              maxLength: 5000,
              minLines: 2,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              enableSuggestions: true,
              autocorrect: false,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
              decoration: const InputDecoration(
                hintText: 'Viết điều bạn muốn gửi xuống biển...',
                prefixIcon: Icon(Icons.edit_note, color: Color(0xFF99F6E4)),
                counterStyle: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            _AudioDraft(
              recordingSeconds: recordingSeconds,
              isRecording: isRecording,
              onToggleRecording: onToggleRecording,
            ),
          const SizedBox(height: 12),

          // 2. NÚT BẤM DÙNG ValueListenableBuilder TỰ ĐỘNG BẬT KHI CÓ CHỮ HOẶC CÓ AUDIO
          ValueListenableBuilder<int>(
            valueListenable: cooldownNotifier,
            builder: (context, secondsRemaining, _) {
              final bool isCoolingDown = secondsRemaining > 0;

              if (draftKind == SecretKind.text) {
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: textController,
                  builder: (context, value, _) {
                    final bool hasText = value.text.trim().isNotEmpty;
                    return _buildSubmitButton(
                      canSubmit: hasText && !isCoolingDown,
                      isCoolingDown: isCoolingDown,
                      secondsRemaining: secondsRemaining,
                    );
                  },
                );
              } else {
                return _buildSubmitButton(
                  canSubmit: recordingSeconds > 0 && !isCoolingDown,
                  isCoolingDown: isCoolingDown,
                  secondsRemaining: secondsRemaining,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Hàm dựng giao diện nút bấm dùng chung
  Widget _buildSubmitButton({
    required bool canSubmit,
    required bool isCoolingDown,
    required int secondsRemaining,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: canSubmit ? onThrow : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF5EEAD4),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
          foregroundColor: const Color(0xFF06211D),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: Icon(
          isCoolingDown ? Icons.hourglass_top_rounded : Icons.send_rounded,
          size: 18,
        ),
        label: Text(
          isCoolingDown
              ? 'Cá kiểm duyệt đang nghỉ ngơi, còn (${secondsRemaining}s)...'
              : 'Thả xuống đại dương',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _DraftKindButton extends StatelessWidget {
  const _DraftKindButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.isDisabled = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? const Color(0xFF99F6E4) : Colors.white54,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioDraft extends StatelessWidget {
  const _AudioDraft({
    required this.recordingSeconds,
    required this.isRecording,
    required this.onToggleRecording,
  });

  final int recordingSeconds;
  final bool isRecording;
  final VoidCallback onToggleRecording;

  @override
  Widget build(BuildContext context) {
    final duration = formatSecretDuration(Duration(seconds: recordingSeconds));

    return Container(
      height: 96,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: isRecording ? 'Dừng ghi' : 'Ghi audio',
            onPressed: onToggleRecording,
            style: IconButton.styleFrom(
              backgroundColor: isRecording
                  ? const Color(0xFFFFA79A)
                  : const Color(0xFF5EEAD4),
              foregroundColor: isRecording
                  ? const Color(0xFF2B0B08)
                  : const Color(0xFF06211D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(isRecording ? Icons.stop_rounded : Icons.mic_none),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isRecording ? 'Đang ghi âm' : 'Audio ẩn danh',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                _Waveform(active: recordingSeconds > 0 || isRecording),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            duration,
            style: const TextStyle(
              color: Color(0xFF99F6E4),
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecretBottleCard extends StatelessWidget {
  const _SecretBottleCard({
    super.key,
    required this.secret,
    required this.controller,
    required this.audioManager,
    required this.onHeart,
  });

  final OceanSecret secret;
  final AnimationController controller;
  final AudioSecretManager audioManager;
  final VoidCallback onHeart;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final float =
            math.sin((controller.value * math.pi * 2) + secret.seed) * 5;
        return Transform.translate(offset: Offset(0, float), child: child);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF071820).withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Color(secret.palette.first).withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Color(secret.palette.first).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    secret.kind == SecretKind.audio
                        ? Icons.graphic_eq
                        : Icons.bubble_chart_outlined,
                    color: Color(secret.palette.first),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: secret.kind == SecretKind.audio
                      ? _AudioSecret(secret: secret, audioManager: audioManager)
                      : _TextSecret(secret: secret),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (secret.senderUid != FirebaseAuth.instance.currentUser?.uid)
                  Expanded(
                    child: Text(
                      secret.drift,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                _ReplyLetterButton(
                  secret: secret,
                  onTap: () {
                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    if (secret.senderUid == currentUid) {
                      showDialog(
                        context: context,
                        builder: (_) => _OwnerRepliesDialog(
                          secret: secret,
                          onRepliesUpdated: () {
                            if (context.mounted) {
                              (context as Element).markNeedsBuild();
                            }
                          },
                        ),
                      );
                      return;
                    }

                    if (secret.hasReplied) {
                      final myReply = secret.replies.cast<Map<String, dynamic>?>().firstWhere(
                        (r) => r?['senderUid'] == currentUid,
                        orElse: () => null,
                      );
                      final String existingText = (myReply?['text'] as String?) ?? '';

                      showDialog(
                        context: context,
                        builder: (_) => _ComfortLetterDialog(
                          secretId: secret.id,
                          initialText: existingText,
                          onReplied: () {
                            if (myReply != null) {
                              // Cập nhật lại trong mảng local
                              myReply['text'] = existingText;
                            }
                            if (context.mounted) {
                              (context as Element).markNeedsBuild();
                            }
                          },
                          onDeleted: () {
                            secret.repliesCount = math.max(0, secret.repliesCount - 1);
                            secret.hasReplied = false;
                            secret.replies.removeWhere((r) => r is Map && r['senderUid'] == currentUid);
                            if (context.mounted) {
                              (context as Element).markNeedsBuild();
                            }
                          },
                        ),
                      );
                      return;
                    }

                    if (secret.repliesCount >= 3) {
                      showOceanSnackBar(
                        context,
                        'Chiếc chai này đã đầy ắp 3 mẩu giấy an ủi rồi!',
                      );
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (_) => _ComfortLetterDialog(
                        secretId: secret.id,
                        onReplied: () {
                          secret.repliesCount++;
                          secret.hasReplied = true;
                          if (context.mounted) {
                            (context as Element).markNeedsBuild();
                          }
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _HeartButton(secret: secret, onTap: onHeart),
                if (secret.senderUid == FirebaseAuth.instance.currentUser?.uid) ...[
                  const SizedBox(width: 8),
                  _DeletePostButton(secret: secret),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TextSecret extends StatelessWidget {
  const _TextSecret({required this.secret});

  final OceanSecret secret;

  @override
  Widget build(BuildContext context) {
    return Text(
      secret.body,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: const Color(0xFFEAF6F4),
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AudioSecret extends StatefulWidget {
  const _AudioSecret({required this.secret, required this.audioManager}); 
  final OceanSecret secret;
  final AudioSecretManager audioManager;

  @override
  State<_AudioSecret> createState() => _AudioSecretState();
}

class _AudioSecretState extends State<_AudioSecret> {

  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(Duration.zero);
  bool _disposed = false;

 @override
  void initState() {
    super.initState();
    _initAudioForCard();
  }

  @override
  void didUpdateWidget(_AudioSecret oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initAudioForCard();
  }

  void _initAudioForCard() {
    _positionNotifier.value = Duration.zero;
    _durationNotifier.value = Duration.zero;
    if (widget.secret.audioUrl != null) {
      // Gọi kết nối trực tiếp vào manager tập trung ở tầng cha truyền xuống
      widget.audioManager.initAudio(
        url: widget.secret.audioUrl!,
        onStateChanged: () {
          if (_disposed || !mounted) return;

          _positionNotifier.value = widget.audioManager.currentPosition;
          if (widget.audioManager.totalDuration != Duration.zero) {
            _durationNotifier.value = widget.audioManager.totalDuration;
          }
          
          setState(() {});
        },
      );
    }
  }

  @override
  void dispose() {
    // Đánh dấu đã dispose TRƯỚC TIÊN để chặn callback đến trễ
    _disposed = true;
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chữ nội dung đi kèm audio
        Text(
          widget.secret.body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFEAF6F4),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10), // Hộp trống tạo khoảng cách 10 pixel
        
        // BỘ LIÊN KẾT ĐIỀU KHIỂN ÂM THANH REALTIME
        Row(
          children: [
            // Nút bấm Play/Pause đổi icon động theo trạng thái của Manager
            IconButton(
              icon: Icon(
                widget.audioManager.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_arrow_rounded,
                color: const Color(0xFFFFA79A),
                size: 28,
              ), 
              onPressed: () => widget.audioManager.togglePlay(),
            ),
            
            // Thanh Slider cô lập tuyệt đối bằng ValueListenableBuilder chống kẹt lệnh
            Expanded(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _durationNotifier,
                builder: (context, totalDuration, _) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: _positionNotifier,
                    builder: (context, currentPosition, _) {
                      final double maxVal = totalDuration.inMilliseconds.toDouble() > 0
                          ? totalDuration.inMilliseconds.toDouble()
                          : (widget.secret.duration?.inMilliseconds.toDouble() ?? 1000.0);
                          
                      double currentVal = currentPosition.inMilliseconds.toDouble();
                      if (currentVal > maxVal) currentVal = maxVal;

                      return Slider(
                        activeColor: const Color(0xFF99F6E4),
                        inactiveColor: Colors.white10,
                        min: 0.0,
                        max: maxVal,
                        value: currentVal,
                        onChanged: (double value) {
                          widget.audioManager.seek(Duration(milliseconds: value.toInt()));
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            
            // Đồng hồ đếm thời gian thực dạng chữ (00:00)
            ValueListenableBuilder<Duration>(
              valueListenable: _positionNotifier,
              builder: (context, currentPosition, _) {
                final Duration displayDuration = widget.audioManager.isPlaying 
                    ? currentPosition 
                    : (widget.secret.duration ?? Duration.zero);

                return Text(
                  formatSecretDuration(displayDuration),
                  style: const TextStyle(
                    color: Color(0xFF99F6E4),
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w900,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.secret, required this.onTap});

  final OceanSecret secret;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: secret.isLiked
          ? const Color(0xFFFFA79A).withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                secret.isLiked ? Icons.favorite : Icons.favorite_border,
                size: 17,
                color: secret.isLiked
                    ? const Color(0xFFFFA79A)
                    : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                '${secret.hearts}',
                style: TextStyle(
                  color: secret.isLiked
                      ? const Color(0xFFFFC1B8)
                      : Colors.white60,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyLetterButton extends StatelessWidget {
  const _ReplyLetterButton({
    required this.secret,
    required this.onTap,
  });

  final OceanSecret secret;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int count = secret.repliesCount;
    final bool isFull = count >= 3;
    final bool hasReplied = secret.hasReplied;

    final Color tintColor = hasReplied
        ? const Color(0xFFFFA79A)
        : (isFull ? const Color(0xFFFBBF24) : const Color(0xFF99F6E4));

    final IconData iconData = hasReplied
        ? Icons.mark_email_read_rounded
        : (isFull ? Icons.mark_email_read_outlined : Icons.mail_outline_rounded);

    return Material(
      color: hasReplied 
          ? const Color(0xFFFFA79A).withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconData,
                size: 17,
                color: tintColor,
              ),
              const SizedBox(width: 6),
              Text(
                '$count/3',
                style: TextStyle(
                  color: tintColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComfortLetterDialog extends StatefulWidget {
  const _ComfortLetterDialog({
    super.key,
    required this.secretId,
    this.initialText,
    required this.onReplied,
    this.onDeleted,
  });

  final String secretId;
  final String? initialText;
  final VoidCallback onReplied;
  final VoidCallback? onDeleted;

  @override
  State<_ComfortLetterDialog> createState() => _ComfortLetterDialogState();
}

class _ComfortLetterDialogState extends State<_ComfortLetterDialog> {
  late final TextEditingController _replyController;
  final CloudSecretService _cloudSecretService = CloudSecretService();
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isEditing => widget.initialText != null;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    if (_isEditing && text == widget.initialText?.trim()) {
      Navigator.of(context).pop();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showOceanSnackBar(context, 'Vui lòng đăng nhập lại.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Kiểm duyệt AI với mode 'reply'
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('moderateContent');

      final result = await callable.call({
        'text': text,
        'mode': 'reply',
      });

      final bool isValid = result.data['isValid'] == true;
      final String category = result.data['category'] ?? 'none';
      final String reason = result.data['reason'] ?? '';

      if (!isValid) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          await showModerationAlert(
            context: context,
            category: category,
            reason: reason,
          );
        }
        return;
      }

      if (_isEditing) {
        await _cloudSecretService.updateComfortReplyAsSender(
          secretId: widget.secretId,
          senderUid: user.uid,
          newText: text,
        );
      } else {
        await _cloudSecretService.sendComfortReply(
          secretId: widget.secretId,
          senderUid: user.uid,
          text: text,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onReplied();
        showOceanSnackBar(
          context,
          _isEditing ? 'Đã cập nhật mẩu giấy an ủi!' : 'Mẩu giấy đã được xếp và gửi vào chai!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showOceanSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  void _confirmDeleteReply() {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: const Color(0xFF071820),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFEF4444), width: 0.8),
        ),
        title: const Text(
          'Rút lại mẩu giấy?',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Mẩu giấy này sẽ được lấy ra khỏi chai để nhường chỗ trống cho người khác.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmCtx).pop(),
            child: const Text('Giữ lại', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(confirmCtx).pop();
              _handleDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rút lại', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isDeleting = true);

    try {
      await _cloudSecretService.removeReplyAsSender(
        secretId: widget.secretId,
        senderUid: user.uid,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onDeleted?.call();
        showOceanSnackBar(context, 'Đã rút lại mẩu giấy an ủi.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        showOceanSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBusy = _isSubmitting || _isDeleting;

    return AlertDialog(
      backgroundColor: const Color(0xFF071820),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (_isEditing ? const Color(0xFFFFA79A) : const Color(0xFF5EEAD4)).withValues(alpha: 0.25),
        ),
      ),
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_note_rounded : Icons.mail_outline_rounded,
            color: _isEditing ? const Color(0xFFFFA79A) : const Color(0xFF5EEAD4),
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            _isEditing ? 'Sửa mẩu giấy an ủi' : 'Gửi mẩu giấy an ủi',
            style: TextStyle(
              color: _isEditing ? const Color(0xFFFFA79A) : const Color(0xFF5EEAD4),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing
                ? 'Bạn có thể chỉnh sửa lại lời nhắn (tối đa 60 ký tự) hoặc rút lại mẩu giấy:'
                : 'Gấp một lời nhắn nhỏ (tối đa 60 ký tự) gửi vào chai thư của người lạ:',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _replyController,
            maxLength: 60,
            autofocus: true,
            enabled: !isBusy,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Nhập lời an ủi ấm áp...',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
              counterStyle: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
      actions: [
        if (_isEditing)
          TextButton.icon(
            onPressed: isBusy ? null : _confirmDeleteReply,
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
            label: const Text('Rút lại', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Đóng', style: TextStyle(color: Colors.white38)),
        ),
        FilledButton(
          onPressed: isBusy ? null : _handleSend,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5EEAD4),
            foregroundColor: const Color(0xFF06211D),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06211D)),
                )
              : Text(_isEditing ? 'Lưu lại' : 'Gửi gắm', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final heights = [
      8.0, 18.0, 12.0, 24.0, 15.0, 28.0, 10.0, 20.0, 14.0, 23.0, 9.0, 17.0,
    ];

    return SizedBox(
      height: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final height in heights) ...[
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  width: 3,
                  height: active ? height : 8,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF99F6E4)
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnimatedOcean extends StatelessWidget {
  const _AnimatedOcean({
    required this.controller,
    required this.bubbles,
  });

  final AnimationController controller;
  final List<_Bubble> bubbles;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final width = constraints.maxWidth;
            final imageWidth = math.max(width, height * 4);
            final x = -(controller.value * imageWidth);

            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFF06131A)),
                Positioned(
                  left: x,
                  top: 0,
                  bottom: 0,
                  width: imageWidth * 2,
                  child: Row(
                    children: [
                      SizedBox(
                        width: imageWidth,
                        child: Image.asset('assets/bg.png', fit: BoxFit.fill),
                      ),
                      SizedBox(
                        width: imageWidth,
                        child: Image.asset('assets/bg.png', fit: BoxFit.fill),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF020A10).withValues(alpha: 0.24),
                        const Color(0xFF06131A).withValues(alpha: 0.5),
                        const Color(0xFF020A10).withValues(alpha: 0.86),
                      ],
                    ),
                  ),
                ),
                for (final bubble in bubbles)
                  Positioned(
                    left: bubble.x * width,
                    top:
                        ((bubble.y - controller.value * bubble.speed) % 1.05) *
                        height,
                    child: Opacity(
                      opacity: bubble.opacity,
                      child: Container(
                        width: bubble.size,
                        height: bubble.size,
                        decoration: const BoxDecoration(
                          color: Color(0xFF99F6E4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Bubble {
  _Bubble()
    : x = math.Random().nextDouble(),
      y = math.Random().nextDouble(),
      speed = math.Random().nextDouble() * 0.25 + 0.08,
      size = math.Random().nextDouble() * 4 + 2,
      opacity = math.Random().nextDouble() * 0.22 + 0.08;

  final double x;
  final double y;
  final double speed;
  final double size;
  final double opacity;
}

class _OwnerRepliesDialog extends StatefulWidget {
  const _OwnerRepliesDialog({
    required this.secret,
    required this.onRepliesUpdated,
  });

  final OceanSecret secret;
  final VoidCallback onRepliesUpdated;

  @override
  State<_OwnerRepliesDialog> createState() => _OwnerRepliesDialogState();
}

class _OwnerRepliesDialogState extends State<_OwnerRepliesDialog> {
  final CloudSecretService _cloudSecretService = CloudSecretService();
  int? _deletingIndex;

  void _confirmDeleteReply(int index) {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: const Color(0xFF071820),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFEF4444), width: 0.8),
        ),
        title: const Text(
          'Thả mẩu giấy trôi đi?',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Mẩu giấy này sẽ biến mất vĩnh viễn khỏi chiếc chai để nhường chỗ trống cho lời nhắn khác.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmCtx).pop(),
            child: const Text('Giữ lại', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(confirmCtx).pop();
              _handleDeleteReply(index);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Thả trôi', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteReply(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.secret.senderUid) return;

    setState(() => _deletingIndex = index);

    try {
      await _cloudSecretService.removeReplyAsOwner(
        secretId: widget.secret.id,
        ownerUid: user.uid,
        replyIndex: index,
      );

      if (mounted) {
        setState(() {
          final updated = List<dynamic>.from(widget.secret.replies);
          updated.removeAt(index);
          widget.secret.replies = updated;
          widget.secret.repliesCount = updated.length;
          _deletingIndex = null;
        });
        widget.onRepliesUpdated();
        showOceanSnackBar(context, 'Đã thả mẩu giấy trôi đi để nhường chỗ trống.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deletingIndex = null);
        showOceanSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final replies = widget.secret.replies;

    return AlertDialog(
      backgroundColor: const Color(0xFF071820),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF5EEAD4).withValues(alpha: 0.25)),
      ),
      title: Row(
        children: [
          const Icon(Icons.mark_email_read_outlined, color: Color(0xFF5EEAD4), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Những mẩu giấy ủi an (${replies.length}/3)',
              style: const TextStyle(color: Color(0xFF5EEAD4), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: replies.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Chai tâm sự của bạn vẫn đang lênh đênh, chưa có ai nhét mẩu giấy nào vào cả...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              ),
            )
          : SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: replies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final reply = replies[index];
                  final String text = (reply is Map ? reply['text'] : '') ?? '';
                  final bool isThisDeleting = _deletingIndex == index;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('✉ ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Color(0xFFEAF6F4),
                              fontSize: 13,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isThisDeleting)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFA79A)),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFFA79A)),
                            tooltip: 'Gỡ mẩu giấy này ra khỏi chai',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _deletingIndex != null
                                ? null
                                : () => _confirmDeleteReply(index),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5EEAD4),
            foregroundColor: const Color(0xFF06211D),
          ),
          child: const Text('Đóng lại', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
class _DeletePostButton extends StatefulWidget {
  const _DeletePostButton({required this.secret});
  final OceanSecret secret;

  @override
  State<_DeletePostButton> createState() => _DeletePostButtonState();
}

class _DeletePostButtonState extends State<_DeletePostButton> {
  bool _isDeleting = false;

  void _confirmDeletePost(BuildContext context) {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: const Color(0xFF071820),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFEF4444), width: 0.8),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text(
              'Nhấn chìm tâm sự?',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Tâm sự này sẽ vĩnh viễn biến mất khỏi đại dương. Dung lượng lưu trữ sẽ được hoàn trả lại cho kho của bạn.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmCtx).pop(),
            child: const Text('Giữ lại', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(confirmCtx).pop();
              _handleDeletePost();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Nhấn chìm', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeletePost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.secret.senderUid) return;

    setState(() => _isDeleting = true);

    try {
      final int bytes = utf8.encode(widget.secret.body).length;
      await CloudSecretService().deleteSecret(
        secretId: widget.secret.id,
        userId: user.uid,
        sizeInBytes: bytes,
      );

      if (mounted) {
        showOceanSnackBar(context, 'Đã nhấn chìm tâm sự xuống đáy biển.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        showOceanSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleting) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFA79A)),
        ),
      );
    }

    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _confirmDeletePost(context),
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(
            Icons.delete_outline_rounded,
            size: 17,
            color: Color(0xFFFFA79A),
          ),
        ),
      ),
    );
  }
}