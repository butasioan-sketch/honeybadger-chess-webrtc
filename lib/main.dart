import 'package:flutter/material.dart';
import 'game_screen.dart';

void main() => runApp(const HoneyBadgerChessApp());

class HoneyBadgerChessApp extends StatelessWidget {
  const HoneyBadgerChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Honey Badger Chess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  void _open(BuildContext context, bool vsComputer) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(vsComputer: vsComputer)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              'Honey Badger Chess',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Schach - schnell & gnadenlos',
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 48),
            _menuButton('Gegen Computer spielen', Colors.green,
                () => _open(context, true)),
            const SizedBox(height: 16),
            _menuButton('Gegen Freund spielen', Colors.blue,
                () => _open(context, false)),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 260,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(label, style: const TextStyle(fontSize: 17)),
      ),
    );
  }
}
