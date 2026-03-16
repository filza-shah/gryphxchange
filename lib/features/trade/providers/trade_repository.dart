import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/mock_data.dart';

abstract class TradeRepository {
  Future<Trade?> getTradeById(String tradeId);
}

class MockTradeRepository implements TradeRepository {
  @override
  Future<Trade?> getTradeById(String tradeId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      // Using firstWhere without orElse throws an error if not found,
      // so we catch it and return null.
      return mockTrades.firstWhere((t) => t.id == tradeId);
    } catch (e) {
      return null;
    }
  }
}

final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return MockTradeRepository();
});
