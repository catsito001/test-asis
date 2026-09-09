import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidad visual de Asiste: tinta nocturna + ámbar cálido para el
/// micrófono/CTA principal, y un verde-azulado para confirmaciones y
/// días marcados en el calendario. Pensado para un asistente que puede
/// usarse a cualquier hora, incluso de noche, sin deslumbrar.
class AppTheme {
  AppTheme._();

  static const Color ink = Color(0xFF14161F);
  static const Color surface = Color(0xFF1E2130);
  static const Color surfaceAlt = Color(0xFF262A3D);
  static const Color textPrimary = Color(0xFFEDEBE4);
  static const Color textMuted = Color(0xFFA7A8B8);
  static const Color accent = Color(0xFFF2A93B);
  static const Color accentSoft = Color(0xFFFBD9A0);
  static const Color confirm = Color(0xFF2FBF9F);
  static const Color danger = Color(0xFFE5605A);

  static ThemeData theme() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: ink,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: confirm,
        surface: surface,
        error: danger,
        onPrimary: ink,
        onSurface: textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: ink,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      // Si tu versión de Flutter es más antigua y "CardThemeData" no
      // existe, cámbialo por "CardTheme" (mismo constructor).
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: surfaceAlt, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : textMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textMuted),
      ),
      dividerColor: surfaceAlt,
    );
  }
}
