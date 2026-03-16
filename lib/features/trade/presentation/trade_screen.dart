import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/workflow/workflow_state.dart';
import '../providers/trade_provider.dart';
import '../models/display_trade.dart';
import 'widgets/transaction_card.dart';

class TradeScreen extends ConsumerWidget {
  const TradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(displayTradesProvider);

    return tradesAsync.when(
      data: (trades) {
        final pending = trades.where((t) => t.workflowStatus == WorkflowTradeStatus.pending).toList();
        final active = trades.where((t) =>
            t.workflowStatus == WorkflowTradeStatus.accepted ||
            t.workflowStatus == WorkflowTradeStatus.scheduled ||
            t.workflowStatus == WorkflowTradeStatus.ready).toList();
        final completed = trades.where((t) => t.workflowStatus == WorkflowTradeStatus.completed).toList();

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Active Trades'),
              bottom: TabBar(
                tabs: [
                  Tab(text: 'PENDING (${pending.length})'),
                  Tab(text: 'ACTIVE (${active.length})'),
                  Tab(text: 'COMPLETED (${completed.length})'),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: const Color(0xFFFFD700),
              ),
            ),
            body: TabBarView(
              children: [
                _buildList(pending),
                _buildList(active),
                _buildList(completed),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildList(List<DisplayTrade> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No transactions'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => TransactionCard(trade: items[index]),
    );
  }
}
