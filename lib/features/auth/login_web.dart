import 'package:flutter/material.dart';

class LoginWebScreen extends StatefulWidget {
  const LoginWebScreen({required this.onAuthenticated, super.key});

  final VoidCallback onAuthenticated;

  @override
  State<LoginWebScreen> createState() => _LoginWebScreenState();
}

class _LoginWebScreenState extends State<LoginWebScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                        hidePassword: _hidePassword,
                        nameController: _nameController,
                        passwordController: _passwordController,
                        onTogglePassword: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        onSubmit: widget.onAuthenticated,
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
    required this.hidePassword,
    required this.nameController,
    required this.passwordController,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final bool hidePassword;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final VoidCallback onTogglePassword;
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chào mừng trở lại',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tiếp tục gieo và vớt những tâm sự trôi xa.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
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
                'Vào đại dương',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SoftBadge(icon: Icons.person_off_outlined, label: 'Ẩn danh'),
              _SoftBadge(icon: Icons.favorite_border, label: 'Chỉ thả tim'),
              _SoftBadge(icon: Icons.mic_none, label: 'Text và audio'),
            ],
          ),
        ],
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
