import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/display_trade.dart';
import 'providers/verify_handshake_provider.dart';
import 'widgets/verify_steps/generate_qr_step.dart';
import 'widgets/verify_steps/scan_verify_step.dart';
import 'widgets/verify_steps/rate_complete_step.dart';

class VerifyHandshakeScreen extends ConsumerWidget {
  final DisplayTrade trade;

  const VerifyHandshakeScreen({super.key, required this.trade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verificationState = ref.watch(verificationProvider(trade.id));
    final verificationNotifier = ref.read(
      verificationProvider(trade.id).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Verify Handshake'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trade.isTradeMode ? 'Trade' : 'Sale',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator showing the steps
          _StepIndicator(currentStep: verificationState.currentStep),
          // Step content
          Expanded(
            child: _buildStepContent(
              context,
              verificationState,
              verificationNotifier,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(
    BuildContext context,
    VerificationState state,
    VerificationNotifier notifier,
  ) {
    switch (state.currentStep) {
      case VerificationStep.generateQr:
        return GenerateQrStep(
          transactionId: state.transactionId,
          onNext: notifier.moveToNextStep,
        );

      case VerificationStep.scanVerify:
        return ScanVerifyStep(
          transactionId: state.transactionId,
          onNext: notifier.moveToNextStep,
          onScanned: notifier.recordScannedQr,
        );

      case VerificationStep.rateComplete:
        return RateCompleteStep(
          transactionId: state.transactionId,
          onRated: notifier.recordRating,
          onComplete: () {
            // Navigate back to trades screen on completion
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final VerificationStep currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      ('Generate QR', Icons.qr_code),
      ('Scan & Verify', Icons.qr_code_scanner),
      ('Rate & Complete', Icons.thumb_up),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(steps.length, (index) {
          final stepNum = index + 2; // Steps 2, 3, 4
          final isCompleted = currentStep.index > index;
          final isCurrent = currentStep.index == index;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    // Step circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? Colors.green
                            : isCurrent
                            ? const Color(0xFF8B0000)
                            : Colors.grey[300],
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : Text(
                                stepNum.toString(),
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted ? Colors.green : Colors.grey[300],
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 50,
                  child: Text(
                    steps[index].$1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCurrent
                          ? const Color(0xFF8B0000)
                          : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
