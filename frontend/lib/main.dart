import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'state/app_state.dart';

void main() {
  runApp(CashWiseApp(appState: AppState()));
}

class CashWiseApp extends StatelessWidget {
  const CashWiseApp({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CashWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF8F7FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6246D8),
          brightness: Brightness.light,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          return appState.isAuthenticated
              ? AppShell(appState: appState)
              : AuthScreen(appState: appState);
        },
      ),
    );
  }
}
