import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';

class ForecastScreen extends StatelessWidget {
  const ForecastScreen({
    super.key,
    required this.appState,
  });

  final AppState appState;

  String _compactRupees(double value) {
    final absolute = value.abs();

    if (absolute >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    }

    if (absolute >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    }

    if (absolute >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(0)}K';
    }

    return '₹${value.toStringAsFixed(0)}';
  }

  List<dynamic> _fallbackTimeline() {
    final cash = appState.currentCash.toDouble();
    final obligations = appState.totalObligationsAmount.toDouble();
    final receivables = appState.receivablesRiskAdjusted.toDouble();

    if (cash <= 0) {
      return [];
    }

    /*
      Fallback only.

      The real backend /simulate timeline is used whenever available.
      This fallback prevents the Forecast screen from becoming empty
      when the backend timeline is temporarily unavailable.
    */
    return List.generate(7, (index) {
      final day = index * 5;

      final projected =
          cash -
          (obligations * day / 30.0) +
          (receivables * day / 30.0);

      return {
        'day': day,
        'cash': projected,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.hasAnalysis) {
          return Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              title: const Text(
                'Cash Flow Forecast',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              backgroundColor: bg,
              elevation: 0,
            ),
            body: const Center(
              child: Text(
                'Upload an Excel file to see your cash forecast.',
              ),
            ),
          );
        }

        final backendTimeline = appState.baselineTimeline;
        final timeline = backendTimeline.isNotEmpty
            ? backendTimeline
            : _fallbackTimeline();

        final spots = timeline
            .map(
              (point) => FlSpot(
                ((point['day'] ?? 0) as num).toDouble(),
                ((point['cash'] ?? 0) as num).toDouble(),
              ),
            )
            .toList();

        final cashValues = spots.map((spot) => spot.y).toList();

        double lowestChartValue = 0;
        double highestChartValue = 100000;

        if (cashValues.isNotEmpty) {
          lowestChartValue =
              cashValues.reduce((a, b) => a < b ? a : b);

          highestChartValue =
              cashValues.reduce((a, b) => a > b ? a : b);

          final reserve =
              appState.requiredReserve.toDouble();

          lowestChartValue =
              lowestChartValue < reserve
                  ? lowestChartValue
                  : reserve;

          lowestChartValue =
              lowestChartValue * 0.92;

          if (lowestChartValue < 0) {
            lowestChartValue = 0;
          }

          highestChartValue =
              highestChartValue * 1.08;

          if (highestChartValue <= lowestChartValue) {
            highestChartValue =
                lowestChartValue + 10000;
          }
        }

        final riskIsLow =
            appState.riskLevel.toUpperCase() == 'LOW';

        final lowestCash =
            appState.lowestProjectedCash.toDouble();

        final reserve =
            appState.requiredReserve.toDouble();

        final lowestDay =
            appState.lowestProjectedCashDay;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
              ),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
            title: const Text(
              'Cash Flow Forecast',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              110,
            ),
            children: [
              // ------------------------------------------------------------
              // HEADER
              // ------------------------------------------------------------
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '30-Day Cash Forecast',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: dark,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Projected cash after obligations and '
                            'risk-adjusted collections',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      text: appState.riskLevel.toUpperCase(),
                      safe: riskIsLow,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------------------
              // KEY NUMBERS
              // ------------------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Current Cash',
                      value: rupees(
                        appState.currentCash.round(),
                      ),
                      iconColor: purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.event_note_outlined,
                      label: 'Obligations',
                      value: rupees(
                        appState.totalObligationsAmount.round(),
                      ),
                      iconColor: orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.trending_up_rounded,
                      label: 'Expected Collections',
                      value: rupees(
                        appState.receivablesRiskAdjusted.round(),
                      ),
                      iconColor: green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.shield_outlined,
                      label: 'Safety Reserve',
                      value: rupees(
                        appState.requiredReserve.round(),
                      ),
                      iconColor: purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ------------------------------------------------------------
              // CHART
              // ------------------------------------------------------------
              AppCard(
                padding: const EdgeInsets.fromLTRB(
                  8,
                  16,
                  16,
                  10,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(
                        left: 8,
                        bottom: 12,
                      ),
                      child: Text(
                        'Projected Cash Movement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: dark,
                        ),
                      ),
                    ),

                    if (spots.isEmpty)
                      const SizedBox(
                        height: 180,
                        child: Center(
                          child: Text(
                            'No cash-flow timeline available.',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 220,
                        child: LineChart(
                          LineChartData(
                            minX: 0,
                            maxX: 30,
                            minY: lowestChartValue,
                            maxY: highestChartValue,

                            // ----------------------------
                            // GRID
                            // ----------------------------
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval:
                                  (highestChartValue -
                                          lowestChartValue) /
                                      4,
                              getDrawingHorizontalLine:
                                  (value) {
                                return FlLine(
                                  color: Colors.grey
                                      .withOpacity(0.16),
                                  strokeWidth: 1,
                                );
                              },
                            ),

                            // ----------------------------
                            // BORDER
                            // ----------------------------
                            borderData:
                                FlBorderData(
                              show: false,
                            ),

                            // ----------------------------
                            // AXES
                            // ----------------------------
                            titlesData: FlTitlesData(
                              topTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles: false,
                                ),
                              ),
                              rightTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles: false,
                                ),
                              ),

                              leftTitles:
                                  AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles: true,
                                  reservedSize: 48,
                                  interval:
                                      (highestChartValue -
                                              lowestChartValue) /
                                          4,
                                  getTitlesWidget:
                                      (value, meta) {
                                    return Text(
                                      _compactRupees(
                                        value,
                                      ),
                                      style:
                                          TextStyle(
                                        fontSize: 9,
                                        color: Colors
                                            .grey
                                            .shade600,
                                        fontWeight:
                                            FontWeight
                                                .w500,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              bottomTitles:
                                  AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  reservedSize: 26,
                                  getTitlesWidget:
                                      (value, meta) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets
                                              .only(
                                        top: 7,
                                      ),
                                      child: Text(
                                        'Day ${value.toInt()}',
                                        style:
                                            TextStyle(
                                          fontSize: 9,
                                          color: Colors
                                              .grey
                                              .shade600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // ------------------------------------------------
                            // RESERVE BOUNDARY
                            // ------------------------------------------------
                            extraLinesData:
                                ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: reserve,
                                  color: orange
                                      .withOpacity(0.75),
                                  strokeWidth: 1.5,
                                  dashArray: [6, 5],
                                  label:
                                      HorizontalLineLabel(
                                    show: true,
                                    alignment:
                                        Alignment
                                            .topRight,
                                    padding:
                                        const EdgeInsets
                                            .only(
                                      right: 4,
                                      bottom: 4,
                                    ),
                                    style:
                                        const TextStyle(
                                      fontSize: 9,
                                      fontWeight:
                                          FontWeight.w700,
                                      color: orange,
                                    ),
                                    labelResolver:
                                        (line) =>
                                            'Safety reserve',
                                  ),
                                ),
                              ],
                            ),

                            // ------------------------------------------------
                            // TOUCH / TOOLTIP
                            // ------------------------------------------------
                            lineTouchData:
                                LineTouchData(
                              enabled: true,
                              handleBuiltInTouches:
                                  true,
                              touchTooltipData:
                                  LineTouchTooltipData(
                                tooltipRoundedRadius:
                                    10,
                                tooltipPadding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                getTooltipItems:
                                    (touchedSpots) {
                                  return touchedSpots
                                      .map(
                                    (spot) {
                                      return LineTooltipItem(
                                        'Day ${spot.x.toInt()}'
                                        '  •  '
                                        '${rupees(spot.y.round())}',
                                        const TextStyle(
                                          color:
                                              Colors.white,
                                          fontWeight:
                                              FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ).toList();
                                },
                              ),
                            ),

                            // ------------------------------------------------
                            // LINE
                            // ------------------------------------------------
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                curveSmoothness: 0.25,
                                barWidth: 3,
                                color: purple,
                                isStrokeCapRound:
                                    true,
                                dotData:
                                    FlDotData(
                                  show: spots.length <= 10,
                                  getDotPainter:
                                      (
                                    spot,
                                    percent,
                                    bar,
                                    index,
                                  ) {
                                    return FlDotCirclePainter(
                                      radius: 3.5,
                                      color: purple,
                                      strokeWidth: 1.5,
                                      strokeColor:
                                          Colors.white,
                                    );
                                  },
                                ),
                                belowBarData:
                                    BarAreaData(
                                  show: true,
                                  color: purple
                                      .withOpacity(0.07),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 6),

                    // Legend
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 3,
                          decoration:
                              BoxDecoration(
                            color: purple,
                            borderRadius:
                                BorderRadius.circular(
                              10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Projected cash',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 20,
                          height: 1.5,
                          color: orange,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Safety reserve',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------------------
              // LOWEST PROJECTED CASH
              // ------------------------------------------------------------
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (riskIsLow
                                ? green
                                : red)
                            .withOpacity(0.10),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: riskIsLow
                            ? green
                            : red,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lowest Projected Cash',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors
                                  .grey
                                  .shade600,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            rupees(
                              lowestCash.round(),
                            ),
                            style:
                                const TextStyle(
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.w900,
                              color: dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Expected around Day $lowestDay',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      text: lowestCash >= reserve
                          ? 'SAFE'
                          : 'WATCH',
                      safe: lowestCash >= reserve,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------------------
              // SAFETY INTERPRETATION
              // ------------------------------------------------------------
              AppCard(
                padding: const EdgeInsets.all(17),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (riskIsLow
                                ? green
                                : red)
                            .withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        riskIsLow
                            ? Icons.check_rounded
                            : Icons.warning_amber_rounded,
                        color: riskIsLow
                            ? green
                            : red,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            riskIsLow
                                ? 'Cash position looks safe'
                                : 'Cash position needs attention',
                            style:
                                const TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w800,
                              color: dark,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            riskIsLow
                                ? 'Your projected minimum cash stays '
                                  'above the required safety reserve.'
                                : 'Projected cash may approach or cross '
                                  'your required safety reserve.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color:
                                  Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ------------------------------------------------------------
              // FRAGILITY / STRESS TEST
              // ------------------------------------------------------------
              if (appState.fragilityNote.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration:
                            BoxDecoration(
                          color: orange
                              .withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons
                              .warning_amber_outlined,
                          color: orange,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Collection Stress Test',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w800,
                                color: dark,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              appState.fragilityNote,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: Colors
                                    .grey
                                    .shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ------------------------------------------------------------
              // ML SALES FORECAST - ONLY IF AVAILABLE
              // ------------------------------------------------------------
              if (appState.salesForecast != null &&
                  appState.salesForecast!.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  padding:
                      const EdgeInsets.all(17),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_graph_rounded,
                        color: purple,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'ML Sales Forecast',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prediction available for '
                              '${appState.salesForecast!.length} '
                              'day(s).',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors
                                    .grey
                                    .shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 19,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: dark,
            ),
          ),
        ],
      ),
    );
  }
}