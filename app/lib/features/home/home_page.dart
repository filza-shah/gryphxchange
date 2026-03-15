import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/search_bar.dart';
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

  //filters listings based on search 
  List<Listing> get _filteredListings {
    //if search is emtpy just return all mock listings 
    if (_searchQuery.isEmpty) return mockListings;
    final String query = _searchQuery.toLowerCase();
    // Filter listings by title course code or category
    return mockListings.where((Listing listing) {
      return listing.title.toLowerCase().contains(query) ||
          listing.courseCode.toLowerCase().contains(query) ||
          listing.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredListings.length,
              itemBuilder: (BuildContext context, int index) {
                //display each listing usign the listingCard widget
                return ListingCard(listing: _filteredListings[index]);
              }
            )
          ),
        ],
      ),
    );
  }
}
 