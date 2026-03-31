import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/workflow_provider.dart';
import '../models/display_trade.dart';
import 'providers/display_trades_provider.dart';
import 'widgets/verify_steps/generate_qr_step.dart';
import 'widgets/verify_steps/rate_complete_step.dart';
import 'widgets/verify_steps/scan_verify_step.dart';

class VerifyHandshakeScreen extends ConsumerStatefulWidget {
  const VerifyHandshakeScreen({super.key, required this.trade});

  final DisplayTrade trade;

  @override
  ConsumerState<VerifyHandshakeScreen> createState() =>
      _VerifyHandshakeScreenState();
}

class _VerifyHandshakeScreenState extends ConsumerState<VerifyHandshakeScreen> {
  DocumentReference<Map<String, dynamic>> get _offerRef =>
      FirebaseFirestore.instance.collection('offers').doc(widget.trade.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVerificationInitialized();
    });
  }

  Future<void> _ensureVerificationInitialized() async {
    final offerSnapshot = await _offerRef.get();
    final Map<String, dynamic> offer = offerSnapshot.data() ?? <String, dynamic>{};

    final String sellerId = (offer['sellerId'] as String?) ?? '';
    final String buyerId = (offer['buyerId'] as String?) ?? '';
    if (sellerId.isEmpty || buyerId.isEmpty) {
      return;
    }

    final Map<String, dynamic> updates = <String, dynamic>{};
    if ((offer['verificationPhase'] as String?) == null) {
      updates['verificationPhase'] = 'buyer_scans_seller';
    }
    if ((offer['sellerVerificationCode'] as String?) == null) {
      updates['sellerVerificationCode'] = _sellerVerificationCode(sellerId);
    }
    if ((offer['buyerVerificationCode'] as String?) == null) {
      updates['buyerVerificationCode'] = _buyerVerificationCode(buyerId);
    }

    if (updates.isNotEmpty) {
      await _offerRef.set(updates, SetOptions(merge: true));
    }
  }

  String _sellerVerificationCode(String sellerId) {
    return 'offer:${widget.trade.id}:seller:$sellerId';
  }

  String _buyerVerificationCode(String buyerId) {
    return 'offer:${widget.trade.id}:buyer:$buyerId';
  }

  Future<void> _markBuyerScannedSeller() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    await firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await transaction.get(_offerRef);
      final Map<String, dynamic> offer = snapshot.data() ?? <String, dynamic>{};
      final String phase =
          ((offer['verificationPhase'] as String?) ?? 'buyer_scans_seller');

      if (phase != 'buyer_scans_seller') {
        return;
      }

      transaction.set(_offerRef, <String, dynamic>{
        'verificationPhase': 'seller_scans_buyer',
        'buyerScannedSellerQrAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _markSellerScannedBuyer() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> listingRef =
        firestore.collection('listings').doc(widget.trade.listingId);

    await firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(_offerRef);
      final Map<String, dynamic> offer =
          offerSnapshot.data() ?? <String, dynamic>{};
      final String phase =
          ((offer['verificationPhase'] as String?) ?? 'buyer_scans_seller');

      if (phase != 'seller_scans_buyer') {
        return;
      }

      final String sellerId = (offer['sellerId'] as String?) ?? '';
      final String buyerId = (offer['buyerId'] as String?) ?? '';

      transaction.set(_offerRef, <String, dynamic>{
        'verificationPhase': 'verified',
        'status': 'completed',
        'sellerScannedBuyerQrAt': FieldValue.serverTimestamp(),
        'verificationCompletedAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(listingRef, <String, dynamic>{
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final Set<String> completedCountedFor =
          (((offer['completedTradesCountedFor'] as List<dynamic>?) ??
                      const <dynamic>[])
                  .whereType<String>()
                  .toSet());

      if (sellerId.isNotEmpty && !completedCountedFor.contains(sellerId)) {
        final sellerRef = firestore.collection('users').doc(sellerId);
        final sellerSnapshot = await transaction.get(sellerRef);
        final int sellerCompleted =
            (sellerSnapshot.data()?['completedTrades'] as num?)?.toInt() ?? 0;
        transaction.set(sellerRef, <String, dynamic>{
          'completedTrades': sellerCompleted + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        completedCountedFor.add(sellerId);
      }

      if (buyerId.isNotEmpty && !completedCountedFor.contains(buyerId)) {
        final buyerRef = firestore.collection('users').doc(buyerId);
        final buyerSnapshot = await transaction.get(buyerRef);
        final int buyerCompleted =
            (buyerSnapshot.data()?['completedTrades'] as num?)?.toInt() ?? 0;
        transaction.set(buyerRef, <String, dynamic>{
          'completedTrades': buyerCompleted + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        completedCountedFor.add(buyerId);
      }

      transaction.set(_offerRef, <String, dynamic>{
        'completedTradesCountedFor': completedCountedFor.toList(growable: false),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _persistRatingOnly(
    Map<String, dynamic> offer,
    double rating,
    String feedback,
  ) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final User? currentUser = FirebaseAuth.instance.currentUser;

    await firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(_offerRef);
      final Map<String, dynamic> latestOffer =
          offerSnapshot.data() ?? <String, dynamic>{};

      final String sellerId = (latestOffer['sellerId'] as String?) ?? '';
      final String buyerId = (latestOffer['buyerId'] as String?) ?? '';
      final String currentUserId = currentUser?.uid ?? '';
      final Map<String, dynamic> ratingsByUser =
          Map<String, dynamic>.from(
            (latestOffer['ratingsByUser'] as Map?) ?? const <String, dynamic>{},
          );

      if (currentUserId.isEmpty || ratingsByUser.containsKey(currentUserId)) {
        return;
      }

      final String ratedUserId =
          currentUserId.isNotEmpty && currentUserId == sellerId
          ? buyerId
          : sellerId;

      transaction.set(_offerRef, <String, dynamic>{
        'ratingsByUser.$currentUserId': rating,
        'feedbackByUser.$currentUserId': feedback,
        'ratingSubmittedAtByUser.$currentUserId': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (ratedUserId.isNotEmpty) {
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
            ((oldRating * oldTotalRatings) + rating) / newTotalRatings;

        transaction.set(ratedUserRef, <String, dynamic>{
          'rating': newAverageRating,
          'totalRatings': newTotalRatings,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

    });
  }

  int _currentStepIndex(String phase) {
    switch (phase) {
      case 'buyer_scans_seller':
        return 0;
      case 'seller_scans_buyer':
        return 1;
      case 'verified':
      case 'completed':
        return 2;
      default:
        return 0;
    }
  }

  Widget _buildStepContent(
    BuildContext context,
    Map<String, dynamic> offer,
    String currentUserId,
  ) {
    final String sellerId = (offer['sellerId'] as String?) ?? '';
    final String buyerId = (offer['buyerId'] as String?) ?? '';
    final String phase =
        ((offer['verificationPhase'] as String?) ?? 'buyer_scans_seller');
    final String offerStatus = ((offer['status'] as String?) ?? '').toLowerCase();
    final Map<String, dynamic> ratingsByUser = Map<String, dynamic>.from(
      (offer['ratingsByUser'] as Map?) ?? const <String, dynamic>{},
    );
    final String sellerCode =
        (offer['sellerVerificationCode'] as String?) ??
        _sellerVerificationCode(sellerId);
    final String buyerCode =
        (offer['buyerVerificationCode'] as String?) ??
        _buyerVerificationCode(buyerId);
    final bool isSeller = currentUserId == sellerId;
    final bool isBuyer = currentUserId == buyerId;

    if (!isSeller && !isBuyer) {
      return const Center(
        child: Text('You are not part of this transaction.'),
      );
    }

    final bool alreadyRated = ratingsByUser.containsKey(currentUserId);

    if ((phase == 'verified' || phase == 'completed' || offerStatus == 'completed') &&
        alreadyRated) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This transaction is complete and you have already submitted your rating.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (phase == 'verified' || phase == 'completed' || offerStatus == 'completed') {
      return RateCompleteStep(
        transactionId: widget.trade.id,
        onRated: (_) {},
        onComplete: (double rating, String feedback) async {
          await _persistRatingOnly(offer, rating, feedback);
          ref.invalidate(displayTradesProvider);

          if (context.mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
      );
    }

    if (phase == 'buyer_scans_seller') {
      if (isSeller) {
        return GenerateQrStep(
          qrData: sellerCode,
          title: 'Show Your QR Code',
          description:
              'Buyer scans first. Ask the buyer to open Complete Trade and scan this code.',
          statusText: 'Waiting for buyer to scan your QR code.',
          footerText: 'Order ID: ${widget.trade.id}',
        );
      }

      return ScanVerifyStep(
        title: 'Scan Seller QR',
        description:
            'Buyer scans first. Use your camera to scan the seller\'s QR code.',
        expectedQrData: sellerCode,
        onScanned: (_) => _markBuyerScannedSeller(),
      );
    }

    if (isBuyer) {
      return GenerateQrStep(
        qrData: buyerCode,
        title: 'Show Your QR Code',
        description:
            'Seller scans second. Ask the seller to scan this QR code now.',
        statusText: 'Waiting for seller to scan your QR code.',
        footerText: 'Order ID: ${widget.trade.id}',
      );
    }

    return ScanVerifyStep(
      title: 'Scan Buyer QR',
      description:
          'Seller scans second. Use your camera to scan the buyer\'s QR code.',
      expectedQrData: buyerCode,
      onScanned: (_) async {
        await _markSellerScannedBuyer();

        final workflowController = ref.read(workflowControllerProvider);
        workflowController.completeTransaction(
          widget.trade.id,
          widget.trade.listingId,
          widget.trade.mode,
        );
        ref.invalidate(displayTradesProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _offerRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to load handshake verification.')),
          );
        }

        final Map<String, dynamic> offer =
            snapshot.data?.data() ?? <String, dynamic>{};
        final String phase =
            ((offer['verificationPhase'] as String?) ?? 'buyer_scans_seller');

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Complete Trade'),
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
                    widget.trade.isTradeMode ? 'Trade' : 'Sale',
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
              _StepIndicator(currentStepIndex: _currentStepIndex(phase)),
              Expanded(
                child: _buildStepContent(context, offer, currentUserId),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStepIndex});

  final int currentStepIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const steps = <(String, IconData)>[
      ('Buyer Scans Seller', Icons.qr_code_scanner),
      ('Seller Scans Buyer', Icons.qr_code_scanner_outlined),
      ('Rate & Complete', Icons.thumb_up),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(steps.length, (index) {
          final int stepNum = index + 1;
          final bool isCompleted = currentStepIndex > index;
          final bool isCurrent = currentStepIndex == index;
          final bool previousSegmentCompleted = currentStepIndex > index - 1;
          final bool nextSegmentCompleted = currentStepIndex > index;

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
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
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
