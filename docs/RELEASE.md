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
Online-Modus/WebRTC nur mit einem zweiten echten Gerät sinnvoll testbar
(`docs/RELEASE.md` ersetzt das nicht - siehe Checkliste unten).

## 5. GitHub Release veröffentlichen

GitHub Release ist der erste öffentliche Kanal - noch **kein** Play-Store-
Listing, keine Store-Zahlung, keine Werbung dafür. Solange Legal-Texte
(`docs/legal/`) noch Platzhalter sind und `android/key.properties` noch
nicht mit dem echten Upload-Keystore existiert, ist die App **nicht**
store-fertig - ein GitHub Release ändert daran nichts, es macht nur eine
sideloadbare APK für Tester verfügbar.

### Checkliste vor jedem Release

- [ ] `flutter analyze` + `flutter test` grün
- [ ] Release-APK mit dem echten (nicht Debug-)Keystore gebaut, siehe
      Schritte 1-3
- [ ] Sideload-Test auf mindestens einem echten Gerät (Schritt 4)
- [ ] Bei Änderungen am Online-Modus: Zwei-Geräte-Test (macht Jonny,
      siehe `docs/legal/`-Hinweis oben zu WebRTC)
- [ ] Release-Notes geschrieben (Vorlage: `docs/RELEASE_NOTES_TEMPLATE.md`)
- [ ] `pubspec.yaml`-Version passt zum geplanten Tag

### Version & Tag

`pubspec.yaml` trägt `version: X.Y.Z+B` (Name+Build-Nummer). Der Git-Tag
folgt demselben `X.Y.Z` ohne Build-Nummer, mit `v`-Präfix:

```bash
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

Solange die App weder store-fertig noch von zwei echten Geräten
durchgetestet ist, ist ein `alpha-`/`beta-`-Präfix ehrlicher als eine
nackte `1.0.0` - das ist eine Produktentscheidung, die Jonny trifft, kein
technisches Muss.

### Release erstellen (GitHub CLI)

```bash
gh release create v1.0.0 \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "v1.0.0" \
  --notes-file docs/RELEASE_NOTES_TEMPLATE.md \
  --prerelease
```

`--prerelease` bleibt gesetzt, bis die App wirklich store-fertig ist
(echtes Legal, zwei-Geräte-QA bestanden) - GitHub markiert den Release
dann sichtbar als "Pre-release", niemand stolpert versehentlich über eine
frühe Version als "das fertige Produkt". `--notes-file` braucht vorher
ausgefüllte Release-Notes (Vorlage kopieren, nicht die Vorlage selbst
hochladen).
