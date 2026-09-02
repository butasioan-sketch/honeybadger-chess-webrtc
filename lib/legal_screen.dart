import 'package:flutter/material.dart';

import 'ui/hbc_theme.dart';

/// Rechtliches-Hub: Datenschutz, Impressum, Open-Source-Lizenzen.
///
/// Datenschutz/Impressum sind noch Platzhalter-Gerüst (siehe
/// docs/legal/PRIVACY.de.md, docs/legal/IMPRESSUM.md) - echte Texte
/// liefert Jonny. Dieser Screen zeigt genau die Dateien an, die im Repo
/// liegen, nichts wird hier zusätzlich erfunden.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rechtliches')),
      body: ListView(
        children: [
          _LegalTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Datenschutz',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _LegalDocScreen(
                  title: 'Datenschutz',
                  assetPath: 'docs/legal/PRIVACY.de.md',
                ),
              ),
            ),
          ),
          _LegalTile(
            icon: Icons.description_outlined,
            label: 'Impressum',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _LegalDocScreen(
                  title: 'Impressum',
                  assetPath: 'docs/legal/IMPRESSUM.md',
                ),
              ),
            ),
          ),
          _LegalTile(
            icon: Icons.code,
            label: 'Open-Source-Lizenzen',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Honey Badger Chess',
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LegalTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: HbcColors.gold),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: HbcColors.inkMuted),
      onTap: onTap,
    );
  }
}

/// Zeigt eine der Platzhalter-Dateien aus docs/legal/ als reinen Text an -
/// bewusst kein Markdown-Rendering (keine neue Abhaengigkeit fuer ein
/// Geruest, das ohnehin noch von Jonny ersetzt wird).
class _LegalDocScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const _LegalDocScreen({required this.title, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(snapshot.data!, style: hbcMono),
          );
        },
      ),
    );
  }
}
