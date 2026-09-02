import 'package:flutter/material.dart';

import 'onboarding_prefs.dart';
import 'ui/hbc_theme.dart';

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
  });
}

// Store-konform formuliert: keine Messenger-/Anonymitaets-Versprechen,
// keine "military-grade"-Marketingfloskeln - nur, was die App wirklich
// tut. Schritt 2/3 sagen explizit "kein Messenger", damit niemand die App
// mit falschen Erwartungen installiert.
const _steps = [
  _OnboardingStep(
    icon: Icons.sports_esports,
    title: 'Schach zuerst',
    body:
        'Lokal gegen den Computer oder einen Freund am selben Gerät - '
        'klassisch in 2D oder mit einem echten 3D-Brett.',
  ),
  _OnboardingStep(
    icon: Icons.shield_outlined,
    title: 'Optional: ein sicherer Kanal zu zweit',
    body:
        'Online-Partien laufen direkt zwischen zwei Geräten (WebRTC, '
        'Ende-zu-Ende verschlüsselt) - kein Server, kein Konto. Ihr '
        'tauscht einen Code aus und bestätigt einen kurzen '
        'Sicherheitscode, bevor die Partie beginnt. Das ist kein '
        'Messenger - nur eine Schachpartie mit einem sicheren Kanal '
        'drumherum.',
  ),
  _OnboardingStep(
    icon: Icons.extension_outlined,
    title: 'Optional: der visuelle Cipher',
    body:
        'Eine Nachricht lässt sich mit einem Passwort in eine ganz '
        'normale Schachpartie verwandeln - die Züge sind die Nachricht. '
        'Auch das ist kein Messenger: du musst die Zugfolge selbst '
        'weitergeben.',
  ),
];

/// Wird einmalig beim ersten Start gezeigt (siehe onboarding_prefs.dart).
/// Baut kein neues Design-System auf - nutzt dieselben Obsidian/Gold-
/// Tokens wie der Rest der App.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    widget.onDone();
  }

  void _next() {
    if (_page == _steps.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _steps.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'Überspringen',
                  style: TextStyle(color: HbcColors.inkMuted),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(step.icon, size: 72, color: HbcColors.gold),
                        const SizedBox(height: 28),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: HbcColors.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? HbcColors.gold : HbcColors.hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(isLast ? 'Los geht\'s' : 'Weiter'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
