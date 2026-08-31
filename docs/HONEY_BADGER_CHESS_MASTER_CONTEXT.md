> ⚠️ **HINWEIS — DAS HIER IST EINE ZUKUNFTSVISION, KEIN AKTUELLER STAND**
>
> Dieses Dokument wurde von Jonny aus einer anderen KI-Sitzung (laut Text
> selbst: "ChatGPT, Grok oder andere Coding-Agenten") hierher kopiert. Es
> beschreibt eine sehr viel größere Produktidee (3D-Schachfiguren, visuelle
> Cipher-Sprache über Schachzüge, I2P-Anonymisierungsnetzwerk, Encoder/
> Decoder/Dashboard-Screens, Automatisierungs-Scripts wie `hbc_push.sh`).
>
> **Nichts davon existiert im tatsächlichen Code dieses Repos.** Geprüft am
> 2026-08-31:
> - Repo/Branch im Dokument (`honey_badger_chess`, Branch `main`) stimmen
>   nicht mit dem echten Remote überein (`honeybadger-chess-webrtc`, Branch
>   `spur-b-webrtc`).
> - Keine der genannten Dateien existiert: `scripts/hbc_push.sh`,
>   `scripts/hbc_status.sh`, `lib/core/rendering/piece_renderer.dart`,
>   `i2p_overlay_service.dart`, `chess_codec.dart`, `dashboard_screen.dart`
>   usw. wurden auf diesem Rechner nirgends gefunden.
> - Der tatsächliche Stand: eine 2D-Flutter-Schach-App mit Unicode-Glyphen
>   als Figuren, lokalem Negamax-KI-Gegner, und WebRTC-P2P-Multiplayer mit
>   Ende-zu-Ende-Verschlüsselung (kein I2P, kein 3D). Details im laufenden
>   Statuslog: [`../../../Schreibtisch/MeinVault/Projekte/HoneyBadgerChess.md`]
>   bzw. der Commit-Historie dieses Repos.
>
> Diese Datei ist also **Produktvision/Ideensammlung für eine mögliche
> Zukunft**, nicht Beschreibung des Ist-Zustands. Jede künftige KI-Sitzung
> (auch ich selbst später) sollte zuerst `git log`, `flutter analyze` und
> die tatsächlichen Dateien in `lib/` prüfen, bevor sie sich auf Aussagen
> in diesem Dokument verlässt.

---

# 🦡 HONEY BADGER CHESS
# MASTER PROJECT CONTEXT / AI HANDOFF
# ============================================================
# Zweck:
# Diese Datei ist der dauerhafte Projektkontext für zukünftige
# KI-Sitzungen (ChatGPT, Grok oder andere Coding-Agenten).
#
# Eine neue KI soll diese Datei ZUERST lesen, bevor sie Änderungen
# am Projekt vornimmt.
# ============================================================


# ============================================================
# 1. PROJEKTIDENTITÄT
# ============================================================

Projekt:
Honey Badger Chess

Entwickler:
Jonny

Lokaler Projektpfad:
~/honey_badger_chess

GitHub:
https://github.com/butasioan-sketch/honey_badger_chess

GitHub Username:
butasioan-sketch

Repository:
honey_badger_chess

Hauptbranch:
main

Aktueller Entwicklungsstatus:
Technical Alpha / Early Alpha


# ============================================================
# 2. WAS IST HONEY BADGER CHESS?
# ============================================================

Honey Badger Chess begann als Schach-App, hat sich aber zu einem
größeren Konzept entwickelt.

Die langfristige Vision ist:

Eine visuelle, verschlüsselte, offline-first Kommunikations-
und Session-Plattform, bei der Schach als visuelle Sprache,
Interface und Cipher-Transport verwendet wird.

Schach ist dabei nicht nur ein Spielbrett.

Schach dient als:

- visuelle Codierung
- Cipher-Sprache
- Transportdarstellung
- Playback-System
- Session-Interface
- mögliche Grundlage für P2P-Kommunikation


# ============================================================
# 3. DESIGN-VISION
# ============================================================

Die Anwendung soll hochwertig und professionell wirken.

Visuelle Richtung:

- Premium
- dunkel
- Cyber / Intelligence
- Gold-Akzente
- taktische Atmosphäre
- hochwertiges Schachbrett
- realistische 3D-Schachfiguren
- dramatische Beleuchtung
- hochwertige Materialien
- Kamerabewegungen
- 360-Grad-Betrachtung
- cinematic presentation

