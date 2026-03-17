import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/mock_data.dart';

abstract class TradeRepository {
  Future<Trade?> getTradeById(String tradeId);
}

class MockTradeRepository implements TradeRepository {
  const MockTradeRepository();

  @override
  Future<Trade?> getTradeById(String tradeId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      return mockTrades.firstWhere((Trade trade) => trade.id == tradeId);
    } on StateError {
      return null;
    }
  }
}

final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return const MockTradeRepository();
});
