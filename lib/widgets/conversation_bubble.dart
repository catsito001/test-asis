import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Muestra una línea de la conversación (lo que dijiste o lo que
/// respondió Asiste) debajo del botón de micrófono.
class ConversationBubble extends StatelessWidget {
  const ConversationBubble({
    super.key,
    required this.text,
    required this.isAsiste,
  });

  final String text;
  final bool isAsiste;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isAsiste ? AppTheme.surfaceAlt : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isAsiste
            ? Border.all(color: AppTheme.confirm.withOpacity(0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAsiste ? 'Asiste' : 'Tú',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isAsiste ? AppTheme.confirm : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
