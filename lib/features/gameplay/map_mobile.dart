import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ocean/core/game_logic.dart';

class OceanMobileScreen extends StatefulWidget {
  const OceanMobileScreen({super.key});

  @override
  State<OceanMobileScreen> createState() => _OceanMobileScreenState();
}

class _OceanMobileScreenState extends State<OceanMobileScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _bubbles = List.generate(24, (_) => _Bubble());
  late final AnimationController _oceanController;
  late final List<OceanSecret> _secrets;

  // Quản lý Tab hiện tại trên Mobile (0: Home/Vớt, 1: Gieo, 2: User)
  int _currentTab = 0;

  // Trạng thái UI giả lập cho luồng Vớt tâm sự
  OceanSecret? _currentFishedSecret;
  int _fishedCountToday = 0;
  final int _maxFishPerDay = 15;

  SecretKind _draftKind = SecretKind.text;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _secrets = createInitialSecrets();
    _oceanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _textController.addListener(_refreshDraft);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _textController
      ..removeListener(_refreshDraft)
      ..dispose();
    _oceanController.dispose();
    super.dispose();
  }

  void _refreshDraft() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canThrow {
    if (_draftKind == SecretKind.text) {
      return _textController.text.trim().isNotEmpty;
    }
    return _recordingSeconds > 0;
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

  void _throwSecret() {
    if (!_canThrow) return;

    final secret = _draftKind == SecretKind.text
        ? OceanSecret(
            body: _textController.text.trim(),
            kind: SecretKind.text,
            drift: 'Vừa thả xuống dòng sâu di động',
            hearts: 0,
            palette: const [0xFF5EEAD4, 0xFFFFA79A],
          )
        : OceanSecret(
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
    _textController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã thả tâm sự vào đại dương.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0B2B2C).withValues(alpha: 0.94),
      ),
    );
  }

  void _toggleHeart(OceanSecret secret) {
    setState(() {
      secret.isLiked = !secret.isLiked;
      secret.hearts += secret.isLiked ? 1 : -1;
    });
  }

  // Logic UI xử lý vớt ngẫu nhiên 1 tâm sự (Tối đa 15 lần/ngày)
  void _fishRandomSecret() {
    if (_fishedCountToday >= _maxFishPerDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hôm nay bạn đã vớt đủ 15 lần. Ngày mai quay lại nhé.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_secrets.isEmpty) return;

    final index = math.Random().nextInt(_secrets.length);
    setState(() {
      _currentFishedSecret = _secrets[index];
      _fishedCountToday++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: _AnimatedOcean(
        controller: _oceanController,
        bubbles: _bubbles,
        child: SafeArea(
          child: Column(
            children: [
              const _MobileTopBar(),
              Expanded(
                child: _buildActiveTabContent(),
              ),
            ],
          ),
        ),
      ),
      // Thanh điều hướng dưới đáy màn hình (Bottom Navigation Bar)
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

  // Phân luồng hiển thị view theo Tab được lựa chọn
  Widget _buildActiveTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildGieoTab();
      case 2:
        return _buildUserTab();
      default:
        return const SizedBox.shrink();
    }
  }

  /// =========================================================
  /// TAB 0: HOME PAGE - NƠI VỚT MỖI LẦN 1 TÂM SỰ (TỐI ĐA 15 LẦN)
  /// =========================================================
  Widget _buildHomeTab() {
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
                      'Hôm nay: $_fishedCountToday/$_maxFishPerDay lần vớt',
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
              child: _currentFishedSecret == null
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
                            secret: _currentFishedSecret!,
                            controller: _oceanController,
                            onHeart: () => _toggleHeart(_currentFishedSecret!),
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
              onPressed: _fishRandomSecret,
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

  /// =========================================================
  /// TAB 1: GIEO PAGE - LƯU TẠI TRANG, XEM LẠI & THEO DÕI DUNG LƯỢNG
  /// =========================================================
  Widget _buildGieoTab() {
    // Thông số dung lượng giả lập 20MB tương thích data lõi
    const double maxStorageBytes = 20971520;
    const double availableStorageBytes = 16777216; // Giả lập đã dùng 4MB còn 16MB
    const double usedStorageBytes = maxStorageBytes - availableStorageBytes;
    final double usagePercent = usedStorageBytes / maxStorageBytes;

    return Column(
      children: [
        // Widget theo dõi dung lượng cho phép của cư dân
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
                children: const [
                  Text('Kho chứa đại dương', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF99F6E4))),
                  Text('Tối đa: 20 MB', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  Text('Đã lưu: ${(usedStorageBytes / (1024 * 1024)).toStringAsFixed(2)} MB', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  Text('Còn trống: ${(availableStorageBytes / (1024 * 1024)).toStringAsFixed(2)} MB', style: const TextStyle(color: Color(0xFFFFA79A), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        
        // Danh sách hiển thị các tâm sự đã gieo để xem lại
        Expanded(
          child: _secrets.isEmpty
              ? const Center(child: Text('Đại dương trống rỗng...', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _secrets.length,
                  itemBuilder: (context, index) {
                    final secret = _secrets[index];
                    return _SecretBottleCard(
                      secret: secret,
                      controller: _oceanController,
                      onHeart: () => _toggleHeart(secret),
                    );
                  },
                ),
        ),
        
        // Form nhập liệu gieo tâm sự giữ nguyên cấu hình mobile cũ
        _MobileComposer(
          draftKind: _draftKind,
          textController: _textController,
          recordingSeconds: _recordingSeconds,
          isRecording: _isRecording,
          canThrow: _canThrow,
          onKindChanged: _changeDraftKind,
          onToggleRecording: _toggleRecording,
          onThrow: _throwSecret,
        ),
      ],
    );
  }

  /// =========================================================
  /// TAB 2: USER PAGE - CÁC TÍNH NĂNG TÀI KHOẢN & DANGER ZONE
  /// =========================================================
  Widget _buildUserTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 🟩 KHU VỰC CÀI ĐẶT THÔNG THƯỜNG
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF071820).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF5EEAD4).withValues(alpha: 0.14),
                      child: const Icon(Icons.person, color: Color(0xFF5EEAD4)),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Cư dân ẩn danh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 2),
                        Text('Tài khoản bảo mật 2 lớp', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                
                // Tính năng Đổi Mật Khẩu UI
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset, color: Color(0xFF99F6E4)),
                  title: const Text('Thay đổi mã mật đạo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Thiết lập lại mật khẩu tài khoản', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('[UI] Mở trang đổi mật khẩu.')),
                    );
                  },
                ),
                const Divider(color: Colors.white10),
                
                // Tính năng Đổi Thiết Bị Mặc Định UI
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phonelink_setup_rounded, color: Color(0xFF99F6E4)),
                  title: const Text('Thay đổi thiết bị mặc định', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Đồng bộ định danh thiết bị này làm gốc', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('[UI] Bật popup xác nhận đồng bộ mã Device ID mới.')),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // 🟥 KHU VỰC NGUY HIỂM (DANGER ZONE) - PHONG CÁCH GITHUB
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF140D0B).withValues(alpha: 0.6), // Nền hơi đỏ sẫm
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1.2), // Viền cảnh báo đỏ
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.dangerous_outlined, color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Khu vực nguy hiểm (Danger Zone)',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Những hành động dưới đây sẽ xóa vĩnh viễn dữ liệu và không thể khôi phục lại. Cẩn trọng tránh bấm nhầm.',
                  style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 16),
                
                // Nút Xóa Tài Khoản đã được cách ly vào vùng nguy hiểm
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('[UI] Bật popup xác nhận xóa tài khoản vĩnh viễn.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFA79A),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 0.8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: const Text('Xóa vĩnh viễn tài khoản cư dân', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  } // Dấu ngoặc nhọn thần thánh kết thúc hàm _buildUserTab nằm ở đây nè Phú!
}

