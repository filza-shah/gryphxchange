import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth_provider.dart';

// View model for buyer-side offer tracking cards in Trades.
class SentOffer {
  const SentOffer({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.sellerId,
    required this.sellerName,
    required this.offerType,
    required this.amount,
    required this.message,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
    required this.respondedAt,
  });

  final String id;
  final String listingId;
  final String listingTitle;
  final String sellerId;
  final String sellerName;
  final String offerType;
  final double? amount;
  final String message;
  final String status;
  final String rejectionReason;
  final DateTime createdAt;
  final DateTime? respondedAt;
}

final sentOffersProvider = StreamProvider<List<SentOffer>>((ref) {
  // Re-query sent offers whenever auth user changes.
  final User? authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) {
    return Stream.value(const <SentOffer>[]);
  }

  // Buyer history: include all statuses so users can track outcomes.
  return FirebaseFirestore.instance
      .collection('offers')
      .where('buyerId', isEqualTo: authUser.uid)
      .snapshots()
      .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
        final Set<String> sellerIds = snapshot.docs
            .map((doc) => (doc.data()['sellerId'] as String?) ?? '')
            .where((sellerId) => sellerId.isNotEmpty)
            .toSet();

        final Map<String, String> sellerNamesById = <String, String>{};
        await Future.wait<void>(
          sellerIds.map((String sellerId) async {
            final DocumentSnapshot<Map<String, dynamic>> userDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(sellerId)
                    .get();

            final Map<String, dynamic> userData =
                userDoc.data() ?? <String, dynamic>{};
            final String name = ((userData['name'] as String?) ??
                    (userData['displayName'] as String?) ??
                    (userData['fullName'] as String?) ??
                    (userData['username'] as String?) ??
                    '')
                .trim();
            sellerNamesById[sellerId] =
                name.isNotEmpty ? name : 'Unknown seller';
          }),
        );

        // Enrich with listing title for readable cards without extra lookups in UI.
        final List<SentOffer?> offers = await Future.wait<SentOffer?>(
          snapshot.docs.map((doc) async {
            final Map<String, dynamic> data = doc.data();
            // listingId is the join key for listing metadata and deep-linking.
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
            // Preserve sort stability even when server timestamp is not resolved yet.
            final DateTime createdAt = createdAtData is Timestamp
                ? createdAtData.toDate()
                : DateTime(1970);
            final dynamic respondedAtData = data['respondedAt'];
            final DateTime? respondedAt = respondedAtData is Timestamp
                ? respondedAtData.toDate()
                : null;

            // Normalize once at the data layer so UI stays declarative.
            final String normalizedStatus =
                ((data['status'] as String?) ?? 'pending').toLowerCase();
            final String sellerId = (data['sellerId'] as String?) ?? '';

            return SentOffer(
              id: doc.id,
              listingId: listingId,
              // Defensive fallback if listing was deleted after offer submission.
              listingTitle:
                  (listingData['title'] as String?) ?? 'Untitled Listing',
              sellerId: sellerId,
              sellerName: sellerNamesById[sellerId] ?? 'Unknown seller',
              offerType: ((data['offerType'] as String?) ?? 'cash').toLowerCase(),
              amount: (data['amount'] as num?)?.toDouble(),
              message: (data['message'] as String?) ?? '',
              status: normalizedStatus,
              // Empty reason still renders with UI default copy.
              rejectionReason:
                  (data['rejectionReason'] as String?) ?? '',
              createdAt: createdAt,
              respondedAt: respondedAt,
            );
          }),
        );

        final List<SentOffer> safeOffers =
            offers.whereType<SentOffer>().toList(growable: false);
        // Surface most recent activity first to match user expectations.
        safeOffers.sort(
          (SentOffer a, SentOffer b) => b.createdAt.compareTo(a.createdAt),
        );
        return safeOffers;
      });
});
