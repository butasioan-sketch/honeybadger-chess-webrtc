import 'package:shared_preferences/shared_preferences.dart';

const _onboardingSeenKey = 'onboarding_seen';

/// Ob das Onboarding schon einmal komplett gesehen ODER uebersprungen
/// wurde - geraeteweit gespeichert, wie die 2D/3D-Praeferenz.
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingSeenKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingSeenKey, true);
}
