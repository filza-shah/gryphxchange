import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/workflow_provider.dart';
import '../../../services/workflow/workflow_state.dart';
import '../models/display_trade.dart';
import 'trade_repository.dart';

final displayTradesProvider = FutureProvider<List<DisplayTrade>>((ref) async {
  final workflowController = ref.watch(workflowControllerProvider);
  final tradeRepo = ref.watch(tradeRepositoryProvider);

  final tradeIds = workflowController.state.tradeStates.keys.toList();
  final displayTrades = <DisplayTrade>[];

  for (final id in tradeIds) {
    final trade = await tradeRepo.getTradeById(id);
    if (trade == null) continue;

    final workflowTradeState = workflowController.state.tradeStates[id];
    if (workflowTradeState == null) continue;

    displayTrades.add(DisplayTrade(
      id: id,
      itemTitle: trade.listing.title,
      otherUserName: trade.listing.seller.name,
      otherUserInitial: trade.listing.seller.name[0],
      mode: workflowTradeState.mode,
      workflowStatus: workflowTradeState.status,
    ));
  }

  return displayTrades;
});

