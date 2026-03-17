import 'package:flutter/material.dart';

class ScanVerifyStep extends StatefulWidget {
  final String transactionId;
  final VoidCallback onNext;
  final Function(String scannedData) onScanned;

  const ScanVerifyStep({
    super.key,
    required this.transactionId,
    required this.onNext,
    required this.onScanned,
  });

  @override
  State<ScanVerifyStep> createState() => _ScanVerifyStepState();
}

class _ScanVerifyStepState extends State<ScanVerifyStep> {
  bool _scannedBoth = false;

  void _simulateScan() {
    // In production, this would use camera to scan the other party's QR code.
    // For demo, we're simulating a successful scan.
    widget.onScanned('OTHER-PARTY-TXN-CODE');

    setState(() => _scannedBoth = true);

    // Show success feedback
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
              'Scan & Verify',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Both parties need to scan each other\'s QR codes to verify the handshake.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Camera placeholder
            Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[300] ?? Colors.grey,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Point camera at other party\'s QR code',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Status indicators
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
                            'Your QR',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Generated',
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
                            _scannedBoth ? Icons.check_circle : Icons.pending,
                            size: 28,
                            color: _scannedBoth
                                ? Colors.green
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Their QR',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _scannedBoth ? 'Scanned' : 'Pending',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _scannedBoth
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _scannedBoth ? null : _simulateScan,
                style: FilledButton.styleFrom(
                  backgroundColor: _scannedBoth ? Colors.grey : red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _scannedBoth ? 'Scanned & Verified' : 'Scan QR Code',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_scannedBoth) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next: Rate & Complete',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
