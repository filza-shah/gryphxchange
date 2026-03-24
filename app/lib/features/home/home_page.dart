import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/search_bar.dart';
import '../../core/providers/listings_provider.dart';
import '../../models/mock_data.dart';
import '../../core/widgets/listing_card.dart';

// HomePage is a ConsumerWidget so it can access Riverpod providers
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Listing> _filteredListings(List<Listing> listings) {
    if (_searchQuery.isEmpty) return listings;
    final String query = _searchQuery.toLowerCase();
    return listings.where((Listing listing) {
      return listing.title.toLowerCase().contains(query) ||
          listing.courseCode.toLowerCase().contains(query) ||
          listing.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(listingsStreamProvider);

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentRoute: '/home'),
      body: Column(
        children: [
          const AppHeader(title: 'Listings'),
          ListingSearchBar(
            controller: _searchController,
            onChanged: (String value) => setState(() => _searchQuery = value),
          ),
          //expanded widget to fill space with the listings
          Expanded(
            child: listingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Unable to load listings right now. Please try again.',
                    style: TextStyle(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (listings) {
                final filteredListings = _filteredListings(listings);

                if (filteredListings.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No listings found.'
                          : 'No listings match your search.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredListings.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListingCard(listing: filteredListings[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
 