// ---------------------------------------------------------------------
// CÁC CLASS HELPER BÊN DƯỚI ĐÃ ĐƯỢC ĐẨY RA NGOÀI NGANG HÀNG CLASS CHÍNH
// ---------------------------------------------------------------------

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                  'Đại dương ẩn danh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Text, audio và những trái tim im lặng',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_off_outlined,
              size: 18,
              color: Color(0xFFFFA79A),
            ),
          ),
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
    required this.canThrow,
    required this.onKindChanged,
    required this.onToggleRecording,
    required this.onThrow,
  });

  final SecretKind draftKind;
  final TextEditingController textController;
  final int recordingSeconds;
  final bool isRecording;
  final bool canThrow;
  final ValueChanged<SecretKind> onKindChanged;
  final VoidCallback onToggleRecording;
  final VoidCallback onThrow;

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
                selected: draftKind == SecretKind.audio,
                onTap: () => onKindChanged(SecretKind.audio),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (draftKind == SecretKind.text)
            TextField(
              controller: textController,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
              decoration: const InputDecoration(
                hintText: 'Viết điều bạn muốn gửi xuống biển...',
                prefixIcon: Icon(Icons.edit_note, color: Color(0xFF99F6E4)),
              ),
            )
          else
            _AudioDraft(
              recordingSeconds: recordingSeconds,
              isRecording: isRecording,
              onToggleRecording: onToggleRecording,
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: canThrow ? onThrow : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5EEAD4),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: const Color(0xFF06211D),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Thả xuống đại dương',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
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
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

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
    required this.secret,
    required this.controller,
    required this.onHeart,
  });

  final OceanSecret secret;
  final AnimationController controller;
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
                      ? _AudioSecret(secret: secret)
                      : _TextSecret(secret: secret),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
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
                ),
                _HeartButton(secret: secret, onTap: onHeart),
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

class _AudioSecret extends StatelessWidget {
  const _AudioSecret({required this.secret});

  final OceanSecret secret;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          secret.body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFEAF6F4),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.play_arrow_rounded,
              size: 18,
              color: Color(0xFFFFA79A),
            ),
            const SizedBox(width: 6),
            Expanded(child: _Waveform(active: true)),
            const SizedBox(width: 10),
            Text(
              formatSecretDuration(secret.duration ?? Duration.zero),
              style: const TextStyle(
                color: Color(0xFF99F6E4),
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w900,
              ),
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
    required this.child,
  });

  final AnimationController controller;
  final List<_Bubble> bubbles;
  final Widget child;

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
                child,
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