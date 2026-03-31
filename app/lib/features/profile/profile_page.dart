import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/star_rating.dart';
import '../../models/mock_data.dart';
import '../../models/listing_firestore_mapper.dart';
import '../../services/workflow/workflow_controller.dart';

final profileUserProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final User? authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) {
    // Stable guest payload keeps the profile screen renderable pre-login.
    return Stream.value(<String, dynamic>{
      'name': 'Guest',
      'email': 'Not signed in',
      'rating': 0.0,
      'totalRatings': 0,
      'completedTrades': 0,
      'trustScore': 0,
    });
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((doc) {
        final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
        final String fallbackName =
            (authUser.displayName != null &&
                authUser.displayName!.trim().isNotEmpty)
            ? authUser.displayName!.trim()
            : (authUser.email?.split('@').first ?? 'GryphXChange User')
                  .toUpperCase();

        return <String, dynamic>{
          'name': (data['name'] as String?) ?? fallbackName,
          'email': (data['email'] as String?) ?? authUser.email ?? '',
          'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
          'totalRatings': (data['totalRatings'] as num?)?.toInt() ?? 0,
          'completedTrades': (data['completedTrades'] as num?)?.toInt() ?? 0,
          'trustScore': (data['trustScore'] as num?)?.toInt() ?? 0,
        };
      });
});

final myListingsProvider = StreamProvider<List<Listing>>((ref) {
  final User? authUser = ref.watch(authStateProvider).asData?.value;
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
          final String status = ((doc.data()['status'] as String?) ?? 'active')
              .toLowerCase();
          if (status != 'completed' &&
              status != 'sold' &&
              status != 'traded' &&
              status != 'inactive' &&
              status != 'deleted') {
            activeListings.add(
              listingFromFirestoreMap(id: doc.id, data: doc.data()),
            );
          }
        }

        // Firestore query cannot filter multiple status values directly here,
        // so we trim and sort client-side for now.
        activeListings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return activeListings;
      });
});

