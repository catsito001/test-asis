import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum MicButtonState { idle, listening, thinking, speaking }

/// El botón central de la app: un círculo grande que cambia de estado
/// visualmente (inactivo, escuchando, pensando, hablando) igual que los
/// asistentes de voz que el usuario ya conoce.
class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.state, required this.onTap});

  final MicButtonState state;
  final VoidCallback onTap;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.state) {
      case MicButtonState.idle:
        return AppTheme.accent;
      case MicButtonState.listening:
        return AppTheme.accent;
      case MicButtonState.thinking:
        return AppTheme.surfaceAlt;
      case MicButtonState.speaking:
        return AppTheme.confirm;
    }
  }

  IconData get _icon {
    switch (widget.state) {
      case MicButtonState.idle:
      case MicButtonState.listening:
        return Icons.mic_rounded;
      case MicButtonState.thinking:
        return Icons.more_horiz_rounded;
      case MicButtonState.speaking:
        return Icons.volume_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pulsing = widget.state == MicButtonState.listening;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final t = pulsing ? _pulseController.value : 0.0;
          return SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (pulsing)
                  Container(
                    width: 180 + (t * 40),
                    height: 180 + (t * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color.withOpacity((1 - t) * 0.35),
                    ),
                  ),
                Container(
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _color,
                    boxShadow: [
                      BoxShadow(
                        color: _color.withOpacity(0.45),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _icon,
                    size: 64,
                    color: widget.state == MicButtonState.thinking
                        ? AppTheme.textMuted
                        : AppTheme.ink,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
