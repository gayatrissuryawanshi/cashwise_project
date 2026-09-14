import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';
import 'app_shell.dart';

class AnalysisCompleteScreen extends StatelessWidget {
  const AnalysisCompleteScreen({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final receivablesCount = appState.receivablesBreakdown.length;
    final obligationsCount = appState.obligations.length;

    final reportingDate =
        appState.business?['reporting_date']?.toString() ?? '—';

    final businessName =
        appState.business?['business_name']?.toString() ??
        appState.business?['Business_Name']?.toString() ??
        'Your Business';

    final recommendation = appState.recommendation;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Analysis Complete',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SUCCESS ICON
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: green.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: green,
                    size: 46,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // TITLE
              Center(
                child: Text(
                  'Analysis completed successfully',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: dark,
                      ),
                ),
              ),

              const SizedBox(height: 6),

              // BUSINESS NAME
              Center(
                child: Text(
                  businessName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // SUMMARY TITLE
              const Text(
                'Your CashWise Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: dark,
                ),
              ),

              const SizedBox(height: 12),

              // SUMMARY ROW 1
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Current Cash',
                      value: rupees(
                        appState.currentCash.round(),
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Safe to Deploy',
                      value: rupees(
                        appState.safeToDeploy.round(),
                      ),
                      icon: Icons.shield_outlined,
                      highlight: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // SUMMARY ROW 2
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Obligations',
                      value: rupees(
                        appState.totalObligationsAmount.round(),
                      ),
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Receivable Risk',
                      value: rupees(
                        appState.receivablesAtRisk.round(),
                      ),
                      icon: Icons.warning_amber_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // CASHWISE DECISION
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: purple,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'CashWise Decision',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: dark,
                          ),
                        ),
                        const Spacer(),

                        // StatusPill only accepts text
                        StatusPill(
                          text: appState.riskLevel,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Text(
                      appState.headline.isNotEmpty
                          ? appState.headline
                          : 'Cash allocation analysis is ready.',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: dark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      appState.riskNote.isNotEmpty
                          ? appState.riskNote
                          : 'The recommendation considers your cash, obligations, reserve and receivable risk.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // FILE SUMMARY
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'File Summary',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: dark,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Reporting Date',
                      value: reportingDate,
                    ),

                    const SizedBox(height: 12),

                    _InfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Obligations Found',
                      value: '$obligationsCount',
                    ),

                    const SizedBox(height: 12),

                    _InfoRow(
                      icon: Icons.people_outline,
                      label: 'Receivables Found',
                      value: '$receivablesCount',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // RECOMMENDED ALLOCATION
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recommended Allocation',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: dark,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (recommendation != null &&
                        recommendation.isNotEmpty)
                      ...recommendation.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _prettyName(entry.key),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: dark,
                                  ),
                                ),
                              ),
                              Text(
                                rupees(
                                  (entry.value as num?)?.round() ?? 0,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: dark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Text(
                        'No allocation details available.',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),

                    const Divider(height: 20),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total Allocated',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: dark,
                            ),
                          ),
                        ),
                        Text(
                          rupees(
                            appState.totalAllocated.round(),
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ML NOTES
              if (appState.mlNotes.isNotEmpty) ...[
                const SizedBox(height: 16),

                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.insights_outlined,
                        color: purple,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          appState.mlNotes.join('\n'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // VIEW DASHBOARD
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppShell(
                          appState: appState,
                        ),
                      ),
                      (_) => false,
                    );
                  },
                  icon: const Icon(
                    Icons.dashboard_outlined,
                  ),
                  label: const Text(
                    'View Dashboard',
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // UPLOAD ANOTHER FILE
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Upload Another File',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _prettyName(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: highlight ? purple : Colors.black54,
          ),

          const SizedBox(height: 10),

          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: highlight ? purple : dark,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: purple,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: dark,
          ),
        ),
      ],
    );
  }
}