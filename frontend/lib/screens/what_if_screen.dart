import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'funding_screen.dart';

class WhatIfScreen extends StatefulWidget {
  const WhatIfScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends State<WhatIfScreen> {
  final controller = TextEditingController(text: '100000');
  String category = 'Inventory';
  Map<String, dynamic>? result;
  bool loading = false;
  String? error;

  Future<void> _simulate() async {
    final amount = num.tryParse(controller.text.trim());
    if (amount == null || amount < 0) {
      setState(() => error = 'Enter a valid amount.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final res = await widget.appState.checkSpend(amount);
    // Also refresh the day-by-day timeline for this proposed amount, so
    // FundingScreen has a concrete shortfall number if needed.
    await widget.appState.runSimulation(amount);
    if (!mounted) return;
    setState(() {
      result = res;
      loading = false;
      error = res == null ? widget.appState.errorMessage : null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('What If I Spend...'), backgroundColor: bg),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Spending Amount', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: '₹ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                const Text('Category (for your reference)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const ['Inventory', 'Marketing', 'Supplier Payment', 'Equipment', 'Other']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: purple, padding: const EdgeInsets.all(15)),
                    onPressed: loading ? null : _simulate,
                    child: loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simulate'),
                  ),
                ),
              ]),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              AppCard(child: Text(error!, style: const TextStyle(color: red))),
            ],
            if (result != null) ...[
              const SizedBox(height: 14),
              _buildResultCard(result!),
              if (result!['is_safe'] != true) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.alt_route),
                    label: const Text('Find Safe Alternative'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FundingScreen(appState: widget.appState, spendCheck: result!)),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      );

  Widget _buildResultCard(Map<String, dynamic> r) {
    final isSafe = r['is_safe'] == true;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isSafe ? Icons.check_circle_outline : Icons.error_outline, color: isSafe ? green : red),
          const SizedBox(width: 8),
          Text(r['verdict']?.toString().replaceAll('_', ' ') ?? '', style: TextStyle(color: isSafe ? green : red, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 12),
        Text(r['reason']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _Stat('Cash After Spending', rupees(((r['remaining_cash_if_spent'] ?? 0) as num).round())),
        _Stat('Safety Floor Required', rupees(((r['safety_floor'] ?? 0) as num).round())),
        if (!isSafe) _Stat('Excess Over Safe Limit', rupees(((r['excess_amount'] ?? 0) as num).round()), color: red),
        _Stat('Risk Level', '${r['risk_level'] ?? ''}', color: isSafe ? green : red),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.a, this.b, {this.color});
  final String a, b;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(a, style: const TextStyle(color: Colors.grey)),
      Text(b, style: TextStyle(fontWeight: FontWeight.w900, color: color ?? dark)),
    ]),
  );
}
