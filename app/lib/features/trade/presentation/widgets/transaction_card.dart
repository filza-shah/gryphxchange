import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../services/workflow/workflow_state.dart';
import '../../models/display_trade.dart';

class TransactionCard extends StatelessWidget {
  final DisplayTrade trade;

  const TransactionCard({super.key, required this.trade});

  Color _statusColor() {
    switch (trade.workflowStatus) {
      case WorkflowTradeStatus.accepted:
        return const Color(0xFF1B5E20);
      case WorkflowTradeStatus.scheduled:
        return const Color(0xFF0D47A1);
      case WorkflowTradeStatus.ready:
        return const Color(0xFF8B0000);
      case WorkflowTradeStatus.completed:
        return const Color(0xFF01579B);
      case WorkflowTradeStatus.pending:
        return const Color(0xFF6A4B00);
    }
  }

  IconData _statusIcon() {
    switch (trade.workflowStatus) {
      case WorkflowTradeStatus.accepted:
        return Icons.check_circle;
      case WorkflowTradeStatus.scheduled:
        return Icons.event_available;
      case WorkflowTradeStatus.ready:
        return Icons.handshake;
      case WorkflowTradeStatus.completed:
        return Icons.task_alt;
      case WorkflowTradeStatus.pending:
        return Icons.hourglass_top;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = const Color(0xFF8B0000);
    final gold = const Color(0xFFFFD700);
    final Color statusColor = _statusColor();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trade.itemTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: red.withValues(alpha: 0.1),
                  child: Text(
                    trade.otherUserInitial,
                    style: TextStyle(color: red, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(trade.otherUserName, style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: 16,
                  color: trade.isTradeMode ? red : gold,
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
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_statusIcon(), color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trade.statusText,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trade.statusDescription,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  context.push(
                    '/verify-handshake/${trade.id}',
                    extra: trade,
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(trade.primaryActionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
