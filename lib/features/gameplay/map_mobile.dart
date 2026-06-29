import 'dart:async';
import 'dart:math' as math;

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
      if (!mounted) {
        return;
      }

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
    if (!_canThrow) {
      return;
    }

    final secret = _draftKind == SecretKind.text
        ? OceanSecret(
            body: _textController.text.trim(),
            kind: SecretKind.text,
            drift: 'Vừa thả xuống dòng sâu',
            hearts: 0,
            palette: const [0xFF5EEAD4, 0xFFFFA79A],
          )
        : OceanSecret(
            body: 'Một đoạn audio ẩn danh',
            kind: SecretKind.audio,
            drift: 'Vừa trôi khỏi bờ',
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
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
          ),
        ),
      ),
    );
  }
}

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
      8.0,
      18.0,
      12.0,
      24.0,
      15.0,
      28.0,
      10.0,
      20.0,
      14.0,
      23.0,
      9.0,
      17.0,
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
