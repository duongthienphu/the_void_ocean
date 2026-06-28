import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const VoidOceanApp());
}

class VoidOceanApp extends StatelessWidget {
  const VoidOceanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712), // Màu đen đại dương sâu thẳm
      ),
      home: const OceanHomeScreen(),
    );
  }
}

class OceanHomeScreen extends StatefulWidget {
  const OceanHomeScreen({super.key});

  @override
  State<OceanHomeScreen> createState() => _OceanHomeScreenState();
}

class _OceanHomeScreenState extends State<OceanHomeScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _driftingBottles = []; // Đổi sang Map để lưu thêm lượt đồng cảm
  final TextEditingController _secretController = TextEditingController();
  late AnimationController _oceanController;

  // Danh sách các hạt bong bóng nước trôi ngẫu nhiên ở nền
  final List<_Bubble> _bubbles = List.generate(25, (index) => _Bubble());

  @override
  void initState() {
    super.initState();
    // Tạo một controller chạy liên tục cho cả sóng lẫn bong bóng nước
    _oceanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _oceanController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _throwBottleIntoOcean() {
    if (_secretController.text.trim().isNotEmpty) {
      setState(() {
        _driftingBottles.insert(0, {
          'text': _secretController.text,
          'empathy': 0,
          'isLiked': false,
          'seed': math.Random().nextDouble() * 100, // Độ lệch nhịp trôi riêng của mỗi chai
        });
      });
      _secretController.clear();
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Your secret has vanished into the deep ocean...'),
          backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _openVentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B132B), 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 28, left: 24, right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What do you need to let go of?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secretController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Type your deepest thoughts here...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _throwBottleIntoOcean,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: const Text('Release to the Void', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _oceanController,
        builder: (context, child) {
          // 1. Lấy chiều cao màn hình hiện tại
          double screenHeight = MediaQuery.of(context).size.height;
          
          // 2. Tỷ lệ chuẩn của ảnh underwater-fantasy-preview.png là 4.0 (Chiều rộng / Chiều cao = 800 / 200)
          // Nếu ảnh của bạn có tỷ lệ khác, hãy đổi số 4.0 này thành tỷ lệ chính xác (Ví dụ: 800/200 = 4.0)
          double imageAspectRatio = 4.0; 
          
          // 3. Chiều rộng thực tế của MỘT bức ảnh sau khi đã fit hết chiều cao màn hình
          double singleImageWidth = screenHeight * imageAspectRatio;
          
          // 4. Khóa khoảng cách dịch chuyển tối đa bằng ĐÚNG chiều rộng của một bức ảnh
          double xPos = -(_oceanController.value * singleImageWidth);

          return Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF030712),
            child: Stack(
              children: [
                // LỚP HÌNH NỀN TRÔI NGANG VÔ TẬN KHÔNG GIẬT LẮC
                Positioned(
                  left: xPos,
                  top: 0,
                  bottom: 0,
                  width: singleImageWidth * 2, // Luôn luôn gấp đôi chiều rộng một ảnh để nối đuôi
                  child: Stack(
                    children: [
                      // Ảnh 1: Nằm ở góc 0
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: singleImageWidth,
                        child: Image.asset(
                          'assets/bg.png', 
                          fit: BoxFit.fill, // Dùng fill ở đây hoàn toàn an toàn vì khung SizedBox đã được khóa đúng tỷ lệ gốc
                        ),
                      ),
                      // Ảnh 2: Nối đuôi ngay sau ảnh 1
                      Positioned(
                        left: singleImageWidth,
                        top: 0,
                        bottom: 0,
                        width: singleImageWidth,
                        child: Image.asset(
                          'assets/bg.png', 
                          fit: BoxFit.fill,
                        ),
                      ),
                    ],
                  ),
                ),

                // LỚP HẠT BONG BÓNG NƯỚC (Giữ lại để tăng độ lung linh nếu muốn)
                ..._bubbles.map((bubble) {
                  double yPos = bubble.startY - (_oceanController.value * MediaQuery.of(context).size.height * bubble.speed);
                  if (yPos < -20) yPos += MediaQuery.of(context).size.height + 20;

                  return Positioned(
                    left: bubble.startX,
                    top: yPos,
                    child: Opacity(
                      opacity: bubble.opacity,
                      child: Container(
                        width: bubble.size,
                        height: bubble.size,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),

                child!,
              ],
            ),
          );
        },
        child: Stack(
          children: [
            // 2. LỚP HIỂN THỊ SECRET: Chai thủy tinh dập dềnh xịn mịn
            _driftingBottles.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.blur_on, size: 48, color: Colors.white12),
                        SizedBox(height: 16),
                        Text(
                          'The ocean is silent.\nTap below to release a secret.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white24, fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _driftingBottles.length,
                    padding: const EdgeInsets.fromLTRB(20, 90, 20, 120),
                    itemBuilder: (context, index) {
                      final bottle = _driftingBottles[index];

                      return AnimatedBuilder(
                        animation: _oceanController,
                        builder: (context, child) {
                          // Thuật toán sóng sin cá nhân hóa giúp mỗi chai trôi một kiểu khác nhau
                          final double floatEffect = math.sin((_oceanController.value * 2 * math.pi * 2) + bottle['seed']) * 8;
                          return Transform.translate(
                            offset: Offset(0, floatEffect),
                            child: child,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            // Hiệu ứng lọ thủy tinh pha lê (Glow glassmorphism)
                            color: const Color(0xFF0F172A).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.15), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0EA5E9).withOpacity(0.03),
                                blurRadius: 15,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.lens_blur, color: Color(0xFF38BDF8), size: 22),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        bottle['text'],
                                        style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 16, height: 1.5, letterSpacing: 0.1),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 8),
                                // Nút Đồng cảm im lặng (Silent Empathy) ngọt ngào
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (bottle['isLiked']) {
                                            bottle['empathy']--;
                                            bottle['isLiked'] = false;
                                          } else {
                                            bottle['empathy']++;
                                            bottle['isLiked'] = true;
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: bottle['isLiked'] ? const Color(0xFF0EA5E9).withOpacity(0.15) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              bottle['isLiked'] ? Icons.wb_twilight : Icons.wb_twilight_outlined,
                                              color: bottle['isLiked'] ? const Color(0xFF38BDF8) : Colors.white30,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${bottle['empathy']}',
                                              style: TextStyle(
                                                color: bottle['isLiked'] ? const Color(0xFF38BDF8) : Colors.white30,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

            // Nút "Vent" được bọc mờ sương nghệ thuật
            Positioned(
              bottom: 36,
              left: 24,
              right: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openVentSheet,
                      child: const Center(
                        child: Text(
                          'Vent to the Deep Void',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Lớp phụ trợ cấu hình ngẫu nhiên cho từng hạt bong bóng nước
class _Bubble {
  final double startX = math.Random().nextDouble() * 400; // Ngẫu nhiên chiều ngang
  final double startY = math.Random().nextDouble() * 800; // Ngẫu nhiên chiều cao khởi tạo
  final double size = math.Random().nextDouble() * 4 + 2;   // Kích thước hạt từ 2-6 pixel
  final double speed = math.Random().nextDouble() * 0.4 + 0.2; // Tốc độ bay lên
  final double opacity = math.Random().nextDouble() * 0.3 + 0.1; // Độ mờ sương ẩn hiện
}