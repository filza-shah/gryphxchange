import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../models/display_trade.dart';
import 'providers/display_trades_provider.dart';
import 'widgets/transaction_card.dart';

class TradeScreen extends ConsumerWidget {
  const TradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(displayTradesProvider);

    return tradesAsync.when(
      data: (trades) {
        final pending = trades
            .where((DisplayTrade trade) => trade.isPending)
            .toList(growable: false);
        final active = trades
            .where((DisplayTrade trade) => trade.isActive)
            .toList(growable: false);
        final completed = trades
            .where((DisplayTrade trade) => trade.isCompleted)
            .toList(growable: false);

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            bottomNavigationBar: const AppBottomNav(currentRoute: '/trades'),
            appBar: AppBar(
              title: const Text('Active Trades'),
              bottom: TabBar(
                tabs: <Widget>[
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
      loading: () => const Scaffold(
        bottomNavigationBar: AppBottomNav(currentRoute: '/trades'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        bottomNavigationBar: const AppBottomNav(currentRoute: '/trades'),
        body: Center(child: Text('Error: $err')),
      ),
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
