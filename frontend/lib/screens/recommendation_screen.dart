import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'what_if_screen.dart';

class RecommendationScreen extends StatelessWidget {
  const RecommendationScreen({super.key, required this.appState});
  final AppState appState;

  static const _icons = {
    'inventory': Icons.inventory_2_outlined,
    'marketing': Icons.campaign_outlined,
    'equipment': Icons.build_outlined,
    'equipment_repair': Icons.build_outlined,
    'buffer': Icons.savings_outlined,
    'business_buffer': Icons.savings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final allocation = appState.recommendedAllocation;
        final funded = allocation.entries.where((e) => (e.value as num) > 0).toList()
          ..sort((a, b) => (b.value as num).compareTo(a.value as num));

        return Scaffold(
          appBar: AppBar(title: const Text('AI Cash Recommendation'), backgroundColor: bg),
          body: !appState.hasAnalysis
              ? const Center(child: Text('Upload an Excel file to get a recommendation.'))
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    AppCard(
                      child: Column(
                        children: [
                          _Line('Current Cash', rupees(appState.currentCash.round())),
                          _Line('Required Reserve', rupees(appState.requiredReserve.round())),
                          const Divider(height: 26),
                          _Line('Safe to Deploy', rupees(appState.safeToDeploy.round()), strong: true, color: green),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Recommended Deployment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        if (funded.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No allocation is recommended right now - it\'s safer to hold everything in reserve.'),
                          )
                        else
                          ...funded.map((e) => _Allocation(
                                icon: _icons[e.key.toLowerCase()] ?? Icons.circle_outlined,
                                name: e.key.replaceAll('_', ' '),
                                amount: rupees((e.value as num).round()),
                              )),
                        const Divider(height: 28),
                        _Line('Remaining Cash', rupees(appState.remainingCash.round()), strong: true),
                      ]),
                    ),
                    if (appState.allocationReasons.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Why this split?', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            ...appState.allocationReasons.map((r) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('• $r'),
                                )),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: green.withOpacity(.08), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: green),
                          const SizedBox(width: 10),
                          Expanded(child: Text(appState.headline.isNotEmpty ? appState.headline : 'You can safely deploy ${rupees(appState.safeToDeploy.round())} without compromising upcoming obligations.', style: const TextStyle(fontWeight: FontWeight.w700))),
                        ],
                      ),
                    ),
                    if (appState.riskNote.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      AppCard(child: Text(appState.riskNote)),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Test another spending plan'),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WhatIfScreen(appState: appState))),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.a, this.b, {this.strong = false, this.color});
  final String a, b;
  final bool strong;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(a, style: TextStyle(color: Colors.grey.shade700, fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
      Text(b, style: TextStyle(fontSize: strong ? 20 : 15, fontWeight: FontWeight.w900, color: color ?? dark)),
    ]),
  );
}

class _Allocation extends StatelessWidget {
  const _Allocation({required this.icon, required this.name, required this.amount});
  final IconData icon;
  final String name, amount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      CircleAvatar(backgroundColor: purple.withOpacity(.10), child: Icon(icon, color: purple)),
      const SizedBox(width: 12),
      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
      Text(amount, style: const TextStyle(fontWeight: FontWeight.w900)),
    ]),
  );
}
