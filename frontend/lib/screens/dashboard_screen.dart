import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';
import 'receivable_risk_screen.dart';
import 'forecast_screen.dart';
import 'recommendation_screen.dart';
import 'upload_screen.dart';
import 'what_if_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.hasAnalysis) {
          return _EmptyDashboard(appState: appState);
        }

        return _FilledDashboard(appState: appState);
      },
    );
  }
}

// ============================================================
// EMPTY DASHBOARD
// ============================================================

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({
    required this.appState,
  });

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: purple.withOpacity(.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.upload_file_outlined,
                  color: purple,
                  size: 40,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'No analysis yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: dark,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Upload your business Excel file to get a safe-to-deploy recommendation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),

              if (appState.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  appState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: red),
                ),
              ],

              const SizedBox(height: 20),

              const Text(
                'Tap "Upload Excel" below to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FILLED DASHBOARD
// ============================================================

class _FilledDashboard extends StatelessWidget {
  const _FilledDashboard({
    required this.appState,
  });

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final safe = appState.riskLevel == 'LOW';

    final initials = appState.businessName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              18,
              16,
              18,
              28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1050,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ------------------------------------------------
                    // HEADER
                    // ------------------------------------------------

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back 👋',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                appState.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  color: dark,
                                ),
                              ),

                              const SizedBox(height: 3),

                              const Text(
                                'Your cash, planned safely.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        CircleAvatar(
                          radius: 22,
                          backgroundColor: purple.withOpacity(.12),
                          child: Text(
                            initials.isEmpty ? '?' : initials,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: purple,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ------------------------------------------------
                    // CURRENT CASH
                    // ------------------------------------------------

                    _cashCard(),

                    const SizedBox(height: 12),

                    // ------------------------------------------------
                    // METRICS
                    // ------------------------------------------------

                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 680;

                        final cards = [
                          _metric(
                            'Safe to Deploy',
                            rupees(
                              appState.safeToDeploy.round(),
                            ),
                            green,
                            Icons.verified_outlined,
                          ),

                          _metric(
                            'Upcoming Obligations',
                            rupees(
                              appState.totalObligationsAmount.round(),
                            ),
                            red,
                            Icons.event_note_outlined,
                          ),

                          _metric(
                            'Receivable Risk',
                            rupees(
                              appState.receivablesRiskAdjusted.round(),
                            ),
                            purple,
                            Icons.people_outline,
                          ),
                        ];

                        if (wide) {
                          return Row(
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 10),
                              Expanded(child: cards[1]),
                              const SizedBox(width: 10),
                              Expanded(child: cards[2]),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 10),
                            cards[1],
                            const SizedBox(height: 10),
                            cards[2],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // ------------------------------------------------
                    // QUICK ACTIONS
                    // ------------------------------------------------

                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: dark,
                      ),
                    ),

                    const SizedBox(height: 10),

                    LayoutBuilder(
                      builder: (context, c) {
                        final width = c.maxWidth;

                        int columns;

                        if (width >= 850) {
                          columns = 4;
                        } else if (width >= 520) {
                          columns = 2;
                        } else {
                          columns = 2;
                        }

                        final actionWidth =
                            (width - ((columns - 1) * 10)) /
                                columns;

                        final actions = [
                          _Action(
                            title: 'Upload Excel',
                            icon: Icons.upload_file_outlined,
                            color: purple,
                            onTap: () async {
                              final result =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: [
                                  'xlsx',
                                  'xlsm',
                                ],
                                withData: true,
                              );

                              if (!context.mounted ||
                                  result == null) {
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UploadScreen(
                                    appState: appState,
                                    file: result.files.single,
                                  ),
                                ),
                              );
                            },
                          ),

                          _Action(
                            title: 'Receivable Risk',
                            icon: Icons.people_outline,
                            color: purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReceivableRiskScreen(
                                    appState: appState,
                                  ),
                                ),
                              );
                            },
                          ),

                          _Action(
                            title: 'Cash Forecast',
                            icon: Icons.show_chart,
                            color: purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ForecastScreen(
                                    appState: appState,
                                  ),
                                ),
                              );
                            },
                          ),

                          _Action(
                            title: 'AI Recommendation',
                            icon: Icons.auto_awesome_outlined,
                            color: purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RecommendationScreen(
                                    appState: appState,
                                  ),
                                ),
                              );
                            },
                          ),
                        ];

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: actions
                              .map(
                                (action) => SizedBox(
                                  width: actionWidth,
                                  child: action,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // ------------------------------------------------
                    // NEXT PAYMENT
                    // ------------------------------------------------

                    if (appState.obligations.isNotEmpty) ...[
                      _nextPaymentCard(),
                      const SizedBox(height: 12),
                    ],

                    // ------------------------------------------------
                    // CASH FLOW STATUS
                    // ------------------------------------------------

                    AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: (safe ? green : red)
                                  .withOpacity(.12),
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              color: safe ? green : red,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cash Flow Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  '${appState.riskLevel} • Lowest projected cash ${rupees(appState.lowestProjectedCash.round())}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          _pill(
                            appState.riskLevel,
                            safe ? green : red,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ------------------------------------------------
                    // AI RECOMMENDATION
                    // ------------------------------------------------

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF7255E8),
                            Color(0xFF5636C8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: purple.withOpacity(.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withOpacity(.16),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),

                              const SizedBox(width: 10),

                              const Expanded(
                                child: Text(
                                  'AI Cash Recommendation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 13),

                          Text(
                            'You can safely deploy ${rupees(appState.safeToDeploy.round())} while maintaining your cash reserve.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),

                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: purple,
                                padding:
                                    const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(13),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RecommendationScreen(
                                      appState: appState,
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'View Full Recommendation',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ------------------------------------------------
                    // WHAT IF
                    // ------------------------------------------------

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.calculate_outlined,
                        ),
                        label: const Text(
                          'What if I spend more?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WhatIfScreen(
                                appState: appState,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Space before the shell's bottom navigation.
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // CASH CARD
  // ============================================================

  Widget _cashCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7255E8),
            Color(0xFF5636C8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: purple.withOpacity(.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Cash',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 6),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupees(appState.currentCash.round()),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Available balance today',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METRIC CARD
  // ============================================================

  Widget _metric(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NEXT PAYMENT
  // ============================================================

  Widget _nextPaymentCard() {
    final sorted = List<dynamic>.from(appState.obligations)
      ..sort(
        (a, b) {
          final aDays =
              ((a['days_until_due'] ?? 0) as num).toDouble();
          final bDays =
              ((b['days_until_due'] ?? 0) as num).toDouble();

          return aDays.compareTo(bDays);
        },
      );

    final next = sorted.first as Map;

    final days =
        ((next['days_until_due'] ?? 0) as num).round();

    final amount =
        ((next['amount'] ?? 0) as num).round();

    final urgent = days <= 7;

    return AppCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: urgent ? red : orange,
                size: 21,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Next Payment',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),

              _pill(
                urgent ? 'HIGH' : 'UPCOMING',
                urgent ? red : orange,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            '${next['name']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Due in $days day(s)',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            rupees(amount),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: urgent ? red : orange,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PILL
  // ============================================================

  Widget _pill(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ============================================================
// QUICK ACTION CARD
// ============================================================

class _Action extends StatelessWidget {
  const _Action({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // IMPORTANT:
    // Material is the ancestor of InkWell.
    // This fixes the red screen:
    // "No Material widget found".
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.black.withOpacity(.035),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SizedBox(
            height: 112,
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 21,
                  ),
                ),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: dark,
                    ),
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