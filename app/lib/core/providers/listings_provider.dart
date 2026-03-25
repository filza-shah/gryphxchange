import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mock_data.dart';
import '../../models/listing_firestore_mapper.dart';

// Stream provider to fetch active listings from Firestore, ordered by creation date
// This will replace the mock listings we currently have in the home page once we integrate with the backend
final listingsStreamProvider = StreamProvider<List<Listing>>((ref) {
  return FirebaseFirestore.instance
      .collection('listings')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        final List<Listing> activeListings = <Listing>[];
        for (final doc in snapshot.docs) {
          final String status =
              ((doc.data()['status'] as String?) ?? 'active').toLowerCase();
          // Keep completed/sold/traded items out of the browse feed.
          if (status == 'completed' || status == 'sold' || status == 'traded') {
            continue;
          }
          activeListings.add(listingFromFirestoreMap(id: doc.id, data: doc.data()));
        }
        return activeListings;
      });
});