import 'package:flutter_riverpod/flutter_riverpod.dart';

// represents the current step in the handshake verification process.
enum VerificationStep {
  generateQr, // Step 2: Both parties generate their QR codes
  scanVerify, // Step 3: Both parties scan each other's codes
  rateComplete, // Step 4: Rate the transaction and mark complete
}

class VerificationState {
  final VerificationStep currentStep;
  final String transactionId;
  final String? generatedQrData;
  final String? scannedQrData;
  final double? rating;

  const VerificationState({
    required this.currentStep,
    required this.transactionId,
    this.generatedQrData,
    this.scannedQrData,
    this.rating,
  });

  VerificationState copyWith({
    VerificationStep? currentStep,
    String? transactionId,
    String? generatedQrData,
    String? scannedQrData,
    double? rating,
  }) {
    return VerificationState(
      currentStep: currentStep ?? this.currentStep,
      transactionId: transactionId ?? this.transactionId,
      generatedQrData: generatedQrData ?? this.generatedQrData,
      scannedQrData: scannedQrData ?? this.scannedQrData,
      rating: rating ?? this.rating,
    );
  }
}

class VerificationNotifier extends StateNotifier<VerificationState> {
  VerificationNotifier(String transactionId)
    : super(
        VerificationState(
          currentStep: VerificationStep.generateQr,
          transactionId: transactionId,
          generatedQrData: 'TXN-TRADE-1-2026-03',
        ),
      );

  void generateQr(String qrData) {
    state = state.copyWith(generatedQrData: qrData);
  }

  void recordScannedQr(String scannedData) {
    state = state.copyWith(scannedQrData: scannedData);
  }

  void moveToNextStep() {
    final nextStep = switch (state.currentStep) {
      VerificationStep.generateQr => VerificationStep.scanVerify,
      VerificationStep.scanVerify => VerificationStep.rateComplete,
      VerificationStep.rateComplete => VerificationStep.rateComplete,
    };
    state = state.copyWith(currentStep: nextStep);
  }

  void recordRating(double rating) {
    state = state.copyWith(rating: rating);
  }
}

final verificationProvider =
    StateNotifierProvider.family<
      VerificationNotifier,
      VerificationState,
      String
    >((ref, transactionId) {
      return VerificationNotifier(transactionId);
    });
