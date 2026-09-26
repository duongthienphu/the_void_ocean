import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ocean/features/auth/auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print("Firebase đã được khởi tạo trước đó: $e");
  }
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final prefs = await SharedPreferences.getInstance();
  final bool hasAcceptedTerms = prefs.getBool('has_accepted_terms_v1.0.0_beta') ?? false;
  
  runApp(VoidOceanApp(hasAcceptedTerms: hasAcceptedTerms));
}

class VoidOceanApp extends StatefulWidget {
  const VoidOceanApp({super.key, required this.hasAcceptedTerms});
  final bool hasAcceptedTerms;

  @override
  State<VoidOceanApp> createState() => _VoidOceanAppState();
}

  class _VoidOceanAppState extends State<VoidOceanApp> {
  late bool _accepted;

  @override
  void initState() {
    super.initState();
    _accepted = widget.hasAcceptedTerms;
  }

  Future<void> _handleAccept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_terms_v1.0.0_beta', true);
    setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Đại dương tĩnh lặng',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF06131A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2DD4BF),
          secondary: Color(0xFFFF8A7A),
          surface: Color(0xFF0B1C24),
        ),
        textTheme: baseTheme.textTheme.apply(
          bodyColor: const Color(0xFFEAF6F4),
          displayColor: const Color(0xFFEAF6F4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF06131A).withValues(alpha: 0.66),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF5EEAD4)),
          ),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      home: _accepted
          ? const AuthWrapper()
          : OceanOnboardingTermsScreen(onAccepted: _handleAccept),
    );
  }
}

class OceanOnboardingTermsScreen extends StatelessWidget {
  const OceanOnboardingTermsScreen({super.key, required this.onAccepted});
  final VoidCallback onAccepted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06131A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF071820),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF5EEAD4).withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5EEAD4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.water_drop_outlined, color: Color(0xFF5EEAD4), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'The Void Ocean',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF5EEAD4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chào mừng bạn đến với nơi cất giữ những tâm sự ẩn danh.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                  ),
                  const SizedBox(height: 16),

                  // Khối Điều khoản dịch vụ
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'QUY ƯỚC ĐẠI DƯƠNG (TERMS OF SERVICE)',
                          style: TextStyle(
                            color: Color(0xFFFFA79A),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Giữ kín danh tính: Tuyệt đối không để lại số điện thoại, mạng xã hội hay thông tin cá nhân (Doxxing).\n'
                          '• Tôn trọng nỗi đau: Cấm đổ lỗi nạn nhân, thù ghét, công kích hoặc xúi giục tự hại.\n'
                          '• Cá kiểm duyệt AI: Mọi bài viết và reply đều được rà soát nội dung trước khi trôi dạt.',
                          style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Khối Tác quyền
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'TÁC QUYỀN & CREDITS',
                          style: TextStyle(
                            color: Color(0xFF99F6E4),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Phát triển ứng dụng: Dương Thiên Phú\n'
                          '• Hình nền đại dương: ansimuz (Giấy phép CC BY 4.0 International)\n'
                          '• Biểu tượng ứng dụng: CraftPix\n'
                          '• Nhạc nền: "Flying above the ocean" bởi TAD (Giấy phép CC-BY 3.0 via OpenGameArt)',
                          style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Chi tiết giấy phép âm nhạc: creativecommons.org/licenses/by/3.0',
                          style: TextStyle(color: Colors.white38, fontSize: 10.5, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: onAccepted,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5EEAD4),
                        foregroundColor: const Color(0xFF06211D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.sailing_rounded, size: 18),
                      label: const Text(
                        'Tôi đồng ý quy ước & Ra khơi',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}