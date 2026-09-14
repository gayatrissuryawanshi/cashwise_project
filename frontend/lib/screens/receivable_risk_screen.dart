import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class ReceivableRiskScreen extends StatelessWidget {
  const ReceivableRiskScreen({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final receivables = appState.receivablesBreakdown;
        return Scaffold(
          appBar: AppBar(title: const Text('Receivable Risk'), backgroundColor: bg),
          body: !appState.hasAnalysis
              ? const Center(child: Text('Upload an Excel file to see receivable risk.'))
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Row(
                      children: [
                        Expanded(child: _top('Total Receivables', rupees(appState.receivablesFaceValue.round()))),
                        const SizedBox(width: 10),
                        Expanded(child: _top('Risk-adjusted Value', rupees(appState.receivablesRiskAdjusted.round()))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('Customer Risk', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: dark)),
                    const SizedBox(height: 10),
                    if (receivables.isEmpty)
                      const AppCard(child: Text('No receivables recorded for this business.'))
                    else
                      ...receivables.map((c) {
                        final map = c as Map;
                        final label = (map['reliability_label'] ?? 'UNKNOWN') as String;
                        final score = ((map['reliability_score'] ?? 0) as num) * 100;
                        final color = _color(label);
                        return AppCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: color.withOpacity(.12),
                              child: Icon(Icons.person_outline, color: color),
                            ),
                            title: Text('${map['description']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${rupees(((map['amount'] ?? 0) as num).round())}  •  Expected in ${map['days_until_expected']} day(s)'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${score.round()}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
                                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 10),
                    AppCard(child: Text(_insight(receivables))),
                    if (appState.udharPredictions != null && appState.udharPredictions!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text('ML Payment Predictions', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: dark)),
                      const SizedBox(height: 10),
                      ...appState.udharPredictions!.map((p) {
                        final map = p as Map;
                        final behavior = '${map['Predicted_Behavior']}';
                        final color = behavior.toUpperCase().contains('LATE') ? red : green;
                        return AppCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${map['Customer_ID']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('Outstanding ${rupees(((map['Outstanding'] ?? 0) as num).round())}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(behavior, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                                Text('${map['Confidence']}% confidence', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _top(String title, String value) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: purple)),
        ]),
      );

  Color _color(String label) {
    switch (label) {
      case 'RELIABLE':
        return green;
      case 'MODERATE':
        return orange;
      case 'UNRELIABLE':
        return red;
      default:
        return Colors.grey;
    }
  }

  String _insight(List<dynamic> receivables) {
    if (receivables.isEmpty) return 'No receivables to assess yet.';
    final risky = receivables.where((r) => (r as Map)['reliability_label'] != 'RELIABLE').length;
    return 'Insight: $risky of ${receivables.length} customer(s) are moderate or high risk of delayed payment. '
        'This risk is already reflected in the cash allocation recommendation.';
  }
}
