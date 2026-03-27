import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/mock_data.dart';
import '../../../models/listing_firestore_mapper.dart';

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

class FirestoreTradeRepository implements TradeRepository {
  const FirestoreTradeRepository();

  @override
  Future<Trade?> getTradeById(String tradeId) async {
    // Trade records are anchored on offers; listing info is loaded next.
    final offerDoc = await FirebaseFirestore.instance
        .collection('offers')
        .doc(tradeId)
        .get();

    if (!offerDoc.exists) {
      return null;
    }

    final Map<String, dynamic> offer = offerDoc.data() ?? <String, dynamic>{};
    final String listingId = (offer['listingId'] as String?) ?? '';
    if (listingId.isEmpty) {
      return null;
    }

    final listingDoc = await FirebaseFirestore.instance
        .collection('listings')
        .doc(listingId)
        .get();
    if (!listingDoc.exists) {
      return null;
    }

    final Listing listing = listingFromFirestoreMap(
      id: listingDoc.id,
      data: listingDoc.data() ?? <String, dynamic>{},
    );

    final dynamic createdAtData = offer['createdAt'];
    // Server timestamps can still be unresolved right after creation.
    final DateTime createdAt = createdAtData is Timestamp
        ? createdAtData.toDate()
        : DateTime.now();

    final String offerTypeRaw =
        ((offer['offerType'] as String?) ?? '').toLowerCase();
    final String offerStatusRaw =
        ((offer['status'] as String?) ?? 'accepted').toLowerCase();

    final double? cashAmount = (offer['amount'] as num?)?.toDouble();
    final List<String> tradeItems =
      ((offer['tradeItems'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false);
    // Current UI supports selecting a single primary trade item.
    final String? tradeItemId = tradeItems.isEmpty ? null : tradeItems.first;

    return Trade(
      id: offerDoc.id,
      listingId: listingId,
      listing: listing,
      offerType: offerTypeRaw == 'trade' ? OfferType.trade : OfferType.cash,
      cashAmount: cashAmount,
      tradeItemId: tradeItemId,
      tradeItem: null,
      status: _mapTradeStatus(offerStatusRaw),
      createdAt: createdAt,
    );
  }

  TradeStatus _mapTradeStatus(String status) {
    switch (status) {
      case 'pending':
        return TradeStatus.pending;
      case 'accepted':
        return TradeStatus.accepted;
      case 'rejected':
        return TradeStatus.rejected;
      case 'completed':
        return TradeStatus.completed;
      default:
        return TradeStatus.pending;
    }
  }
}

final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return const FirestoreTradeRepository();
});
