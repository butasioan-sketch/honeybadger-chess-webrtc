# Release-Build (Android)

Der Release-Build ist standardmäßig **gesperrt**: ohne `android/key.properties`
bricht jeder `assembleRelease`/`bundleRelease`-Task mit einer klaren
Fehlermeldung ab, statt still mit den Debug-Keys zu signieren. Das ist
Absicht (siehe `android/app/build.gradle.kts`).

## 1. Keystore erzeugen (einmalig)

```bash
keytool -genkey -v \
  -keystore ~/honeybadgerchess-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

`keytool` fragt interaktiv nach Passwort und ein paar Identitätsangaben
(Name, Organisation, Land - müssen nicht real/geprüft sein, tauchen aber
im Zertifikat auf).

**Wichtig:** Die `.jks`-Datei liegt bewusst **außerhalb** dieses Repos (hier
im Beispiel im Home-Verzeichnis) - nicht in `android/` oder sonst irgendwo
im Projektbaum. `android/.gitignore` schließt `**/*.jks`/`**/*.keystore`
zwar zusätzlich aus, aber die Datei sollte gar nicht erst in Versuchung
kommen, aus Versehen mit `git add -A` erfasst zu werden.

Diesen Keystore **sicher aufbewahren und sichern** (Passwortmanager,
verschlüsseltes Backup). Geht er verloren, kann die App auf Google Play nie
wieder unter derselben Signatur aktualisiert werden.

## 2. `key.properties` anlegen

```bash
cp android/key.properties.example android/key.properties
```

Dann `android/key.properties` mit echten Werten füllen:

```properties
storeFile=/home/jonny/honeybadgerchess-upload-keystore.jks
storePassword=<echtes Passwort>
keyAlias=upload
keyPassword=<echtes Passwort>
```

Diese Datei ist bereits in `android/.gitignore` ausgeschlossen (`key.properties`)
- sie landet nie im Repo. Keine echten Passwörter in Commit-Messages, Issues
oder Chat-Verläufen einfügen.

## 3. Bauen

```bash
flutter build apk --release       # sideloadbare APK
flutter build appbundle --release # fuer den Play-Upload (.aab)
```

Beide Befehle schlagen ohne Schritt 2 mit einer expliziten Fehlermeldung
fehl. `flutter run --release` / `flutter build apk --debug` funktionieren
immer, unabhängig von `key.properties` - die Sperre betrifft ausschließlich
echte Release-Artefakte.

## 4. Sideload testen (vor jedem GitHub Release)

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Auf einem echten Gerät starten und mindestens den lokalen Modus (gegen
Computer/Freund) einmal durchspielen, bevor die APK veröffentlicht wird.
