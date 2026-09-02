<!--
  Vorlage fuer GitHub-Release-Notes - vor jedem Release kopieren und
  ausfuellen (nicht diese Datei selbst als --notes-file verwenden, sonst
  landen die Platzhalter im veroeffentlichten Release). Siehe
  docs/RELEASE.md Abschnitt 5.
-->

# Honey Badger Chess [VERSION]

## Neu in dieser Version

- [Kurzpunkte, deutsch, im Stil der Commit-Messages - was hat sich fuer
  Spieler:innen tatsaechlich geaendert?]

## Bekannte Einschränkungen (Stand [DATUM])

- Kein Play-Store-Listing - Installation nur per Sideload (APK unten).
- Datenschutzerklärung/Impressum sind noch nicht final (Gerüst siehe
  `docs/legal/`).
- Online-Modus (WebRTC) ist nur zwischen zwei Geräten getestet, die
  [Person/Umgebung] tatsächlich manuell durchgespielt hat - kein
  automatisierter Zwei-Geräte-Test.
- Verbindungsaufbau nutzt einen öffentlichen Google-STUN-Server
  (`stun.l.google.com:19302`); kein TURN-Server im Default.

## Installation (Sideload)

1. `app-release.apk` unten herunterladen.
2. Auf dem Android-Gerät „Installation aus unbekannten Quellen“ für den
   Browser/Dateimanager erlauben, der die APK öffnet (Android fragt beim
   ersten Versuch automatisch danach).
3. APK antippen und installieren.

Alternativ per ADB:

```bash
adb install -r app-release.apk
```

## Signatur

Signiert mit dem Honey Badger Chess Upload-Keystore (siehe
`docs/RELEASE.md`) - **nicht** mit Debug-Keys.