final myCompletedListingsProvider = StreamProvider<List<Listing>>((ref) {
  final User? authUser = ref.watch(authStateProvider).asData?.value;
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
          final String status = ((doc.data()['status'] as String?) ?? 'active')
              .toLowerCase();
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

  Future<void> _confirmDeleteListing(
    BuildContext context,
    Listing listing,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Listing?'),
          content: Text(
            'This will permanently remove "${listing.title}" if there are no linked offers or trades.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final QuerySnapshot<Map<String, dynamic>> relatedOffers = await firestore
          .collection('offers')
          .where('listingId', isEqualTo: listing.id)
          .limit(1)
          .get();

      // keep this guard in place so we do not orphan offer/trade records.
      if (relatedOffers.docs.isNotEmpty) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This listing already has related offers or trades, so it cannot be permanently deleted.',
            ),
          ),
        );
        return;
      }

      // lil cleanup pass: only Firebase Storage urls can be deleted here.
      for (final String imageUrl in listing.images) {
        if (!imageUrl.contains('firebasestorage.googleapis.com')) {
          continue;
        }

        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (_) {
          // if image cleanup fails, we still want the doc delete to go through.
        }
      }

      await firestore.collection('listings').doc(listing.id).delete();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing deleted successfully.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the listing right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds automatically whenever WorkflowController notifies listeners
    return AnimatedBuilder(
      animation: workflowController,
      builder: (BuildContext context, Widget? child) {
        final profileUserAsync = ref.watch(profileUserProvider);
        final userListingsAsync = ref.watch(myListingsProvider);
        final completedListingsAsync = ref.watch(myCompletedListingsProvider);

        return Scaffold(
          bottomNavigationBar: const AppBottomNav(currentRoute: '/profile'),
          body: profileUserAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const Center(child: Text('Unable to load profile right now.')),
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
                                    (profileUser['rating'] as num?)
                                        ?.toDouble() ??
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
                            'Trust Score: ${(profileUser['trustScore'] as num?)?.toInt() ?? 0}',
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
                                        error: (error, stackTrace) =>
                                            const Text('--'),
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
                                        "You don't have any active listings",
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                        onPressed: () {
                                          context.go('/create');
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF8B0000,
                                          ),
                                        ),
                                        child: const Text('Create a Listing'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children: userListings
                                  .map((listing) {
                                    final String previewImage =
                                        listing.images.isNotEmpty
                                        ? listing.images.first
                                        : 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400';

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: InkWell(
                                        onTap: () {
                                          context.push(
                                            '/listing/${listing.id}',
                                          );
                                        },
                                        child: Row(
                                          children: <Widget>[
                                            ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(
                                                      12,
                                                    ),
                                                    bottomLeft: Radius.circular(
                                                      12,
                                                    ),
                                                  ),
                                              child: _ProfileListingThumbnail(
                                                imagePathOrUrl: previewImage,
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    // quick seller controls live right beside each card,
                                                    // so managing your own listings stays dead simple.
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: <Widget>[
                                                        Expanded(
                                                          child: Text(
                                                            listing.title,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                        PopupMenuButton<String>(
                                                          onSelected: (String value) {
                                                            if (value ==
                                                                'edit') {
                                                              context.push(
                                                                '/listing/${listing.id}/edit',
                                                              );
                                                              return;
                                                            }
                                                            if (value ==
                                                                'delete') {
                                                              _confirmDeleteListing(
                                                                context,
                                                                listing,
                                                              );
                                                            }
                                                          },
                                                          itemBuilder: (BuildContext context) =>
                                                              const <
                                                                PopupMenuEntry<
                                                                  String
                                                                >
                                                              >[
                                                                PopupMenuItem<
                                                                  String
                                                                >(
                                                                  value: 'edit',
                                                                  child: Text(
                                                                    'Edit listing',
                                                                  ),
                                                                ),
                                                                PopupMenuItem<
                                                                  String
                                                                >(
                                                                  value:
                                                                      'delete',
                                                                  child: Text(
                                                                    'Delete listing',
                                                                  ),
                                                                ),
                                                              ],
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      listing.courseCode,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade700,
                                                      ),
                                                    ),
                                                    Text(
                                                      listing.isTrade
                                                          ? 'Trade'
                                                          : '\$${listing.price?.toStringAsFixed(0) ?? ''}',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF8B0000,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                  })
                                  .toList(growable: false),
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
                              children: completedListings
                                  .map((listing) {
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              listing.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            const Chip(
                                              label: Text('Completed'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(growable: false),
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
                          leading: const Icon(
                            Icons.help,
                            color: Color(0xFF8B0000),
                          ),
                          title: const Text('Help & Support'),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.logout,
                            color: Color(0xFF8B0000),
                          ),
                          title: const Text('Logout'),
                          onTap: () async {
                            // sign out the user and return to login page. Router redirect rules will also prevent access to protected routes after logout
                            await ref.read(authServiceProvider).signOut();
                            workflowController.resetWorkflowState();
                            if (context.mounted) {
                              context.go('/login');
                            }
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

class _ProfileListingThumbnail extends StatelessWidget {
  const _ProfileListingThumbnail({required this.imagePathOrUrl});

  final String imagePathOrUrl;

  Future<String?> _resolveImageUrl() async {
    final String value = imagePathOrUrl.trim();
    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    try {
      // Some older docs store Storage paths instead of public download URLs.
      if (value.startsWith('gs://')) {
        return await FirebaseStorage.instance.refFromURL(value).getDownloadURL();
      }

      if (!value.contains('://')) {
        return await FirebaseStorage.instance.ref(value).getDownloadURL();
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveImageUrl(),
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        final String? resolvedUrl = snapshot.data;
        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          return _thumbnailFallback(context);
        }

        return Image.network(
          resolvedUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _thumbnailFallback(context),
        );
      },
    );
  }

  Widget _thumbnailFallback(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey.shade600,
      ),
    );
  }
}
