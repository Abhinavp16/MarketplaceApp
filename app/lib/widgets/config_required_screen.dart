import 'package:flutter/material.dart';

/// Full-screen error shown when the app was built without an API base URL.
class ConfigRequiredApp extends StatelessWidget {
  const ConfigRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ConfigRequiredScreen(),
    );
  }
}

class ConfigRequiredScreen extends StatelessWidget {
  const ConfigRequiredScreen({super.key});

  static const String message =
      'Configuration required: build with --dart-define=API_BASE_URL=...';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF2F2),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.settings_suggest_outlined,
                  size: 64,
                  color: Color(0xFFB91C1C),
                ),
                const SizedBox(height: 20),
                const Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7F1D1D),
                  ),
                ),
                const SizedBox(height: 16),
                const SelectableText(
                  'Example (Android emulator):\n'
                  'flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5050/api/v1',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Color(0xFF450A0A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
