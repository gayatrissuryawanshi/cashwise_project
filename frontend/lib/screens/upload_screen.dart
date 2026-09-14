import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';
import 'analysis_complete_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({
    super.key,
    required this.appState,
    required this.file,
  });

  final AppState appState;
  final PlatformFile file;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  double progress = 0;
  Timer? timer;

  bool requestDone = false;
  bool requestOk = false;
  String? error;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
      const Duration(milliseconds: 350),
      (_) {
        if (!mounted) return;

        setState(() {
          if (progress < 0.9) {
            progress += 0.07;

            if (progress > 0.9) {
              progress = 0.9;
            }
          }
        });
      },
    );

    _runUpload();
  }

  Future<void> _runUpload() async {
    try {
      String? filePath;
      Uint8List? bytes;

      // ==========================================================
      // WEB
      // ==========================================================
      //
      // Chrome/Web does NOT provide PlatformFile.path.
      // We must send the file as bytes.
      //
      if (kIsWeb) {
        bytes = widget.file.bytes;

        if (bytes == null || bytes!.isEmpty) {
          throw Exception(
            'Could not read the Excel file in the browser. '
            'Please select the Excel file again.',
          );
        }
      }

      // ==========================================================
      // MOBILE / DESKTOP
      // ==========================================================
      //
      // On Android/Desktop, use the actual file path.
      //
      else {
        filePath = widget.file.path;

        if (filePath == null || filePath!.isEmpty) {
          throw Exception(
            'Could not access the selected Excel file.',
          );
        }
      }

      // ==========================================================
      // SEND TO BACKEND
      // ==========================================================

      final ok = await widget.appState.uploadAndAnalyze(
        filename: widget.file.name,
        filePath: filePath,
        bytes: bytes,
      );

      if (!mounted) return;

      timer?.cancel();

      setState(() {
        progress = 1.0;
        requestDone = true;
        requestOk = ok;
        error = widget.appState.errorMessage;
      });

      // ==========================================================
      // SUCCESS
      // ==========================================================

      if (ok) {
        await Future.delayed(
          const Duration(milliseconds: 350),
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisCompleteScreen(
              appState: widget.appState,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      timer?.cancel();

      setState(() {
        progress = 1.0;
        requestDone = true;
        requestOk = false;
        error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool failed = requestDone && !requestOk;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyzing Your Sheet'),
        backgroundColor: bg,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // ==================================================
            // PROGRESS CIRCLE
            // ==================================================

            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    color: failed ? red : purple,
                    backgroundColor: purple.withOpacity(.10),
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      failed
                          ? Icons.error_outline
                          : requestDone
                              ? Icons.check_circle_outline
                              : Icons.table_chart,
                      color: failed
                          ? red
                          : requestDone
                              ? green
                              : green,
                      size: 34,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ==================================================
            // FILE NAME
            // ==================================================

            Text(
              widget.file.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // STEPS
            // ==================================================

            const _Step(
              'Reading Excel file',
              true,
            ),

            _Step(
              'Uploading to CashFlow Engine',
              progress > .3,
            ),

            _Step(
              'Running ML + decision engine',
              progress > .6,
            ),

            _Step(
              'Generating recommendations',
              requestDone,
            ),

            const Spacer(),

            // ==================================================
            // ERROR
            // ==================================================

            if (failed) ...[
              AppCard(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        error ??
                            'Upload failed. Please try again.',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: purple,
                    padding: const EdgeInsets.all(15),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Go Back'),
                ),
              ),
            ]

            // ==================================================
            // NORMAL / SUCCESS
            // ==================================================

            else
              AppCard(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: purple,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        requestDone
                            ? 'Analysis complete. Preparing your CashWise results...'
                            : 'Tip: your sheet should follow BUSINESS_DATA_TEMPLATE.xlsx (BusinessData, Sales, Udhar sheets).',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ANALYSIS STEP
// ============================================================

class _Step extends StatelessWidget {
  const _Step(
    this.label,
    this.done,
  );

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: done ? green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}