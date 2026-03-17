import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/workflow_provider.dart';
import '../../data/trade_repository.dart';
import '../../models/display_trade.dart';

// Provider to fetch and prepare the list of trades for display in the UI.
final displayTradesProvider = FutureProvider<List<DisplayTrade>>((ref) async {
  final workflowController = ref.watch(workflowControllerProvider);
  final tradeRepository = ref.watch(tradeRepositoryProvider);
  final tradeStates = workflowController.state.tradeStates;

  final List<DisplayTrade?> displayTrades = await Future.wait<DisplayTrade?>(
    tradeStates.keys.map((String tradeId) async {
      final trade = await tradeRepository.getTradeById(tradeId);
      final workflowTradeState = tradeStates[tradeId];

      if (trade == null || workflowTradeState == null) {
        return null;
      }

      final sellerName = trade.listing.seller.name;

      return DisplayTrade(
        id: tradeId,
        listingId: trade.listingId,
        itemTitle: trade.listing.title,
        otherUserName: sellerName,
        otherUserInitial: sellerName.isEmpty ? '?' : sellerName[0],
        mode: workflowTradeState.mode,
        workflowStatus: workflowTradeState.status,
      );
    }),
  );

  return displayTrades.whereType<DisplayTrade>().toList(growable: false);
});
