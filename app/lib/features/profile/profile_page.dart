import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/star_rating.dart';
import '../../models/mock_data.dart';
import '../../models/listing_firestore_mapper.dart';
import '../../services/workflow/workflow_controller.dart';
import '../../services/workflow/workflow_state.dart';

final profileUserProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final User? authUser = FirebaseAuth.instance.currentUser;
  if (authUser == null) {
    return Stream.value(<String, dynamic>{
      'name': 'Guest',
      'email': 'Not signed in',
      'rating': 0.0,
      'totalRatings': 0,
      'completedTrades': 0,
    });
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((doc) {
        final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
        final String fallbackName = (authUser.displayName != null &&
                authUser.displayName!.trim().isNotEmpty)
            ? authUser.displayName!.trim()
            : (authUser.email?.split('@').first ?? 'GryphXChange User').toUpperCase();

        return <String, dynamic>{
          'name': (data['name'] as String?) ?? fallbackName,
          'email': (data['email'] as String?) ?? authUser.email ?? '',
          'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
          'totalRatings': (data['totalRatings'] as num?)?.toInt() ?? 0,
          'completedTrades': (data['completedTrades'] as num?)?.toInt() ?? 0,
        };
      });
});

final myListingsProvider = StreamProvider<List<Listing>>((ref) {
  final User? authUser = FirebaseAuth.instance.currentUser;
  if (authUser == null) {
    return Stream.value(const <Listing>[]);
  }

  return FirebaseFirestore.instance
      .collection('listings')
      .where('sellerId', isEqualTo: authUser.uid)
      .snapshots()
      .map((snapshot) {
        final List<Listing> activeListings = <Listing>[];
        for (final doc in snapshot.docs) {
          final String status =
              ((doc.data()['status'] as String?) ?? 'active').toLowerCase();
          if (status != 'completed' && status != 'sold' && status != 'traded') {
            activeListings.add(
              listingFromFirestoreMap(id: doc.id, data: doc.data()),
            );
          }
        }

        activeListings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return activeListings;
      });
});

final myCompletedListingsProvider = StreamProvider<List<Listing>>((ref) {
  final User? authUser = FirebaseAuth.instance.currentUser;
  if (authUser == null) {
    return Stream.value(const <Listing>[]);
  }

  return FirebaseFirestore.instance
      .collection('listings')
      .where('sellerId', isEqualTo: authUser.uid)
      .snapshots()
      .map((snapshot) {
        final List<Listing> completedListings = <Listing>[];
        for (final doc in snapshot.docs) {
          final String status =
              ((doc.data()['status'] as String?) ?? 'active').toLowerCase();
          if (status == 'completed' || status == 'sold' || status == 'traded') {
            completedListings.add(
              listingFromFirestoreMap(id: doc.id, data: doc.data()),
            );
          }
        }
        completedListings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return completedListings;
      });
});

/// Profile page for the currently logged-in user
/// We're gonna use a mock user for now, 
/// but this page will eventually read from auth state to get the current user's info
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, required this.workflowController});

  final WorkflowController workflowController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds automatically whenever WorkflowController notifies listeners
    return AnimatedBuilder(
      animation: workflowController,
      builder: (BuildContext context, Widget? child) {
        // Latest persisted workflow state (trust score, hidden/completed listings, etc)
        final WorkflowState workflowState = workflowController.state;
        final profileUserAsync = ref.watch(profileUserProvider);
        final userListingsAsync = ref.watch(myListingsProvider);
        final completedListingsAsync = ref.watch(myCompletedListingsProvider);

        return Scaffold(
          bottomNavigationBar: const AppBottomNav(currentRoute: '/profile'),
          body: profileUserAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => const Center(
              child: Text('Unable to load profile right now.'),
            ),
            data: (profileUser) {
              final String displayName =
                  (profileUser['name'] as String?)?.trim().isNotEmpty == true
                  ? (profileUser['name'] as String).trim().toUpperCase()
                  : 'GRYPHXCHANGE USER';

              return ListView(
              children: <Widget>[
              // Top profile header (identity, verification, rating, trust score)
              Container(
                color: const Color(0xFF8B0000),
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFFFFD700),
                        child: Text(
                          displayName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF8B0000),
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            profileUser['email'] as String? ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFFFFD700),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          StarRating(
                            value:
                                (profileUser['rating'] as num?)?.toDouble() ??
                                0,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(profileUser['rating'] as num?)?.toDouble() ?? 0} (${(profileUser['totalRatings'] as num?)?.toInt() ?? 0} reviews)',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Trust Score: ${workflowState.trustScore}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Quick stats cards
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: <Widget>[
                                  Icon(
                                    Icons.local_shipping,
                                    size: 38,
                                    color: Color(0xFF8B0000),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '${(profileUser['completedTrades'] as num?)?.toInt() ?? 0}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 24,
                                    ),
                                  ),
                                  Text('Completed Trades'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: <Widget>[
                                  const Icon(
                                    Icons.attach_money,
                                    size: 38,
                                    color: Color(0xFFFFD700),
                                  ),
                                  const SizedBox(height: 6),
                                  userListingsAsync.when(
                                    loading: () => const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    error: (error, stackTrace) => const Text('--'),
                                    data: (userListings) => Text(
                                      '${userListings.length}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ),
                                  const Text('Active Listings'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'My Listings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Active listings owned by current user
                    userListingsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Unable to load your listings right now.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      data: (userListings) {
                        if (userListings.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: <Widget>[
                                  Text(
                                    "You haven't posted any listings yet",
                                    style: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () {
                                      context.go('/create');
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B0000),
                                    ),
                                    child: const Text('Create Your First Listing'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: userListings.map((listing) {
                            final String previewImage = listing.images.isNotEmpty
                                ? listing.images.first
                                : 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () {
                                  context.push('/listing/${listing.id}');
                                },
                                child: Row(
                                  children: <Widget>[
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                      child: Image.network(
                                        previewImage,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              listing.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              listing.courseCode,
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              listing.isTrade
                                                  ? 'Trade'
                                                  : '\$${listing.price?.toStringAsFixed(0) ?? ''}',
                                              style: const TextStyle(
                                                color: Color(0xFF8B0000),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(growable: false),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    completedListingsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) => Text(
                        'Unable to load transaction history right now.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      data: (completedListings) {
                        if (completedListings.isEmpty) {
                          return Text(
                            'No completed transactions yet.',
                            style: TextStyle(color: Colors.grey.shade700),
                          );
                        }

                        return Column(
                          children: completedListings.map((listing) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      listing.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Chip(label: Text('Completed')),
                                  ],
                                ),
                              ),
                            );
                          }).toList(growable: false),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.settings,
                        color: Color(0xFF8B0000),
                      ),
                      title: const Text('Account Settings'),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.help, color: Color(0xFF8B0000)),
                      title: const Text('Help & Support'),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Color(0xFF8B0000),
                      ),
                      title: const Text('Logout'),
                      onTap: () {
                        // sign out the user and return to login page. Router redirect rules will also prevent access to protected routes after logout
                        ref.read(authServiceProvider).signOut();
                        context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
              ],
            );
            },
          ),
        );
      },
    );
  }
}
