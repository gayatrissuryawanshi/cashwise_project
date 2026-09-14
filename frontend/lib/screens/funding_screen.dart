import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// The backend doesn't have a `/funding-alternative` endpoint (the old
/// frontend contract assumed one that was never built - see
/// TEAM_HANDOFF.md). Rather than call a URL that 404s, this screen derives
/// a simple, transparent suggestion from data the backend actually
/// returns: the shortfall from /evaluate-spend and the receivables risk
/// breakdown from the recommendation. It's clearly labeled as a
/// prototype heuristic, not a real lending product.
class FundingScreen extends StatelessWidget {
  const FundingScreen({super.key, required this.appState, required this.spendCheck});
  final AppState appState;
  final Map<String, dynamic> spendCheck;

  @override
  Widget build(BuildContext context) {
    final gap = ((spendCheck['excess_amount'] ?? 0) as num).round();
    final atRiskReceivables = appState.receivablesBreakdown
        .where((r) => (r as Map)['reliability_label'] != 'UNRELIABLE')
        .toList();
    final bestReceivable = atRiskReceivables.isNotEmpty
        ? (atRiskReceivables..sort((a, b) => ((b as Map)['amount'] as num).compareTo((a as Map)['amount'] as num))).first as Map
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Safe Alternative'), backgroundColor: bg),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: red.withOpacity(.08), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Funding Gap', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(rupees(gap), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: red)),
              const SizedBox(height: 5),
              const Text('Amount needed to complete the plan safely.'),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Options', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: dark)),
          const SizedBox(height: 10),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(backgroundColor: Color(0xFFE8F9F0), child: Icon(Icons.trending_down, color: green)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Reduce the spend', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                const StatusPill(text: 'SAFEST'),
              ]),
              const SizedBox(height: 14),
              Text('Spend up to ${rupees(((spendCheck['safe_amount'] ?? 0) as num).round())} instead - that stays within the safe-to-deploy limit with no funding gap at all.'),
            ]),
          ),
          if (bestReceivable != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const CircleAvatar(backgroundColor: Color(0xFFF3EEFF), child: Icon(Icons.handshake_outlined, color: purple)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Chase down "${bestReceivable['description']}"', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 14),
                Text(
                  '${rupees((bestReceivable['amount'] as num).round())} is expected from this customer '
                  '(${bestReceivable['reliability_label']}, expected in ${bestReceivable['days_until_expected']} day(s)). '
                  'Collecting it early could close some or all of the ${rupees(gap)} gap.',
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Icon(Icons.info_outline, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(child: Text('These are simple, transparent suggestions based on your data - not a loan offer. The backend does not yet include a funding/credit product.', style: TextStyle(color: Colors.grey))),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
