# Datenschutzerklärung (Gerüst — noch keine finale Fassung)

**Dieses Dokument ist ein Platzhalter-Gerüst, keine rechtsgültige
Datenschutzerklärung.** Der Architekt (Claude) erfindet laut Auftrag
keine Datenschutz-Fließtexte - die echten Formulierungen liefert Jonny.
Diese Datei zeigt nur die Struktur und listet die Fakten auf, die der
spätere Text abdecken muss. Die App zeigt diese Datei unverändert im
Menüpunkt „Rechtliches" an, bis Jonny sie ersetzt.

## Verantwortlicher

[ANBIETER]
[ADRESSE]
[EMAIL]

## Fakten, die der Text abdecken muss

Diese Liste ist technisch geprüft (aus dem Code, Stand HEAD `e2d575f`),
aber selbst noch kein Fließtext - Jonny formuliert daraus die eigentliche
Erklärung:

- Keine Registrierung, keine Accounts, keine Nutzerkonten.
- Kein Backend/Server: Schachpartien laufen direkt Peer-to-Peer über
  WebRTC (verschlüsselter DataChannel, X25519-Schlüsseltausch +
  ChaCha20-Poly1305, Sitzungsschlüssel per HKDF an den Handschlag
  gebunden).
- Der Verbindungsaufbau nutzt einen öffentlichen STUN-Server von
  Google (`stun.l.google.com:19302`) - das ist der einzige externe
  Dienst, den die App kontaktiert. [STUN-HINWEIS: hier erklären, dass
  STUN beim Verbindungsaufbau die öffentliche IP-Adresse beider
  Geräte sieht, aber keine Gesprächsinhalte/Zugdaten - die sind
  Ende-zu-Ende verschlüsselt]
- Der Einladungs-/Antwort-Code, den Nutzer manuell kopieren und
  teilen (z.B. per Messenger), enthält Netzwerk-Informationen (u.a.
  lokale IP-Adressen des Geräts als ICE-Kandidaten) - darauf weist
  die App direkt beim Code selbst schon hin.
- Ein sechsstelliger Sicherheitscode (Fingerprint) muss von beiden
  Seiten außerhalb der App bestätigt werden, bevor Chat/Partie
  beginnt - das ist ein Schutzmechanismus, keine Datenerhebung.
- Keine Analytics, kein Tracking, keine Werbung, kein Crash-Reporting
  an Dritte.
- Einstellungen (KI-Schwierigkeit, 2D/3D-Anzeigepräferenz) werden nur
  lokal auf dem Gerät gespeichert (`shared_preferences`), nie
  übertragen.
- Cipher-Passwörter werden nirgends gespeichert oder übertragen - nur
  lokal und temporär im Arbeitsspeicher zur Ver-/Entschlüsselung
  verwendet.

## Rechte der Nutzer

[Platzhalter - hängt von Anbieter/Zuständigkeit/Rechtsform ab, liefert
Jonny]

## Kontakt für Datenschutzanfragen

[EMAIL]
