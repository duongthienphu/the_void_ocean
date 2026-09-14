import 'package:flutter/material.dart';
import 'package:ocean/core/auth_logic.dart';

class LoginWebScreen extends StatefulWidget {
  const LoginWebScreen({required this.onAuthenticated, super.key});

  final VoidCallback onAuthenticated;

  @override
  State<LoginWebScreen> createState() => _LoginWebScreenState();
}

class _LoginWebScreenState extends State<LoginWebScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegister = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền email và mật khẩu.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu nhập lại không khớp.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
      ),
    );

    try {
      final authService = AuthService();
      await authService.registerWithEmail(
        email: email,
        password: password,
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF071820),
            title: const Text('Xác thực tài khoản', style: TextStyle(color: Color(0xFF5EEAD4))),
            content: Text(
              'Đã gửi liên kết xác thực đến $email.\nVui lòng mở Gmail (kiểm tra cả hòm thư Spam) và nhấn vào liên kết trước khi đăng nhập.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _isRegister = false);
                },
                child: const Text('Đã hiểu', style: TextStyle(color: Color(0xFF5EEAD4))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  void _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền email và mật khẩu.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
      ),
    );

    try {
      final authService = AuthService();
      final userCred = await authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (userCred != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chào mừng cư dân quay trở lại!')),
        );
        widget.onAuthenticated();
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg == 'EMAIL_NOT_VERIFIED') {
          _showEmailNotVerifiedDialog(email, password);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      }
    }
  }

  void _showEmailNotVerifiedDialog(String email, String password) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF071820),
        title: const Text('Chưa xác thực Email', style: TextStyle(color: Color(0xFFFFA79A))),
        content: const Text(
          'Tài khoản này chưa kích hoạt link trong hộp thư Gmail. Bạn có muốn gửi lại email xác thực không?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await AuthService().resendVerificationEmail(email: email, password: password);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã gửi lại link xác thực! Vui lòng kiểm tra hộp thư.')),
                  );
                }
              } catch (err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err.toString())),
                  );
                }
              }
            },
            child: const Text('Gửi lại email', style: TextStyle(color: Color(0xFF5EEAD4))),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF071820),
        title: const Text('Đặt lại mật khẩu', style: TextStyle(color: Color(0xFF5EEAD4))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập địa chỉ Gmail để nhận đường dẫn đặt lại mật khẩu:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'vidu@gmail.com',
                prefixIcon: Icon(Icons.mail_outline, color: Color(0xFF5EEAD4)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              final targetEmail = resetEmailController.text.trim();
              if (targetEmail.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await AuthService().sendPasswordResetEmail(email: targetEmail);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã gửi thư đặt lại mật khẩu tới $targetEmail')),
                  );
                }
              } catch (err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err.toString().replaceAll('Exception: ', ''))),
                  );
                }
              }
            },
            child: const Text('Gửi link', style: TextStyle(color: Color(0xFF5EEAD4))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg.png', fit: BoxFit.cover),
          const _WebOverlay(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1180,
                  minHeight: 640,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center, 
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 56),
                        child: _BrandPanel(
                          onAuthenticated: widget.onAuthenticated,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 430,
                      child: _WebAuthPanel(
                        isRegister: _isRegister,
                        hidePassword: _hidePassword,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        confirmPasswordController: _confirmPasswordController,
                        onToggleMode: () => setState(() => _isRegister = !_isRegister),
                        onTogglePassword: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        onForgotPassword: _showForgotPasswordDialog,
                        onSubmit: _isRegister ? _handleSignUp : _handleSignIn,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. BỌC CONSTRAINEDBOX VÀO ĐÂY ĐỂ GIỚI HẠN CHIỀU RỘNG CỦA BADGE
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 480, // Giới hạn badge rộng tối đa 480px (vừa vặn đẹp mắt trước khi đổi sang bản small)
          ),
          child: const _SoftBadge(
            icon: Icons.water_drop_outlined,
            label: 'Vết thương nào cũng đau, nhưng kì diệu thay vết thương nào rồi cũng sẽ lành.',
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Đại dương\ntĩnh lặng',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: 76,
            height: 0.98,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Text(
            'Nơi mà con người có thể tự do trôi theo làn nước, trút hết tâm sự vào đại dương sâu thẳm.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _MetricPill(
              value: 'KHÔNG',
              label: 'phán xét',
              color: Color(0xFF5EEAD4),
            ),
            _MetricPill(value: 'KHÔNG', label: 'gièm pha', color: Color(0xFFFFA79A)),
            _MetricPill(
              value: 'KHÔNG',
              label: 'tên gọi',
              color: Color(0xFFFBBF24),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _FloatingBottlePreview(onAuthenticated: onAuthenticated),
      ],
    );
  }
}

class _FloatingBottlePreview extends StatelessWidget {
  const _FloatingBottlePreview({required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF071820).withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sailing_outlined,
              color: Color(0xFF99F6E4),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vớt một tâm sự ngẫu nhiên, gieo một nỗi niềm khói nói',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rồi những cơn sóng sẽ cuốn chúng đi, đến bất cứ đâu, bất cứ ai.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebAuthPanel extends StatelessWidget {
  const _WebAuthPanel({
    required this.isRegister,
    required this.hidePassword,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  final bool isRegister;
  final bool hidePassword;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF071820).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 38,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModeSwitch(isRegister: isRegister, onToggleMode: onToggleMode),
          const SizedBox(height: 20),
          Text(
            isRegister ? 'Tạo nơi ẩn danh' : 'Chào mừng trở lại',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isRegister
                ? 'Gieo nỗi niềm của bạn vào làn sóng đại dương.'
                : 'Tiếp tục gieo và vớt những tâm sự trôi xa.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _AuthField(
            controller: emailController,
            icon: Icons.alternate_email,
            hintText: 'Địa chỉ Gmail của bạn',
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
                isRegister ? 'Đăng ký cư dân' : 'Vào đại dương',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!isRegister) ...[
            Center(
              child: TextButton.icon(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5EEAD4),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                icon: const Icon(Icons.lock_reset, size: 16),
                label: const Text(
                  'Quên mật mã truy cập?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF071820).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
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

class _WebOverlay extends StatelessWidget {
  const _WebOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF020A10).withValues(alpha: 0.92),
            const Color(0xFF06131A).withValues(alpha: 0.7),
            const Color(0xFF020A10).withValues(alpha: 0.86),
          ],
        ),
      ),
    );
  }
}
