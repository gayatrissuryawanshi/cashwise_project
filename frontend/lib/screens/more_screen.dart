import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'what_if_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final initials = appState.businessName
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('More', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: dark)),
            const SizedBox(height: 16),
            AppCard(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFFE9E3FF), child: Text(initials.isEmpty ? '?' : initials)),
                title: Text(appState.hasAnalysis ? appState.businessName : 'No business analyzed yet', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(appState.userEmail ?? ''),
              ),
            ),
            const SizedBox(height: 10),
            _item(
              Icons.calculate_outlined,
              'What-if Simulator',
              appState.hasAnalysis
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => WhatIfScreen(appState: appState)))
                  : null,
            ),
            const SizedBox(height: 10),
            const Text('Analysis History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            if (appState.history.isEmpty)
              const AppCard(child: Text('No past uploads yet.'))
            else
              ...appState.history.map((h) {
                final map = h as Map;
                final risk = map['risk_level'] as String?;
                return AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${map['business_name'] ?? 'Analysis #${map['analysis_id']}'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${map['created_at'] ?? ''}'),
                    trailing: risk != null
                        ? StatusPill(text: risk, safe: risk == 'LOW')
                        : null,
                    onTap: () => appState.loadAnalysis(map['analysis_id'] as int),
                  ),
                );
              }),
            const SizedBox(height: 10),
            _item(Icons.insights_outlined, 'Reports & Insights', () {}),
            _item(Icons.settings_outlined, 'Settings', () {}),
            _item(Icons.help_outline, 'Help & Support', () {}),
            const SizedBox(height: 10),
            _item(Icons.logout, 'Log Out', () => appState.logout()),
          ],
        );
      },
    );
  }

  Widget _item(IconData icon, String title, VoidCallback? onTap) => AppCard(
        child: ListTile(onTap: onTap, leading: Icon(icon, color: purple), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right)),
      );
}
