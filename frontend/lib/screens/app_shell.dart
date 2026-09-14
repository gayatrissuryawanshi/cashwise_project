import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'receivable_risk_screen.dart';
import 'forecast_screen.dart';
import 'recommendation_screen.dart';
import 'more_screen.dart';
import 'upload_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.appState});
  final AppState appState;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final pages = [
      DashboardScreen(appState: appState),
      ReceivableRiskScreen(appState: appState),
      ForecastScreen(appState: appState),
      RecommendationScreen(appState: appState),
      MoreScreen(appState: appState),
    ];

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Risk'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Forecast'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
      floatingActionButton: index == 0
          ? FloatingActionButton.extended(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx', 'xlsm'],
                  withData: true, // ensures bytes are available even on web
                );
                if (!context.mounted || result == null) return;
                final picked = result.files.single;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UploadScreen(appState: appState, file: picked),
                  ),
                );
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Excel'),
            )
          : null,
    );
  }
}
