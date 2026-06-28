import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
class LoginMobileScreen extends StatefulWidget {
  const LoginMobileScreen({super.key});

  @override
  State<LoginMobileScreen> createState() => _LoginMobileScreenState();
}

class _LoginMobileScreenState extends State<LoginMobileScreen> {
  // Biến trạng thái: true là hiển thị Đăng nhập, false là hiển thị Đăng ký
  bool isLoginMode = true;

  // Các bộ điều khiển để lấy dữ liệu text người dùng nhập
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dùng ResizeToAvoidBottomInset để khi hiện bàn phím ảo không bị lỗi tràn màn hình (Overflow)
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // 1. Ép hình nền tĩnh để điện thoại chạy nhẹ và mượt nhất
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/void_ocean_static.png'), // Bạn nhớ thêm ảnh này vào assets nhé
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            // Dùng SingleChildScrollView để người dùng màn hình nhỏ vuốt lên xuống được khi hiện bàn phím
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 2. Logo / Tên Game
                  Text(
                    "ĐẠI DƯƠNG TĨNH LẶNG",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexendZetta(
                      color:  Color(0xFF00E5FF),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isLoginMode ? "Chào mừng Thuyền Trường trở lại" : "Khởi tạo hành trình ẩn danh",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  // 3. Khung Form nhập liệu (Chứa trong một Container mờ tạo cảm giác hiện đại)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        // Ô nhập Tài khoản
                        TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Tên tài khoản hoặc Email",
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.person, color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Ô nhập Mật khẩu
                        TextField(
                          controller: _passwordController,
                          obscureText: true, // Ẩn mật khẩu thành dấu chấm
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Mật khẩu",
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        
                        // Nếu là chế độ Đăng ký -> Hiện thêm ô Nhập lại mật khẩu
                        if (!isLoginMode) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Xác nhận mật khẩu",
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(Icons.lock_clock, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // 4. Nút bấm Hành động chính (Đăng nhập / Đăng ký)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              if (isLoginMode) {
                                // Xử lý logic Đăng nhập ở đây
                                print("Đăng nhập với: ${_usernameController.text}");
                              } else {
                                // Xử lý logic Đăng ký ở đây
                                print("Đăng ký với: ${_usernameController.text}");
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isLoginMode ? "ĐĂNG NHẬP" : "ĐĂNG KÝ NGAY",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Nút chuyển đổi trạng thái giữa Đăng nhập và Đăng ký
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isLoginMode = !isLoginMode; // Đảo ngược trạng thái để đổi UI
                      });
                    },
                    child: Text(
                      isLoginMode 
                          ? "Chưa có tài khoản? Đăng ký tại đây" 
                          : "Đã có tài khoản? Quay lại Đăng nhập",
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
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