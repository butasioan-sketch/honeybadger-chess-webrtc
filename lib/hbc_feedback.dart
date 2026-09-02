import 'package:flutter/services.dart';

/// Zentrales Zug-Feedback (Sound + Haptik) - eine Stelle statt verstreuter
/// HapticFeedback-Aufrufe in jedem Screen, damit sich alle Ereignisse
/// gleich anfuehlen und sich spaeter leicht zentral aendern lassen.
///
/// Sound nutzt bewusst nur Flutters eingebauten Systemklick
/// (`SystemSound.play`), keine gebuendelten Audio-Dateien: eigene
/// Sound-Assets zu erfinden waere derselbe Fehler wie ein erfundenes Icon
/// oder ein erfundener Rechtstext - das ist Jonnys/eines Sound-Designers
/// Entscheidung, nicht meine. Sobald echte, abgenommene Sound-Dateien
/// existieren, ersetzt eine `AudioPlayer`-Zeile pro Methode hier den
/// Systemklick, ohne dass Aufrufer irgendwo im Code angefasst werden
/// muessen. Haptik ist dagegen voll umgesetzt (kein Asset noetig,
/// Intensitaet je nach Gewicht des Ereignisses abgestuft).
class HbcFeedback {
  HbcFeedback._();

  /// Globaler An/Aus-Schalter - noch ohne UI (kein Einstellungs-Screen in
  /// diesem Block), aber vorbereitet fuer einen spaeteren.
  static bool enabled = true;

  /// Normaler, nicht schlagender Zug.
  static void move() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  /// Ein Zug, der eine gegnerische Figur schlaegt - spuerbar staerker als
  /// ein normaler Zug.
  static void capture() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  /// Zug versetzt den Gegner in Schach.
  static void check() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Partie endet (Matt, Patt, Remis, Aufgabe, Verbindungsabbruch).
  static void gameEnd() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// P2P-Sicherheitscode wurde bestaetigt - Kanal gilt jetzt als sicher.
  static void fingerprintConfirmed() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// P2P-Sicherheitscode stimmte NICHT ueberein - Warnereignis.
  static void fingerprintRejected() {
    if (!enabled) return;
    HapticFeedback.vibrate();
  }
}