Zielgefühl:

Nicht wie eine einfache Flutter-Schach-App.

Sondern wie:

"ein hochwertiges digitales Schach-/Cipher-Terminal"


# ============================================================
# 4. WICHTIGSTE ENTWICKLUNGSREGEL
# ============================================================

Die Verschlüsselungsfunktionen dürfen NICHT durch die 3D-
Entwicklung kaputtgemacht werden.

Architekturprinzip:

CIPHER CORE
    ↓
SESSION
    ↓
VISUAL MOVE DATA
    ↓
BOARD / PLAYBACK
    ↓
3D RENDERING

Rendering ist eine Darstellungsschicht.

Die Verschlüsselungslogik muss davon unabhängig bleiben.


# ============================================================
# 5. BEREITS IMPLEMENTIERTE FUNKTIONEN
# ============================================================

## 5.1 Offline Cipher

Vorhanden:

- Encrypt
- Decrypt
- Visual Chess Cipher
- Move Encoding
- Move Decoding
- Session-Fingerprint
- Session Envelope
- Offline-first Konzept


## 5.2 Chess Encoding

Vorhandene Services:

- chess_codec.dart
- chess_code_service.dart
- offline_chess_cipher.dart
- crypto_chess_cipher.dart
- encrypted_session_service.dart


## 5.3 Visual Cipher

Die verschlüsselten Informationen können als
Schachzüge dargestellt werden.

Konzept:

Text
  ↓
Cipher
  ↓
Chess Moves
  ↓
Visual Board
  ↓
Playback


## 5.4 Playback

Vorhanden:

- PLAY
- STOP
- SLOW
- FAST

Playback soll die verschlüsselten Schachzüge visuell
auf dem Brett abspielen.


# ============================================================
# 6. CAMERA SYSTEM
# ============================================================

Das Board besitzt bereits eine Kamera-/Perspektiv-Logik.

Vorhandene Funktionen:

- Rotation
- Tilt
- Camera Presets
- White / Black Perspective
- Reset View

Bedienelemente:

CAM
TILT+
TILT-
Rotation
RESET

Langfristiges Ziel:

Eine echte 3D-Orbit-Kamera.

Der Benutzer soll das Brett frei aus verschiedenen
Winkeln betrachten können.

Ziel:

360° Camera Orbit


# ============================================================
# 7. AKTUELLER 3D-STATUS
# ============================================================

SEHR WICHTIG:

Die aktuelle Darstellung ist noch KEIN echtes hochwertiges
3D-Schachmodell.

Der aktuelle Zustand ist:

Hybrid / 2.5D / Pseudo-3D

Es existieren:

- Tiefenillusion
- Schatten
- Lichtsimulation
- Perspektive
- Layering
- Rendering-Abstraktion

Aber noch nicht vollständig:

- echte 3D Meshes
- echte GLB-Modelle
- echtes Materialsystem
- echtes Shadow Mapping
- vollständige 3D Scene
- echte Orbit Camera


# ============================================================
# 8. 3D-HAUPTZIEL
# ============================================================

Das wichtigste nächste große Entwicklungsziel ist:

ECHTES HOCHWERTIGES 3D-SCHACH.

Nicht nur ein bisschen 3D.

Zielqualität:

vergleichbar mit modernen hochwertigen Online-Schach-
Darstellungen.

Jede einzelne Figur soll ein echtes 3D-Modell sein.

Benötigt werden:

King
Queen
Rook
Bishop
Knight
Pawn

Für beide Seiten:

White
Black


# ============================================================
# 9. GEPLANTE 3D ASSETS
# ============================================================

Geplante Asset-Struktur:

assets/3d/

    pieces/
        king.glb
        queen.glb
        rook.glb
        bishop.glb
        knight.glb
        pawn.glb

    boards/
    materials/
    environment/

Die App besitzt bereits eine Asset-Mapping-Schicht:

piece_model_assets.dart


# ============================================================
# 10. RENDERING ARCHITEKTUR
# ============================================================

Rendering-Dateien:

lib/core/rendering/

Geplante / vorhandene Komponenten:

- piece_renderer.dart
- piece_render_mode.dart
- piece_model_assets.dart
- model_asset_status.dart

Konzept:

PieceRenderer
    ↓
Render Mode
    ↓
Unicode / Pseudo3D / Real3D

Langfristig:

PieceRenderer
    ↓
Real 3D Scene
    ↓
GLB / GLTF Mesh
    ↓
Materials
    ↓
Lighting
    ↓
Shadows
    ↓
Camera


# ============================================================
# 11. 360-GRAD-KAMERA
# ============================================================

Langfristiges Ziel:

Der Benutzer soll die Schachfiguren und das gesamte Brett
aus allen Richtungen betrachten können.

Zielsteuerung:

- horizontal drehen
- vertikal neigen
- zoom
- orbit
- presets
- reset

Optional später:

- automatische cinematic camera
- move-follow camera
- piece focus camera
- replay camera
- close-up
- board overview


# ============================================================
# 12. REALISTISCHE MATERIALIEN
# ============================================================

Zukünftiges Materialsystem:

Weiße Figuren:

- ivory
- polished ceramic / marble-like material
- subtle reflections

Schwarze Figuren:

- dark obsidian / ebony appearance
- controlled reflections

Gold:

- UI accent
- optional board details
- optional cinematic highlights

Brett:

- hochwertige Holz-/Carbon-/Metal-Optik
- je nach Theme

Wichtig:

Materialien sollen hochwertig aussehen, nicht wie einfache
Flutter-Farbflächen.


# ============================================================
# 13. LICHTSYSTEM
# ============================================================

Für echtes 3D später:

- key light
- fill light
- rim light
- ambient light
- environment light

Ziel:

Die Figuren sollen echte Formtiefe besitzen.

Besonders wichtig:

- Highlights
- Kontakt-Schatten
- Kanten
- Materialreflexion
- Figurensilhouette


# ============================================================
# 14. SCHATTEN
# ============================================================

Ziel:

Echte Schatten zwischen:

- Figur und Brett
- Figur und Figur
- Brett und Umgebung

Schatten sollen zur Kamera und Lichtquelle passen.


# ============================================================
# 15. I2P KONZEPT
# ============================================================

Langfristig soll Honey Badger Chess optional über ein
anonymes Overlay-Netzwerk kommunizieren.

Inspiration:

I2P / Invisible Internet Project

Ziel:

Anonyme Kommunikation.

Eigenschaften:

- dezentral
- kein zentraler Server als Pflicht
- verschlüsselte Kommunikation
- Tunnel
- P2P
- optionaler Relay-Fallback


# ============================================================
# 16. I2P ARCHITEKTUR
# ============================================================

Geplante Ebenen:

1. Local Offline Mode

2. I2P Overlay Mode

3. Future Relay Mode


## Local Offline Mode

- keine Server
- Cipher Profile
- Session Code
- Burn / TTL
- Visual Chess Cipher


## I2P Overlay Mode

- Kommunikation über lokalen I2P Router
- keine direkte IP-Kommunikation zwischen Nutzern
- Tunnel-basierte Nachrichten
- private Match Rooms
- Cipher Sessions


## Future Relay Mode

Optional.

Nur verschlüsselte Payloads.

Kein Klartext.


# ============================================================
# 17. I2P MESSAGE ENVELOPE
# ============================================================

Vorhanden:

i2p_overlay_service.dart

session_envelope_service.dart

Envelope enthält konzeptionell:

- sessionFingerprint
- payload
- timestamp
- routeHint
- burned

Der Envelope wird serialisiert und kann als transportierbare
Payload verwendet werden.


# ============================================================
# 18. NETWORKING STATUS
# ============================================================

WICHTIG:

I2P ist momentan noch NICHT vollständig implementiert.

Aktuell vorhanden:

- Architektur
- Envelope
- Transport-Konzept
- Router-Prüfung
- Vorbereitung

Noch offen:

- echter I2P Transport
- Destination Exchange
- echte Tunnel-Kommunikation
- P2P Session Synchronisation
- Relay Infrastruktur


# ============================================================
# 19. SECURITY PHILOSOPHY
# ============================================================

Grundprinzip:

Keine unnötige zentrale Infrastruktur.

Offline muss funktionieren.

Netzwerk ist optional.

Klartext soll nicht unnötig transportiert werden.

Cipher und Transport sollen getrennt sein.

Architektur:

PLAINTEXT
    ↓
ENCRYPTION
    ↓
SESSION ENVELOPE
    ↓
TRANSPORT
    ↓
I2P / RELAY / OFFLINE


# ============================================================
# 20. UI
# ============================================================

Hauptbereich:

Dashboard

