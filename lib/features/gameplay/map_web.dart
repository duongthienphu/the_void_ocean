import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ocean/core/game_logic.dart';

class OceanWebScreen extends StatefulWidget {
  const OceanWebScreen({super.key});

  @override
  State<OceanWebScreen> createState() => _OceanWebScreenState();
}

class _OceanWebScreenState extends State<OceanWebScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _bubbles = List.generate(34, (_) => _Bubble());
  late final AnimationController _oceanController;
  late final List<OceanSecret> _secrets;

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
      duration: const Duration(seconds: 30),
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

  int get _audioCount =>
      _secrets.where((secret) => secret.kind == SecretKind.audio).length;

  int get _heartCount =>
      _secrets.fold<int>(0, (total, secret) => total + secret.hearts);

  void _changeDraftKind(SecretKind kind) {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    setState(() {
      _draftKind = kind;
      if (kind == SecretKind.text) {
        _isRecording = false;
      }
    });
  }

  void _toggleRecording() {
    if (_isRecording) {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      setState(() => _isRecording = false);
      return;
    }

    setState(() {
      _recordingSeconds = 0;
      _isRecording = true;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingSeconds++);
      }
    });
  }

  void _throwSecret() {
    if (!_canThrow) {
      return;
    }

    final secret = _draftKind == SecretKind.text
        ? OceanSecret(
            body: _textController.text.trim(),
            kind: SecretKind.text,
            drift: 'Vừa rời khỏi bến web',
            hearts: 0,
            palette: const [0xFF5EEAD4, 0xFFFFA79A],
          )
        : OceanSecret(
            body: 'Một đoạn audio ẩn danh',
            kind: SecretKind.audio,
            drift: 'Âm thanh trôi dưới mặt nước',
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
        content: const Text('Tâm sự đã được thả vào đại dương.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0B2B2C).withValues(alpha: 0.94),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _toggleHeart(OceanSecret secret) {
    setState(() {
      secret.isLiked = !secret.isLiked;
      secret.hearts += secret.isLiked ? 1 : -1;
    });
  }

  void _surfaceRandomSecret() {
    if (_secrets.length < 2) {
      return;
    }

    final index = math.Random().nextInt(_secrets.length - 1) + 1;
    setState(() {
      final secret = _secrets.removeAt(index);
      _secrets.insert(0, secret);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AnimatedOcean(
        controller: _oceanController,
        bubbles: _bubbles,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 270,
                  child: _SidePanel(
                    total: _secrets.length,
                    audioCount: _audioCount,
                    hearts: _heartCount,
                    onRandom: _surfaceRandomSecret,
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: _OceanStream(
                    secrets: _secrets,
                    controller: _oceanController,
                    onHeart: _toggleHeart,
                  ),
                ),
                const SizedBox(width: 22),
                SizedBox(
                  width: 380,
                  child: _WebComposer(
                    draftKind: _draftKind,
                    textController: _textController,
                    recordingSeconds: _recordingSeconds,
                    isRecording: _isRecording,
                    canThrow: _canThrow,
                    onKindChanged: _changeDraftKind,
                    onToggleRecording: _toggleRecording,
                    onThrow: _throwSecret,
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

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.total,
    required this.audioCount,
    required this.hearts,
    required this.onRandom,
  });

  final int total;
  final int audioCount;
  final int hearts;
  final VoidCallback onRandom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
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
              child: Text(
                'Đại dương ẩn danh',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Một vùng biển rộng cho những điều khó nói, chỉ có text, audio và trái tim.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.64),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _StatTile(
          icon: Icons.bubble_chart_outlined,
          value: '$total',
          label: 'tâm sự đang trôi',
        ),
        const SizedBox(height: 10),
        _StatTile(
          icon: Icons.graphic_eq,
          value: '$audioCount',
          label: 'audio ẩn danh',
        ),
        const SizedBox(height: 10),
        _StatTile(
          icon: Icons.favorite_border,
          value: '$hearts',
          label: 'lượt thả tim',
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onRandom,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.travel_explore, size: 18),
            label: const Text(
              'Vớt ngẫu nhiên',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF071820).withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFA79A), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _OceanStream extends StatelessWidget {
  const _OceanStream({
    required this.secrets,
    required this.controller,
    required this.onHeart,
  });

  final List<OceanSecret> secrets;
  final AnimationController controller;
  final ValueChanged<OceanSecret> onHeart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dòng chảy hôm nay',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Không có comment, không hồ sơ công khai.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const _SoftBadge(icon: Icons.person_off_outlined, label: 'Ẩn danh'),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: secrets.length,
            itemBuilder: (context, index) {
              final secret = secrets[index];
              return _WebSecretCard(
                secret: secret,
                controller: controller,
                onHeart: () => onHeart(secret),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WebComposer extends StatelessWidget {
  const _WebComposer({
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF071820).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thả một tâm sự',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn text hoặc audio, rồi để biển giữ phần còn lại.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.58),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 14),
          if (draftKind == SecretKind.text)
            TextField(
              controller: textController,
              minLines: 7,
              maxLines: 9,
              style: const TextStyle(
                color: Colors.white,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                hintText: 'Viết điều bạn muốn gửi xuống biển...',
              ),
            )
          else
            _AudioDraft(
              recordingSeconds: recordingSeconds,
              isRecording: isRecording,
              onToggleRecording: onToggleRecording,
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
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
      height: 172,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
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
                child: Text(
                  isRecording ? 'Đang ghi âm' : 'Audio ẩn danh',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
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
          const Spacer(),
          _Waveform(active: recordingSeconds > 0 || isRecording),
          const Spacer(),
          Text(
            'Bản audio sẽ trôi đi dưới tên ẩn danh.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSecretCard extends StatelessWidget {
  const _WebSecretCard({
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
            math.sin((controller.value * math.pi * 2) + secret.seed) * 4;
        return Transform.translate(offset: Offset(0, float), child: child);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF071820).withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Color(secret.palette.first).withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(secret.palette.first).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                secret.kind == SecretKind.audio
                    ? Icons.graphic_eq
                    : Icons.bubble_chart_outlined,
                color: Color(secret.palette.first),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  secret.kind == SecretKind.audio
                      ? _AudioSecret(secret: secret)
                      : _TextSecret(secret: secret),
                  const SizedBox(height: 14),
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
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: const Color(0xFFEAF6F4),
        height: 1.5,
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFEAF6F4),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.play_arrow_rounded,
              size: 18,
              color: Color(0xFFFFA79A),
            ),
            const SizedBox(width: 8),
            Expanded(child: _Waveform(active: true)),
            const SizedBox(width: 12),
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
      8.0,
      22.0,
      13.0,
      30.0,
      16.0,
      26.0,
      10.0,
      24.0,
      14.0,
      28.0,
      9.0,
      20.0,
      12.0,
      18.0,
    ];

    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final height in heights)
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
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF020A10).withValues(alpha: 0.86),
                        const Color(0xFF06131A).withValues(alpha: 0.5),
                        const Color(0xFF020A10).withValues(alpha: 0.78),
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
      speed = math.Random().nextDouble() * 0.22 + 0.05,
      size = math.Random().nextDouble() * 4 + 2,
      opacity = math.Random().nextDouble() * 0.18 + 0.06;

  final double x;
  final double y;
  final double speed;
  final double size;
  final double opacity;
}
