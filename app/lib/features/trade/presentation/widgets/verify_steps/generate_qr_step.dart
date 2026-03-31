import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GenerateQrStep extends StatelessWidget {
  final String qrData;
  final String title;
  final String description;
  final String statusText;
  final String footerText;

  const GenerateQrStep({
    super.key,
    required this.qrData,
    required this.title,
    required this.description,
    required this.statusText,
    required this.footerText,
  });

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
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // QR Code display
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 260,
                gapless: true,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1a1a1a),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              footerText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE1E1E1)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFF8B0000),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: red,
                        fontWeight: FontWeight.w600,
                      ),
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