Wichtige Bereiche:

- Encoder
- Decoder
- Board
- Chat
- Profile

Wichtige Dateien:

lib/features/dashboard/dashboard_screen.dart
lib/features/encoder/encoder_screen.dart
lib/features/decoder/decoder_screen.dart
lib/features/board_screen.dart
lib/features/chat_screen.dart
lib/features/profile_screen.dart


# ============================================================
# 21. BOARD
# ============================================================

Wichtigste Datei:

lib/widgets/chess_board_widget.dart

Der Board-Widget ist verantwortlich für:

- Board
- Figuren
- visuelle Moves
- Camera
- Tilt
- Rotation
- Playback
- Controls


# ============================================================
# 22. BOARD CONTROLS
# ============================================================

Geplante/sichtbare Controls:

CAMERA:

⟲
⟳
CAM
TILT+
TILT-
WHITE / BLACK
RESET

CIPHER:

PLAY
STOP
SLOW
FAST

Weitere visuelle Controls können später folgen.


# ============================================================
# 23. VISUAL CIPHER STATUS
# ============================================================

Geplanter Status:

VISUAL CIPHER READY · PLAY drücken · XX Moves

Damit soll der Benutzer erkennen:

Die Verschlüsselung wurde erfolgreich erzeugt
und kann visuell abgespielt werden.


# ============================================================
# 24. BEKANNTE FEHLER, DIE BEREITS BEHOBEN WURDEN
# ============================================================

## google_fonts

Problem:

google_fonts wurde importiert, obwohl das Package nicht
verfügbar war.

Fehler:

Couldn't resolve package 'google_fonts'

Lösung:

GoogleFonts entfernt.

Aktuell:

AppTheme.darkTheme

wird verwendet.


## Invalid depfile

Problem:

Flutter meldete:

Invalid depfile:
.dart_tool/flutter_build/.../kernel_snapshot_program.d

Lösung:

Flutter Cache bereinigen:

rm -rf .dart_tool
rm -rf build
flutter clean
flutter pub get


## Rendering Import Warning

Nicht verwendete Imports wurden bereinigt.


## Playback Controls

Problem:

PLAY / TILT / CAMERA waren teilweise wegen der unteren
Control-Zone nicht sichtbar.

Ziel:

Controls in robuste, sichtbare Zeilen aufteilen.


# ============================================================
# 25. FLUTTER
# ============================================================

Bekannter funktionierender Stand:

Flutter 3.41.9

Channel:
stable

Getestete Plattform:

Linux desktop

Device:

Linux x64

Auch erkannt:

Chrome


# ============================================================
# 26. AKTUELLER BUILD STATUS
# ============================================================

flutter analyze:

NO ISSUES FOUND

Linux Build:

SUCCESSFUL

Encrypt:

WORKING

Decrypt:

WORKING

GitHub:

WORKING

Playback:

IMPLEMENTED

Camera:

IMPLEMENTED

Tilt:

IMPLEMENTED

Pseudo 3D:

IMPLEMENTED

I2P:

ARCHITECTURE / PREPARATION ONLY

Real 3D:

NOT YET COMPLETE


# ============================================================
# 27. GIT / GITHUB
# ============================================================

GitHub Username:

butasioan-sketch

Repository:

honey_badger_chess

Remote:

git@github.com:butasioan-sketch/honey_badger_chess.git

Branch:

main

Push funktioniert.

Beispiel:

git push -u origin main --tags


# ============================================================
# 28. GIT AUTOMATION
# ============================================================

Vorhanden:

scripts/hbc_push.sh

Verwendung:

bash scripts/hbc_push.sh

Das Script:

- fragt Commit Message ab
- git add .
- git commit
- git push


# ============================================================
# 29. BACKUP
# ============================================================

Backups befinden sich unter:

.hbc_backups/

Backup Script:

scripts/hbc_backup_run.sh


# ============================================================
# 30. STATUS SCRIPT
# ============================================================

Status Script:

scripts/hbc_status.sh

Verwendung:

bash scripts/hbc_status.sh


# ============================================================
# 31. LAGEBERICHT
# ============================================================

Lagebericht Script:

scripts/hbc_lagebericht.sh

Verwendung:

bash scripts/hbc_lagebericht.sh

Es sammelt:

- Flutter Version
- Git Status
- Branch
- Remote
- lib Dateien
- Assets
- Scripts
- Rendering
- Network
- Controls
- flutter analyze


