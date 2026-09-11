// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Material 3 умеет генерировать согласованную палитру из одного seed-цвета.
    // Одно и то же «семя» (Colors.blue) даёт нам:
    //   - light-схему:   светлые оттенки синего + тёмный текст
    //   - dark-схему:    тёмные оттенки синего + светлый текст
    // Всё это автоматически подхватится в primaryContainer / onPrimaryContainer
    // и т.д., если мы их используем (а не Colors.blue.shade50).
    final lightScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Spently',
          theme: ThemeData(useMaterial3: true, colorScheme: lightScheme),
          darkTheme: ThemeData(useMaterial3: true, colorScheme: darkScheme),
          themeMode: themeProvider.themeMode,
          home: HomeScreen(),
        );
      },
    );
  }
}