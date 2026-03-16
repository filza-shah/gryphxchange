import 'package:flutter/material.dart';
import '../../models/display_trade.dart';
import '../../../../services/workflow/workflow_state.dart';

class TransactionCard extends StatelessWidget {
  final DisplayTrade trade;

  const TransactionCard({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = const Color(0xFF8B0000); // matches your theme
    final gold = const Color(0xFFFFD700);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item title
            Text(
              trade.itemTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // User row with avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: red.withOpacity(0.1),
                  child: Text(
                    trade.otherUserInitial,
                    style: TextStyle(
                      color: red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  trade.otherUserName,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status line
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: 16,
                  color: trade.mode == TransactionMode.trade ? red : gold,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trade.fullStatus,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Two buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Navigate to command center
                      print('Open Command Center for ${trade.id}');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: red,
                      side: BorderSide(color: red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Open Command Center'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // TODO: Trigger verification (QR scan)
                      print('Verify transaction ${trade.id}');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Verify'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