# ============================================================
# 32. UI CHECK
# ============================================================

UI Check:

scripts/hbc_ui_check.sh

Soll prüfen:

PLAY
STOP
TILT
CAM
VISUAL CIPHER


# ============================================================
# 33. DOKUMENTATION
# ============================================================

Wichtige Dokumentation:

docs/I2P_ARCHITECTURE.md

Weitere wichtige Projektdatei:

docs/NEXT_SESSION_PLAN.md


# ============================================================
# 34. ENTWICKLUNGSREGEL FÜR ZUKÜNFTIGE KI
# ============================================================

BEVOR CODE GEÄNDERT WIRD:

1. Projektstatus prüfen.
2. git status prüfen.
3. flutter analyze ausführen.
4. vorhandene Architektur lesen.
5. keine funktionierenden Cipher-Funktionen unnötig ändern.
6. Änderungen klein und testbar machen.
7. nach jeder größeren Änderung:
   flutter analyze
8. anschließend Linux Build testen.
9. erst danach committen/pushen.


# ============================================================
# 35. WICHTIGE REGEL:
# KEINE BLINDEN DATEI-REWRITES
# ============================================================

Nicht einfach komplette Dateien überschreiben, wenn nicht
klar ist, wie die aktuelle Datei aufgebaut ist.

Vor Änderungen:

sed -n '1,240p' DATEI

oder:

grep -n "funktion" DATEI


# ============================================================
# 36. ENTWICKLUNGSREIHENFOLGE
# ============================================================

EMPFOHLENE REIHENFOLGE:

PHASE 1
-------
Stabilität

- Encrypt
- Decrypt
- Session
- Playback
- Board
- Camera
- Controls


PHASE 2
-------
ECHTES 3D

- GLB Assets
- Scene
- Camera
- Lighting
- Materials
- Shadows


PHASE 3
-------
3D Animation

- Piece movement
- smooth interpolation
- capture animation
- camera follow
- cinematic replay


PHASE 4
-------
UI Premium Polish

- transitions
- effects
- responsive controls
- HUD
- status indicators


PHASE 5
-------
Networking

- I2P integration
- P2P
- encrypted sessions
- relay fallback


PHASE 6
-------
Production

- security audit
- performance
- mobile
- packaging
- release


# ============================================================
# 37. PRIORITÄT JETZT
# ============================================================

HÖCHSTE PRIORITÄT:

REALISTISCHE 3D-SCHACHFIGUREN.

Nicht sofort I2P bauen.

Erst das visuelle Kernprodukt hochwertig machen.

Ziel:

Wenn der Benutzer die App öffnet, soll das Schachbrett
sofort hochwertig und professionell wirken.


# ============================================================
# 38. 3D KONKRETE TODO-LISTE
# ============================================================

[ ] echte GLB Modelle beschaffen/erstellen
[ ] King GLB
[ ] Queen GLB
[ ] Rook GLB
[ ] Bishop GLB
[ ] Knight GLB
[ ] Pawn GLB

[ ] White Material
[ ] Black Material

[ ] 3D Scene
[ ] Board Mesh
[ ] Lighting
[ ] Shadows
[ ] Environment

[ ] Orbit Camera
[ ] Zoom
[ ] Tilt
[ ] 360° Rotation

[ ] Piece Selection
[ ] Piece Highlight
[ ] Move Animation

[ ] Capture Animation
[ ] Playback Camera
[ ] Cinematic Camera


# ============================================================
# 39. PERFORMANCE
# ============================================================

3D darf nicht auf Kosten der gesamten App gehen.

Achten auf:

- GPU performance
- texture sizes
- polygon count
- memory
- loading times
- animation frame rate

Später:

Asset compression.

LOD:

Level of Detail


# ============================================================
# 40. ARCHITEKTUR-ZIEL
# ============================================================

Zielarchitektur:

                    HONEY BADGER CHESS
                           |
             +-------------+-------------+
             |                           |
         CIPHER CORE                 3D ENGINE
             |                           |
       Encryption                    Scene
       Decryption                    Camera
       Sessions                      Lighting
       Encoding                      Materials
             |                       Animation
             |                           |
             +-------------+-------------+
                           |
                     VISUAL BOARD
                           |
             +-------------+-------------+
             |                           |
         OFFLINE                       NETWORK
                                      |
                                  I2P / P2P
                                      |
                                   RELAY


