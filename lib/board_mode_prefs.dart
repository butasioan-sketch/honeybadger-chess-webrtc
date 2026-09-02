import 'package:shared_preferences/shared_preferences.dart';

/// Ob 2D oder 3D bevorzugt wird - geteilt zwischen lokalem Spiel, Online-
/// Partie und Cipher-Playback, damit die Wahl an einer Stelle auch fuer die
/// anderen gilt (wie die KI-Schwierigkeit).
const _use3DPrefsKey = 'use_3d_board';

Future<bool> loadUse3DBoard() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_use3DPrefsKey) ?? false;
}

Future<void> saveUse3DBoard(bool use3D) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_use3DPrefsKey, use3D);
}
