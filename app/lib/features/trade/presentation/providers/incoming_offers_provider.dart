import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth_provider.dart';

// Lightweight view model used by the Trades screen for seller-side inbox cards.
class IncomingOffer {
  const IncomingOffer({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.buyerId,
    required this.buyerName,
    required this.offerType,
    required this.amount,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String listingTitle;
  final String buyerId;
  final String buyerName;
  final String offerType;
  final double? amount;
  final String message;
  final DateTime createdAt;
}

final incomingOffersProvider = StreamProvider<List<IncomingOffer>>((ref) {
  // Provider depends on auth state so it auto-refreshes when users switch.
  final User? authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) {
    return Stream.value(const <IncomingOffer>[]);
  }

  // Seller inbox: only unresolved offers need quick action in Trades.
  return FirebaseFirestore.instance
      .collection('offers')
      .where('sellerId', isEqualTo: authUser.uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
        // Resolve buyer names once per snapshot so card rendering stays simple.
        final Set<String> buyerIds = snapshot.docs
            .map((doc) => (doc.data()['buyerId'] as String?) ?? '')
            .where((buyerId) => buyerId.isNotEmpty)
            .toSet();

        final Map<String, String> buyerNamesById = <String, String>{};
        await Future.wait<void>(
          buyerIds.map((String buyerId) async {
            final DocumentSnapshot<Map<String, dynamic>> userDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(buyerId)
                    .get();

            final Map<String, dynamic> userData =
                userDoc.data() ?? <String, dynamic>{};
            final String name = (userData['name'] as String?)?.trim() ?? '';
            buyerNamesById[buyerId] = name.isNotEmpty ? name : buyerId;
          }),
        );

        // Each offer is enriched with listing title so cards stay self-contained.
        final List<IncomingOffer?> offers = await Future.wait<IncomingOffer?>(
          snapshot.docs.map((doc) async {
            final Map<String, dynamic> data = doc.data();
            // listingId is required to link the card back to listing details.
            final String listingId = (data['listingId'] as String?) ?? '';
            if (listingId.isEmpty) {
              return null;
            }

            final DocumentSnapshot<Map<String, dynamic>> listingDoc =
                await FirebaseFirestore.instance
                    .collection('listings')
                    .doc(listingId)
                    .get();
            final Map<String, dynamic> listingData =
                listingDoc.data() ?? <String, dynamic>{};

            final dynamic createdAtData = data['createdAt'];
            // Timestamp can be unresolved briefly after write; use epoch fallback.
            final DateTime createdAt = createdAtData is Timestamp
                ? createdAtData.toDate()
                : DateTime(1970);

            return IncomingOffer(
              id: doc.id,
              listingId: listingId,
              // Keep cards readable if listing doc is deleted/missing title.
              listingTitle:
                  (listingData['title'] as String?) ?? 'Untitled Listing',
              buyerId: (data['buyerId'] as String?) ?? 'Unknown buyer',
              buyerName:
                buyerNamesById[(data['buyerId'] as String?) ?? ''] ??
                (data['buyerId'] as String?) ??
                'Unknown buyer',
              // UI relies on lowercase status/type strings for simple comparisons.
              offerType: ((data['offerType'] as String?) ?? 'cash').toLowerCase(),
              amount: (data['amount'] as num?)?.toDouble(),
              message: (data['message'] as String?) ?? '',
              createdAt: createdAt,
            );
          }),
        );

        final List<IncomingOffer> safeOffers =
            offers.whereType<IncomingOffer>().toList(growable: false);
        // Newest first keeps fresh requests visible at the top.
        safeOffers.sort(
          (IncomingOffer a, IncomingOffer b) => b.createdAt.compareTo(a.createdAt),
        );
        return safeOffers;
      });
});
