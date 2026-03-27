import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/providers/workflow_provider.dart';
import '../models/display_trade.dart';
import 'providers/display_trades_provider.dart';
import 'providers/verify_handshake_provider.dart';
import 'widgets/verify_steps/generate_qr_step.dart';
import 'widgets/verify_steps/scan_verify_step.dart';
import 'widgets/verify_steps/rate_complete_step.dart';

class VerifyHandshakeScreen extends ConsumerWidget {
  final DisplayTrade trade;

  const VerifyHandshakeScreen({super.key, required this.trade});

  Future<void> _persistCompletionAndRating(VerificationState state) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> offerRef =
        firestore.collection('offers').doc(trade.id);
    final DocumentReference<Map<String, dynamic>> listingRef =
        firestore.collection('listings').doc(trade.listingId);
    final User? currentUser = FirebaseAuth.instance.currentUser;

    // This helps to update related data such as number of transactions and ratings to a user's profile after a transaction is completed.
    await firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offerRef);
      final Map<String, dynamic> offer =
          offerSnapshot.data() ?? <String, dynamic>{};

      final String sellerId = (offer['sellerId'] as String?) ?? '';
      final String buyerId = (offer['buyerId'] as String?) ?? '';
      final String currentUserId = currentUser?.uid ?? '';

      final String ratedUserId =
          currentUserId.isNotEmpty && currentUserId == sellerId
          ? buyerId
          : sellerId;

      // We update both offer and listing status together so trades never show
      // as completed in one collection and pending in the other.
      transaction.set(offerRef, <String, dynamic>{
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(listingRef, <String, dynamic>{
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (ratedUserId.isNotEmpty && state.rating != null) {
        final ratedUserRef = firestore.collection('users').doc(ratedUserId);
        final ratedUserSnapshot = await transaction.get(ratedUserRef);
        final Map<String, dynamic> ratedUser =
            ratedUserSnapshot.data() ?? <String, dynamic>{};

        final int oldTotalRatings =
            (ratedUser['totalRatings'] as num?)?.toInt() ?? 0;
        final double oldRating = (ratedUser['rating'] as num?)?.toDouble() ?? 0;
        final int newTotalRatings = oldTotalRatings + 1;
        // Running-average update avoids loading historical ratings documents.
        final double newAverageRating =
            ((oldRating * oldTotalRatings) + state.rating!) / newTotalRatings;

        transaction.set(ratedUserRef, <String, dynamic>{
          'rating': newAverageRating,
          'totalRatings': newTotalRatings,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (sellerId.isNotEmpty) {
        final sellerRef = firestore.collection('users').doc(sellerId);
        final sellerSnapshot = await transaction.get(sellerRef);
        final int sellerCompleted =
            (sellerSnapshot.data()?['completedTrades'] as num?)?.toInt() ?? 0;

        transaction.set(sellerRef, <String, dynamic>{
          'completedTrades': sellerCompleted + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (buyerId.isNotEmpty) {
        final buyerRef = firestore.collection('users').doc(buyerId);
        final buyerSnapshot = await transaction.get(buyerRef);
        final int buyerCompleted =
            (buyerSnapshot.data()?['completedTrades'] as num?)?.toInt() ?? 0;

        transaction.set(buyerRef, <String, dynamic>{
          'completedTrades': buyerCompleted + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

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
              ref,
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
    WidgetRef ref,
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
          onComplete: () async {
            await _persistCompletionAndRating(state);

            final workflowController = ref.read(workflowControllerProvider);
            workflowController.completeTransaction(
              trade.id,
              trade.listingId,
              trade.mode,
            );
            ref.invalidate(displayTradesProvider);

            // Navigate back to trades screen on completion
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
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
          final stepNum = index + 1;
          final isCompleted = currentStep.index > index;
          final isCurrent = currentStep.index == index;
          final previousSegmentCompleted = currentStep.index > index - 1;
          final nextSegmentCompleted = currentStep.index > index;

          return Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (index > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(
                              height: 2,
                              color: previousSegmentCompleted
                                  ? Colors.green
                                  : Colors.grey[300],
                            ),
                          ),
                        ),
                      if (index < steps.length - 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(
                              height: 2,
                              color: nextSegmentCompleted
                                  ? Colors.green
                                  : Colors.grey[300],
                            ),
                          ),
                        ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
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
