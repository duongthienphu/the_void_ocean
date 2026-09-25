import 'package:flutter/material.dart';
import 'package:ocean/core/auth_logic.dart';
import 'package:ocean/core/ocean_snackbar.dart';

class LoginMobileScreen extends StatefulWidget {
  const LoginMobileScreen({required this.onAuthenticated, super.key});

  final VoidCallback onAuthenticated;

  @override
  State<LoginMobileScreen> createState() => _LoginMobileScreenState();
}

class _LoginMobileScreenState extends State<LoginMobileScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

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
      showOceanSnackBar(context, 'Vui lòng điền email và mật khẩu.', isError: true);
      return;
    }

  if (password != confirmPassword) {
      showOceanSnackBar(context, 'Mật khẩu nhập lại không khớp.', isError: true);
      return;
    }
  setState(() => _isSubmitting = true);
  try {
    // Gọi Service đăng ký
    final authService = AuthService();
    await authService.registerWithEmail(
        email: email,
        password: password,
      );
    if (mounted) {
        setState(() => _isSubmitting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF071820),
            title: const Text('Xác thực tài khoản', style: TextStyle(color: Color(0xFF5EEAD4))),
            content: Text(
              'Nhân viên cá đã gửi liên kết xác thực đến $email.\nVui lòng mở Gmail (kiểm tra cả hòm thư Spam) và nhấn vào liên kết trước khi đăng nhập.',
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
  void _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showOceanSnackBar(context, 'Vui lòng điền email và mật khẩu.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
    final authService = AuthService();
    await authService.signInWithEmail(
      email: email,
      password: password,
    );
   } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg == 'EMAIL_NOT_VERIFIED') {
          _showEmailNotVerifiedDialog(email, password);
        } else {
          showOceanSnackBar(context, errorMsg, isError: true);
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
          'Tài khoản này chưa kích hoạt link trong hộp thư Gmail. Bạn có muốn nhân viên cá gửi lại email xác thực không?',
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
                  showOceanSnackBar(context, 'Nhân viên cá đã gửi lại link xác thực! Vui lòng kiểm tra hộp thư.');
                }
              } catch (err) {
                if (mounted) {
                  showOceanSnackBar(context, err.toString().replaceAll('Exception: ', ''), isError: true);
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
                  showOceanSnackBar(context, 'Nhân viên cá đã gửi thư đặt lại mật khẩu tới $targetEmail');
                }
              } catch (err) {
                if (mounted) {
                  showOceanSnackBar(context, err.toString().replaceAll('Exception: ', ''), isError: true);
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
                        isSubmitting: _isSubmitting,
                        nameController: _emailController,
                        passwordController: _passwordController,
                        confirmPasswordController: _confirmPasswordController,
                        onToggleMode: () => setState(() => _isRegister = !_isRegister),
                        onTogglePassword: () => setState(() => _hidePassword = !_hidePassword),
                        onForgotPassword: _showForgotPasswordDialog,
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
    required this.isSubmitting,
    required this.nameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  final bool isRegister;
  final bool hidePassword;
  final bool isSubmitting;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
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
            hintText: 'Email',
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
            child: FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5EEAD4),
                foregroundColor: const Color(0xFF06211D),
                disabledBackgroundColor: const Color(0xFF5EEAD4).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF06211D),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.waves, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isRegister ? 'Tạo nơi ẩn danh' : 'Vào đại dương',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
