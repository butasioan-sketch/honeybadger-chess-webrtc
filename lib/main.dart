import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_screen.dart';
import 'connection_screen.dart';
import 'cipher_screen.dart';
import 'support_url.dart';
import 'ui/hbc_theme.dart';

void main() => runApp(const HoneyBadgerChessApp());

class HoneyBadgerChessApp extends StatelessWidget {
  const HoneyBadgerChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Honey Badger Chess',
      debugShowCheckedModeBanner: false,
      theme: buildHbcTheme(),
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  void _openGame(BuildContext context, bool vsComputer) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(vsComputer: vsComputer)),
    );
  }

  void _openConnection(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ConnectionScreen()));
  }

  void _openCipher(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CipherScreen()));
  }

  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HbcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Honey Badger Chess unterstützen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Die App hat keine Serverkosten (alles laeuft direkt '
              'zwischen den Geraeten) und ist kostenlos. Wer trotzdem '
              'etwas dalassen will:',
              style: TextStyle(color: HbcColors.inkMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HbcColors.obsidian,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: HbcColors.hairline),
              ),
              child: SelectableText(supportUrl, style: hbcMono),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: supportUrl));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Link kopiert'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Link kopieren'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag, size: 72, color: HbcColors.gold),
            const SizedBox(height: 20),
            const Text(
              'Honey Badger Chess',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Schach - schnell & gnadenlos',
              style: TextStyle(fontSize: 14, color: HbcColors.inkMuted),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 300,
              child: Column(
                children: [
                  _MenuRow(
                    label: 'Gegen Computer spielen',
                    onTap: () => _openGame(context, true),
                  ),
                  const SizedBox(height: 10),
                  _MenuRow(
                    label: 'Gegen Freund spielen',
                    onTap: () => _openGame(context, false),
                  ),
                  const SizedBox(height: 10),
                  _MenuRow(
                    label: 'Online verbinden',
                    onTap: () => _openConnection(context),
                  ),
                  const SizedBox(height: 10),
                  _MenuRow(
                    label: 'Visueller Cipher',
                    onTap: () => _openCipher(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => _showSupportSheet(context),
              icon: const Icon(Icons.favorite_border, size: 16),
              label: const Text('Unterstützen'),
              style: TextButton.styleFrom(foregroundColor: HbcColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine "Terminal-Zeile" im Hauptmenue statt eines eigenfarbigen
/// Material-Buttons pro Modus - eine einzige Optik fuer alle vier
/// Eintraege, Gold als einzige Akzentfarbe statt gruen/blau/orange/lila.
class _MenuRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MenuRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HbcColors.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: HbcColors.hairline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Text(
                '>',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: HbcColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 16)),
              ),
              const Icon(
                Icons.chevron_right,
                color: HbcColors.inkMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