# ============================================================
# 41. NICHT VERGESSEN
# ============================================================

Das Projekt soll OFFLINE-FIRST bleiben.

Das bedeutet:

Die App muss auch ohne Internet sinnvoll funktionieren.

I2P ist ein optionaler Kommunikationslayer.

Nicht umgekehrt.


# ============================================================
# 42. ZUKÜNFTIGE PRODUKTIDEEN
# ============================================================

Mögliche spätere Funktionen:

- private chess rooms
- encrypted rooms
- session QR
- session code
- visual key exchange
- burn sessions
- TTL
- anonymous rooms
- I2P rooms
- encrypted chat
- visual message replay
- chess-based authentication
- cinematic replay
- spectator mode
- training mode


# ============================================================
# 43. TESTPROTOKOLL
# ============================================================

Nach jeder wichtigen Änderung:

cd ~/honey_badger_chess

flutter analyze

flutter run -d linux

Dann testen:

1. App startet.
2. Encoder funktioniert.
3. Encrypt funktioniert.
4. Decoder funktioniert.
5. Decrypt funktioniert.
6. Board zeigt Moves.
7. PLAY funktioniert.
8. STOP funktioniert.
9. CAM funktioniert.
10. TILT funktioniert.
11. Rotation funktioniert.
12. Keine UI Overflow Errors.
13. Keine Dart Exceptions.


# ============================================================
# 44. GIT COMMIT PROTOKOLL
# ============================================================

Nach erfolgreichem Test:

bash scripts/hbc_push.sh

Commit Message beschreiben:

- WAS geändert wurde
- nicht nur "update"

Beispiele:

stable playback camera controls

add real 3d piece renderer

integrate glb chess pieces

improve orbit camera

add cinematic lighting


# ============================================================
# 45. AKTUELLER ENTWICKLUNGSPLAN
# ============================================================

JETZT:

1. Projekt stabilisieren.
2. UI Controls prüfen.
3. Encrypt/Decrypt nicht verändern.
4. echtes 3D vorbereiten.
5. GLB Pipeline implementieren.
6. 3D-Kamera implementieren.
7. Materialien.
8. Licht.
9. Schatten.
10. Animation.
11. erst danach Networking erweitern.


# ============================================================
# 46. KI-HANDOFF
# ============================================================

Wenn eine neue KI dieses Projekt übernimmt:

Sie soll NICHT davon ausgehen, dass alles fertig ist.

Sie soll NICHT die Cipher-Architektur neu erfinden.

Sie soll zuerst:

cd ~/honey_badger_chess

git status

flutter analyze

bash scripts/hbc_status.sh


Danach die relevanten Dateien lesen.

Besonders:

lib/widgets/chess_board_widget.dart

lib/features/dashboard/dashboard_screen.dart

lib/core/services/

lib/core/network/

lib/core/rendering/


# ============================================================
# 47. ZIELDEFINITION
# ============================================================

FINAL VISION:

Honey Badger Chess soll eine hochwertige, visuelle,
verschlüsselte Kommunikationsplattform werden.

Der Benutzer soll:

1. eine Session erstellen können.
2. Text verschlüsseln können.
3. die Verschlüsselung als Schachzüge sehen.
4. diese Schachzüge visuell abspielen können.
5. das Brett frei in 3D betrachten können.
6. realistische 3D-Schachfiguren sehen.
7. Sessions offline verwenden können.
8. später optional anonym über I2P kommunizieren können.
9. verschlüsselte Nachrichten über Sessions austauschen können.

Die Kombination aus:

SCHACH
+
CIPHER
+
3D
+
OFFLINE
+
OPTIONALEM ANONYMEN NETWORKING

ist der Kern des Produkts.


# ============================================================
# 48. MASTER PRIORITY
# ============================================================

Wenn unklar ist, was als Nächstes gemacht werden soll:

PRIORITÄT 1:
Stabilität

PRIORITÄT 2:
ECHTES 3D

PRIORITÄT 3:
3D Camera / 360°

PRIORITÄT 4:
3D Animation

PRIORITÄT 5:
UI Polish

PRIORITÄT 6:
I2P / P2P

PRIORITÄT 7:
Production Hardening


# ============================================================
# END OF MASTER CONTEXT
# ============================================================

Dieses Dokument ist der zentrale AI-Handoff für
Honey Badger Chess.

Bei zukünftigen Sessions zuerst diese Datei lesen.

END.
