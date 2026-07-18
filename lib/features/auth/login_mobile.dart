import 'package:flutter/material.dart';
import 'package:ocean/core/auth_logic.dart';

class LoginMobileScreen extends StatefulWidget {
  const LoginMobileScreen({required this.onAuthenticated, super.key});

  final VoidCallback onAuthenticated;

  @override
  State<LoginMobileScreen> createState() => _LoginMobileScreenState();
}

class _LoginMobileScreenState extends State<LoginMobileScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegister = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  void _handleSignUp() async {
  final nickname = _nameController.text.trim();
  final password = _passwordController.text.trim();
  final confirmPassword = _confirmPasswordController.text.trim();
  
  if (nickname.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng điền biệt danh và mật khẩu.')),
    );
    return;
  }

  if (password != confirmPassword) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mật khẩu nhập lại không khớp.')),
    );
    return;
  }

  // Hiển thị vòng xoay Loading chờ phản hồi từ Firebase
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
    ),
  );

  try {
    // Gọi Service đăng ký
    final authService = AuthService();
    final userCred = await authService.registerWithNickname(
      nickname: nickname,
      password: password,
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); 
    } // Tắt vòng xoay Loading

    if (userCred != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chào mừng bạn đến với Đại dương tĩnh lặng!')),
      );
      widget.onAuthenticated(); // Đăng ký xong, kích hoạt chuyển màn hình vào game[cite: 2]
    }
  } catch (e) {
    if (mounted) Navigator.of(context).pop(); // Tắt Loading nếu thất bại
    if (mounted) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg == 'DEVICE_LINKED_ANOTHER_OCEAN') {
        errorMsg = 'Thiết bị đã liên kết với vùng biển khác.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }
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
    // Hiển thị vòng xoay Loading chờ phản hồi từ Firebase
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
      ),
    );
    try {
      // Gọi Service đăng nhập đã viết trong auth_logic.dart
      final authService = AuthService();
      final userCred = await authService.signInWithNickname(
        nickname: nickname,
        password: password,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Tắt vòng xoay Loading
      }

      if (userCred != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chào mừng cư dân quay trở lại!')),
        );
        widget.onAuthenticated(); // Đăng nhập thành công, kích hoạt bay vào game
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Tắt Loading nếu thất bại
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
                              'Vớt một tâm sự ngẫu nhiên, gieo một nỗi niềm khói nói. Rồi những cơn sóng sẽ cuốn chúng đi, đến bất cứ đâu, bất cứ ai.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _AuthPanel(
                        isRegister: _isRegister,
                        hidePassword: _hidePassword,
                        nameController: _nameController,
                        passwordController: _passwordController,
                        confirmPasswordController: _confirmPasswordController,
                        onToggleMode: () => setState(() => _isRegister = !_isRegister),
                        onTogglePassword: () => setState(() => _hidePassword = !_hidePassword),
                        onSubmit: _isRegister ? _handleSignUp : _handleSignIn
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
    required this.isRegister,
    required this.hidePassword,
    required this.nameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final bool isRegister;
  final bool hidePassword;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onToggleMode;
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
          _ModeSwitch(isRegister: isRegister, onToggleMode: onToggleMode),
          const SizedBox(height: 18),
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
          if (isRegister) ...[
            const SizedBox(height: 12),
            _AuthField(
              controller: confirmPasswordController,
              icon: Icons.verified_user_outlined,
              hintText: 'Nhập lại mật khẩu',
              obscureText: hidePassword,
            ),
          ],
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
              label: Text(
                isRegister ? 'Tạo nơi ẩn danh' : 'Vào đại dương',
                style: const TextStyle(
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

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.isRegister, required this.onToggleMode});

  final bool isRegister;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Đăng nhập',
            selected: !isRegister,
            onTap: isRegister ? onToggleMode : null,
          ),
          _ModeButton(
            label: 'Đăng ký',
            selected: isRegister,
            onTap: isRegister ? null : onToggleMode,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.56),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
