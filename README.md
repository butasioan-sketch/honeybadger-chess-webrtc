# Honey Badger Chess

Schach-App (Flutter) mit drei Spielarten und wahlweise 2D- oder 3D-Brett.

## Features

- **Lokal:** gegen eine einfache Negamax-KI (Schwierigkeit einstellbar) oder
  zu zweit an einem Gerät.
- **Online P2P:** Partie über WebRTC, Ende-zu-Ende-verschlüsselt
  (X25519 + ChaCha20-Poly1305), manueller Signaling-Code-Austausch, kein
  Server.
- **Visueller Chess-Cipher:** verschlüsselt Text passphrasen-basiert
  (ChaCha20-Poly1305 + PBKDF2) und kodiert ihn als Folge legaler Schachzüge;
  mit demselben Passwort wieder entschlüsselbar.
- **2D/3D:** echtes, prozedural gerendertes 3D-Brett (`flutter_cube`,
  Software-Rasterizer, keine native GL-Abhängigkeit) neben der klassischen
  2D-Ansicht. Die Wahl wird geräteweit gespeichert und gilt für lokales
  Spiel, Online-Partie und Cipher-Playback gleichermaßen.

## Setup

```bash
flutter pub get
flutter run
```

## Tests

Vor jedem Commit müssen beide grün sein:

```bash
flutter analyze
flutter test
```

## Projektstruktur

```
lib/
  main.dart                  Hauptmenü, Einstieg
  game_screen.dart           Lokales Spiel (KI oder 2 Spieler)
  online_game_screen.dart    Online-Partie über WebRTC
  connection_screen.dart     Signaling-Code-Austausch
  crypto_service.dart        E2E-Verschlüsselung des WebRTC-Kanals
  chess_ai.dart               Negamax-KI
  move_codec.dart             Zug-Kodierung für Online-Sync
  cipher_screen.dart          UI: Chess-Cipher ver-/entschlüsseln
  visual_chess_cipher.dart    Kern: Text <-> Zugfolge
  board_mode_prefs.dart       Geteilte 2D/3D-Präferenz
  widgets/chess_board_view.dart   2D-Brett
  chess3d/                    3D-Brett (Meshes, Kamera, Raycasting)
test/                         Unit- und Widget-Tests zu allem oben
```

## Lizenz

Siehe [LICENSE](LICENSE) - proprietär, alle Rechte vorbehalten.
