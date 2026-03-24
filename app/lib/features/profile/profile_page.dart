import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/star_rating.dart';
import '../../models/mock_data.dart';
import '../../services/workflow/workflow_controller.dart';
import '../../services/workflow/workflow_state.dart';

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

        // Listings posted by the current user that are still active (not hidden/completed)
        final List<Listing> userListings = mockListings
            .where(
              (Listing listing) =>
                  listing.sellerId == currentUser.id &&
                  !workflowState.hiddenListingIds.contains(listing.id),
            )
            .toList(growable: false);

        // Listings that were marked as sold/traded in workflow state
        final List<Listing> completedListings = mockListings
            .where(
              (Listing listing) =>
                  workflowState.listingOutcome.containsKey(listing.id),
            )
            .toList(growable: false);

        return Scaffold(
          bottomNavigationBar: const AppBottomNav(currentRoute: '/profile'),
          body: ListView(
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
                          currentUser.name[0],
                          style: const TextStyle(
                            color: Color(0xFF8B0000),
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currentUser.name,
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
                            currentUser.email,
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
                          StarRating(value: currentUser.rating),
                          const SizedBox(width: 6),
                          Text(
                            '${currentUser.rating} (${currentUser.totalRatings} reviews)',
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
                                    '${currentUser.totalRatings}',
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
                                  Text(
                                    '${userListings.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 24,
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
                    if (userListings.isEmpty)
                      Card(
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
                                  // Route to create-listing flow
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
                      )
                    else
                      for (final Listing listing in userListings)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () {
                              // Open listing details while keeping tab stack behavior
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
                                    listing.images.first,
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
                    // Completed transactions (sold/traded), taken from workflow state
                    if (completedListings.isEmpty)
                      Text(
                        'No completed transactions yet.',
                        style: TextStyle(color: Colors.grey.shade700),
                      )
                    else
                      for (final Listing listing in completedListings)
                        Card(
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
                                Chip(
                                  label: Text(
                                    workflowState.listingOutcome[listing.id] ==
                                            'sold'
                                        ? 'Sold'
                                        : 'Traded',
                                  ),
                                ),
                              ],
                            ),
                          ),
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
          ),
        );
      },
    );
  }
}
