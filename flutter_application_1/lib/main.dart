import 'package:flutter/material.dart';
import 'splash_root.dart';

void main() => runApp(const KnockSenseApp());

class KnockSenseApp extends StatelessWidget {
  const KnockSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = const Color(0xFFF7F8FB);
    return MaterialApp(
      title: 'KnockSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF4C21A),
          brightness: Brightness.light,
          background: bg,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(height: 1.35),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const SplashRoot(),
    );
  }
}
