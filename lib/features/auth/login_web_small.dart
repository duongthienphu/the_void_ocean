import 'package:flutter/material.dart';
import 'package:ocean/core/auth_logic.dart';
class LoginWebSmallScreen extends StatefulWidget {
  const LoginWebSmallScreen({required this.onAuthenticated, super.key});

  final VoidCallback onAuthenticated;

  @override
  State<LoginWebSmallScreen> createState() => _LoginWebSmallScreenState();
}

class _LoginWebSmallScreenState extends State<LoginWebSmallScreen> {
  // 1. ĐÃ XÓA _confirmPasswordController và biến _isRegister
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  void _handleSignIn() async {
    final nickname = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (nickname.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền biệt danh và mật khẩu.')),
      );
      return;
    }

    // Mở vòng xoay đợi Firebase phản hồi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
      ),
    );

    try {
      final authService = AuthService();
      final userCred = await authService.signInWithNickname(
        nickname: nickname,
        password: password,
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Tắt Loading

      if (userCred != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chào mừng cư dân quay trở lại!')),
        );
        widget.onAuthenticated(); // Xác thực xong, đẩy vào game chính!
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Tắt Loading nếu lỗi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _OceanBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SoftBadge(
                              icon: Icons.water_drop_outlined,
                              label: 'Vết thương nào cũng đau, nhưng kì diệu thay \nvết thương nào rồi cũng sẽ lành.',
                            ),
                            const SizedBox(height: 26),
                            Text(
                              'Đại dương\ntĩnh lặng',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    fontSize: 39,
                                    height: 1.02,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Vớt một tâm sự ngẫu nhiên, gieo một nỗi niềm khó nói. Rồi những cơn sóng sẽ cuốn chúng đi, đến bất cứ đâu, bất cứ ai.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // 2. CẬP NHẬT TRUYỀN THAM SỐ GỌN NHẸ CHO _AuthPanel
                        _AuthPanel(
                          hidePassword: _hidePassword,
                          nameController: _nameController,
                          passwordController: _passwordController,
                          onTogglePassword: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          onSubmit: _handleSignIn,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.hidePassword,
    required this.nameController,
    required this.passwordController,
    required this.onTogglePassword,
    required this.onSubmit,
  }); // <-- Đã xóa các tham số Đăng ký ở đây

  final bool hidePassword;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF071820).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3. ĐÃ XÓA TOÀN BỘ THANH CHUYỂN CHẾ ĐỘ _ModeSwitch Ở ĐÂY
          
          _AuthField(
            controller: nameController,
            icon: Icons.alternate_email,
            hintText: 'Email hoặc biệt danh',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: passwordController,
            icon: Icons.lock_outline,
            hintText: 'Mật khẩu',
            obscureText: hidePassword,
            suffixIcon: IconButton(
              tooltip: hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: onTogglePassword,
              icon: Icon(
                hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
          ),
          
          // 4. ĐÃ XÓA ĐOẠN CHECK "if (isRegister) ...[" Ô NHẬP LẠI MẬT KHẨU
          
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5EEAD4),
                foregroundColor: const Color(0xFF06211D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.waves, size: 20),
              label: const Text(
                'Vào đại dương', // <-- Ép cứng chữ Đăng nhập luôn
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SoftBadge(icon: Icons.favorite_border, label: 'Chỉ thả tim'),
              _SoftBadge(icon: Icons.mic_none, label: 'Text và audio'),
              _SoftBadge(icon: Icons.person_off_outlined, label: 'Ẩn danh'),
            ],
          ),
        ],
      ),
    );
  }
}

// 5. ĐÃ XÓA BỎ HOÀN TOÀN 2 CLASS _ModeSwitch VÀ _ModeButton KHỎI FILE

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.icon,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF99F6E4), size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// 6. TỐI ƯU LẠI _SoftBadge ĐỂ TỰ ĐỘNG KHÔNG BỊ TRÀN CHỮ TRÊN WEB
class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFFFA79A)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OceanBackdrop extends StatelessWidget {
  const _OceanBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/bg.png', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF020A10).withValues(alpha: 0.2),
                const Color(0xFF071820).withValues(alpha: 0.7),
                const Color(0xFF020A10).withValues(alpha: 0.96),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.7, -0.65),
              radius: 0.9,
              colors: [
                const Color(0xFF2DD4BF).withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}