import 'package:flutter/material.dart';

/// Design-Tokens der App: Obsidian/Gold statt Material-Regenbogen. Jede
/// Modus-Wahl im Menue (lokal, online, Cipher) hatte bisher ihre eigene
/// Material-Farbe (gruen/blau/orange/lila) - das sah nach Bausatz aus,
/// nicht nach einem Siegel. Ab hier gibt es genau eine Akzentfarbe (Gold)
/// plus zwei semantische Farben (Erfolg/Gefahr), die unabhaengig vom Akzent
/// bleiben - keine weitere Farbe wird "einfach so" eingefuehrt.
class HbcColors {
  HbcColors._();

  static const Color obsidian = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF17140F);
  static const Color hairline = Color(0xFF2E2A22);

  static const Color gold = Color(0xFFC9A227);
  static const Color goldDim = Color(0xFF8C7419);

  static const Color ink = Color(0xFFF5F3EE);
  static const Color inkMuted = Color(0xFFA9A398);

  static const Color danger = Color(0xFFC1554A);
  static const Color success = Color(0xFF5FA875);
}

/// Monospace-Textstil fuer alles, was ein Code, Fingerprint oder
/// Geheimtext ist - Einladungs-/Antwort-Codes, den SAS-Fingerprint, die
/// Cipher-Zugfolge. Generic-Family "monospace" statt einer gebuendelten
/// Schriftart, damit kein Font-Asset erfunden werden muss.
const TextStyle hbcMono = TextStyle(
  fontFamily: 'monospace',
  color: HbcColors.ink,
);

ThemeData buildHbcTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: HbcColors.obsidian,
    colorScheme: base.colorScheme.copyWith(
      primary: HbcColors.gold,
      secondary: HbcColors.gold,
      surface: HbcColors.surface,
      error: HbcColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: HbcColors.obsidian,
      foregroundColor: HbcColors.ink,
      elevation: 0,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: HbcColors.ink,
      displayColor: HbcColors.ink,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HbcColors.gold,
        foregroundColor: HbcColors.obsidian,
        disabledBackgroundColor: HbcColors.hairline,
        disabledForegroundColor: HbcColors.inkMuted,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HbcColors.ink,
        side: const BorderSide(color: HbcColors.hairline),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: HbcColors.gold),
    ),
    iconTheme: const IconThemeData(color: HbcColors.gold),
    dividerColor: HbcColors.hairline,
    inputDecorationTheme: const InputDecorationTheme(
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: HbcColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: HbcColors.gold),
      ),
    ),
  );
}
