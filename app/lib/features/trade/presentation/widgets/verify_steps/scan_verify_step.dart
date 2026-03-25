import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanVerifyStep extends StatefulWidget {
  final String title;
  final String description;
  final String expectedQrData;
  final Future<void> Function(String scannedData) onScanned;
  final VoidCallback onSkip;

  const ScanVerifyStep({
    super.key,
    required this.title,
    required this.description,
    required this.expectedQrData,
    required this.onScanned,
    required this.onSkip,
  });

  @override
  State<ScanVerifyStep> createState() => _ScanVerifyStepState();
}

class _ScanVerifyStepState extends State<ScanVerifyStep> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessingScan = false;
  bool _scanVerified = false;
  String _statusMessage =
      'Point camera at the QR code to verify the handshake.';

  void _handleScannerError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }

    final String message = switch (error) {
      MobileScannerException exception
          when exception.errorCode == MobileScannerErrorCode.permissionDenied =>
        'Camera permission is required to scan QR codes. Allow camera access and reopen this screen.',
      _ => 'Unable to access the camera right now. Please try again.',
    };

    setState(() {
      _statusMessage = message;
    });
  }

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final bool permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            permissionDenied
                ? 'Camera permission is required to scan QR codes. Allow camera access and try again.'
                : 'Unable to start the camera preview. Please try again.',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleDetectedCode(String scannedData) async {
    if (_isProcessingScan || _scanVerified) {
      return;
    }

    if (scannedData != widget.expectedQrData) {
      setState(() {
        _statusMessage =
            'That QR code does not match this transaction. Try again.';
      });
      return;
    }

    setState(() {
      _isProcessingScan = true;
      _statusMessage = 'Verifying QR code...';
    });

    await _scannerController.stop();
    await widget.onScanned(scannedData);

    if (!mounted) {
      return;
    }

    setState(() {
      _scanVerified = true;
      _isProcessingScan = false;
      _statusMessage = 'QR code verified successfully.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR code verified successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = const Color(0xFF8B0000);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              widget.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[300] ?? Colors.grey,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetectError: _handleScannerError,
                  errorBuilder: _buildScannerError,
                  onDetect: (capture) {
                    final String? rawValue = capture.barcodes.first.rawValue;
                    if (rawValue == null || rawValue.isEmpty) {
                      return;
                    }
                    _handleDetectedCode(rawValue);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 28,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Camera',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Live',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Icon(
                            _scanVerified ? Icons.check_circle : Icons.pending,
                            size: 28,
                            color: _scanVerified
                                ? Colors.green
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Verification',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _scanVerified ? 'Matched' : 'Pending',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _scanVerified
                                  ? Colors.green
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _scanVerified ? Colors.green[700] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isProcessingScan || _scanVerified
                    ? null
                    : widget.onSkip,
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip for Testing'),
                style: TextButton.styleFrom(foregroundColor: red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
