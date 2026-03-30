import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../models/mock_data.dart';
import '../../services/workflow/workflow_controller.dart';
import '../../services/workflow/workflow_state.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key, required this.workflowController});

  final WorkflowController workflowController;

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> with SingleTickerProviderStateMixin {
  final TextEditingController _newItemController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _selectedFilter = 'all'; // For filtering matches

  // For storing additional item details
  final Map<String, WishlistItemDetails> _itemDetails = {};

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  List<_WishlistMatch> _matches(WorkflowState workflowState) {
    final List<String> terms = workflowState.wishlist
        .map(_normalize)
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);

    if (terms.isEmpty) {
      return <_WishlistMatch>[];
    }

    // Get matches from listings with scores
    final List<_WishlistMatch> listingMatches = mockListings
        .where((Listing listing) => !workflowState.hiddenListingIds.contains(listing.id))
        .where((Listing listing) {
          final haystack = '${listing.title} ${listing.courseCode} ${listing.description}'.toLowerCase();
          return terms.any(haystack.contains);
        })
        .map((Listing listing) {
          double matchScore = _calculateMatchScore(terms, listing);
          List<String> matchReasons = _getMatchReasons(terms, listing);
          
          return _WishlistMatch(
            id: 'listing-${listing.id}',
            type: listing.isTrade ? MatchType.trade : MatchType.sale,
            title: listing.title,
            subtitle: listing.isTrade
                ? 'Trade listing • ${listing.courseCode}'
                : 'Sale listing • \$${listing.price?.toStringAsFixed(0) ?? ''} • ${listing.courseCode}',
            listingId: listing.id,
            matchScore: matchScore,
            matchReasons: matchReasons,
          );
        })
        .toList(growable: false);

    // Get matches from active trades
    final List<_WishlistMatch> activeTradeMatches = mockTrades
        .where((Trade trade) {
          final WorkflowTradeState? workflowTrade = workflowState.tradeStates[trade.id];
          return workflowTrade != null && 
              (workflowTrade.status == WorkflowTradeStatus.accepted ||
               workflowTrade.status == WorkflowTradeStatus.scheduled ||
               workflowTrade.status == WorkflowTradeStatus.ready);
        })
        .map((Trade trade) => _WishlistMatch(
          id: 'trade-${trade.id}',
          type: trade.offerType == OfferType.trade ? MatchType.trade : MatchType.sale,
          title: '${trade.listing.title} (${trade.id.toUpperCase()})',
          subtitle: trade.offerType == OfferType.trade ? 'Trade match found' : 'Sale match found',
          listingId: trade.listingId,
          matchScore: 0.9,
          matchReasons: ['Active trade offer', 'Seller is responsive'],
        ))
        .toList(growable: false);

    // Combine and sort by match score
    final Set<String> seen = <String>{};
    List<_WishlistMatch> allMatches = <_WishlistMatch>[...activeTradeMatches, ...listingMatches]
        .where((match) => seen.add(match.id))
        .toList(growable: false);
    
    allMatches.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    
    // Apply filter
    if (_selectedFilter == 'trade') {
      allMatches = allMatches.where((m) => m.type == MatchType.trade).toList();
    } else if (_selectedFilter == 'sale') {
      allMatches = allMatches.where((m) => m.type == MatchType.sale).toList();
    }
    
    return allMatches;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWishlistDetails();
  }

  @override
  void dispose() {
    _newItemController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadWishlistDetails() {
    final workflowState = widget.workflowController.state;
    for (var item in workflowState.wishlist) {
      if (!_itemDetails.containsKey(item)) {
        _itemDetails[item] = WishlistItemDetails(
          title: item,
          description: '',
          category: _guessCategory(item),
          maxPrice: null,
          isUrgent: false,
          tags: [],
          createdAt: DateTime.now(),
        );
      }
    }
  }

  String _guessCategory(String itemTitle) {
    final title = itemTitle.toLowerCase();
    if (title.contains('textbook') || title.contains('book')) return 'Textbooks';
    if (title.contains('calc') || title.contains('calculator')) return 'Electronics';
    if (title.contains('furniture') || title.contains('desk')) return 'Furniture';
    if (title.contains('shirt') || title.contains('hoodie')) return 'Clothing';
    return 'Other';
  }

  double _calculateMatchScore(List<String> terms, Listing listing) {
    double score = 0.0;
    final listingText = '${listing.title} ${listing.courseCode} ${listing.description}'.toLowerCase();
    
    for (var term in terms) {
      if (listingText.contains(term)) score += 0.3;
      if (listing.title.toLowerCase().contains(term)) score += 0.5;
    }
    return score.clamp(0.0, 1.0);
  }

  List<String> _getMatchReasons(List<String> terms, Listing listing) {
    List<String> reasons = [];
    final listingText = '${listing.title} ${listing.courseCode}'.toLowerCase();
    
    for (var term in terms) {
      if (listingText.contains(term)) {
        reasons.add('Matches keyword: "$term"');
        break;
      }
    }
    
    if (listing.price != null && listing.price! < 50) {
      reasons.add('Affordable price');
    }
    if (listing.isTrade) {
      reasons.add('Available for trade');
    }
    return reasons;
  }

  void _showAddWishlistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Wishlist'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newItemController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'What are you looking for?',
                  hintText: 'e.g., CIS*1300 textbook',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _guessCategory(_newItemController.text),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Textbooks', child: Text('Textbooks')),
                  DropdownMenuItem(value: 'Electronics', child: Text('Electronics')),
                  DropdownMenuItem(value: 'Furniture', child: Text('Furniture')),
                  DropdownMenuItem(value: 'Clothing', child: Text('Clothing')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_newItemController.text.trim().isNotEmpty) {
                widget.workflowController.addWishlistItem(_newItemController.text.trim());
                _newItemController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to wishlist!')),
                );
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditWishlistItemDialog(String item) {
    final details = _itemDetails[item] ?? WishlistItemDetails(
      title: item,
      description: '',
      category: _guessCategory(item),
      maxPrice: null,
      isUrgent: false,
      tags: [],
      createdAt: DateTime.now(),
    );
    
    final titleController = TextEditingController(text: item);
    bool isUrgent = details.isUrgent;
    String category = details.category;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Wishlist Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Item',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Textbooks', child: Text('Textbooks')),
                    DropdownMenuItem(value: 'Electronics', child: Text('Electronics')),
                    DropdownMenuItem(value: 'Furniture', child: Text('Furniture')),
                    DropdownMenuItem(value: 'Clothing', child: Text('Clothing')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setStateDialog(() {
                      category = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isUrgent,
                      onChanged: (value) {
                        setStateDialog(() {
                          isUrgent = value!;
                        });
                      },
                    ),
                    const Text('Mark as urgent'),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _itemDetails[item] = WishlistItemDetails(
                    title: titleController.text,
                    description: details.description,
                    category: category,
                    maxPrice: details.maxPrice,
                    isUrgent: isUrgent,
                    tags: details.tags,
                    createdAt: details.createdAt,
                  );
                  
                  if (titleController.text != item) {
                    widget.workflowController.removeWishlistItem(item);
                    widget.workflowController.addWishlistItem(titleController.text);
                  }
                  
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wishlist item updated!')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(String item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove "$item" from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.workflowController.removeWishlistItem(item);
              _itemDetails.remove(item);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed $item from wishlist')),
              );
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearWishlistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Wishlist'),
        content: const Text('Remove all items from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final items = List.from(widget.workflowController.state.wishlist);
              for (var item in items) {
                widget.workflowController.removeWishlistItem(item);
                _itemDetails.remove(item);
              }
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wishlist cleared')),
              );
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.workflowController,
      builder: (BuildContext context, Widget? child) {
        final WorkflowState workflowState = widget.workflowController.state;
        final List<_WishlistMatch> matches = _matches(workflowState);

        final List<_WishlistMatch> saleMatches = matches
            .where((_WishlistMatch match) => match.type == MatchType.sale)
            .toList(growable: false);
        final List<_WishlistMatch> tradeMatches = matches
            .where((_WishlistMatch match) => match.type == MatchType.trade)
            .toList(growable: false);

        return Scaffold(
          bottomNavigationBar: const AppBottomNav(currentRoute: '/wishlist'),
          body: Column(
            children: <Widget>[
              AppHeader(
                title: 'Wishlist',
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      showSearch(
                        context: context,
                        delegate: WishlistSearchDelegate(workflowState.wishlist),
                      );
                    },
                  ),
                ],
              ),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF8B0000),
                indicatorColor: const Color(0xFF8B0000),
                tabs: <Widget>[
                  Tab(text: 'My Wishlist (${workflowState.wishlist.length})'),
                  Tab(text: 'Matches (${matches.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    // Wishlist Tab
                    _buildWishlistTab(workflowState),
                    // Matches Tab
                    _buildMatchesTab(matches, tradeMatches, saleMatches),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWishlistTab(WorkflowState workflowState) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Add What You Are Looking For',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newItemController,
                        decoration: const InputDecoration(
                          labelText: 'Wishlist Item',
                          hintText: 'e.g., CIS*1300 textbook',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _newItemController.text.trim().isEmpty
                          ? null
                          : () {
                              widget.workflowController
                                  .addWishlistItem(_newItemController.text.trim());
                              _newItemController.clear();
                              setState(() {});
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B0000),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _showAddWishlistDialog,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Advanced Add'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Managed Wishlist',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (workflowState.wishlist.isNotEmpty)
                      TextButton(
                        onPressed: _showClearWishlistDialog,
                        child: const Text(
                          'Clear All',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (workflowState.wishlist.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your wishlist is empty',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: workflowState.wishlist.length,
                    itemBuilder: (context, index) {
                      final item = workflowState.wishlist[index];
                      final details = _itemDetails[item];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: details?.isUrgent == true
                                ? Colors.red.shade100
                                : Colors.grey.shade200,
                            child: Icon(
                              details?.isUrgent == true
                                  ? Icons.priority_high
                                  : _getCategoryIcon(details?.category),
                              size: 20,
                            ),
                          ),
                          title: Text(item),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showEditWishlistItemDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _showDeleteConfirmation(item),
                              ),
                            ],
                          ),
                          onTap: () => _showEditWishlistItemDialog(item),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchesTab(
    List<_WishlistMatch> matches,
    List<_WishlistMatch> tradeMatches,
    List<_WishlistMatch> saleMatches,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('Filter: '),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('All'),
                selected: _selectedFilter == 'all',
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = 'all';
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Trade (${tradeMatches.length})'),
                selected: _selectedFilter == 'trade',
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = 'trade';
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Sale (${saleMatches.length})'),
                selected: _selectedFilter == 'sale',
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = 'sale';
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: ListTile(
                  title: const Text(
                    'Found Trades and Sales',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Trade matches: ${tradeMatches.length} • Sale matches: ${saleMatches.length}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (matches.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matches found yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...matches.map((match) => _buildMatchCard(match)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(_WishlistMatch match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/listing/${match.listingId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      match.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: match.type == MatchType.trade
                          ? const Color(0x40FFD700)
                          : const Color(0x1A8B0000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      match.type == MatchType.trade
                          ? 'Trade Match'
                          : 'Sale Match',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: match.type == MatchType.trade
                            ? Colors.brown.shade700
                            : const Color(0xFF8B0000),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(match.subtitle),
              if (match.matchScore > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${(match.matchScore * 100).toInt()}% match',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              if (match.matchReasons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 4,
                    children: match.matchReasons.map((reason) {
                      return Chip(
                        label: Text(
                          reason,
                          style: const TextStyle(fontSize: 10),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    context.push('/listing/${match.listingId}');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B0000),
                  ),
                  child: const Text('View Listing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Textbooks':
        return Icons.menu_book;
      case 'Electronics':
        return Icons.devices;
      case 'Furniture':
        return Icons.chair;
      case 'Clothing':
        return Icons.checkroom;
      default:
        return Icons.favorite;
    }
  }
}

enum MatchType { sale, trade }

class _WishlistMatch {
  const _WishlistMatch({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.listingId,
    this.matchScore = 0.0,
    this.matchReasons = const [],
  });

  final String id;
  final MatchType type;
  final String title;
  final String subtitle;
  final String listingId;
  final double matchScore;
  final List<String> matchReasons;
}

class WishlistItemDetails {
  final String title;
  final String description;
  final String category;
  final double? maxPrice;
  final bool isUrgent;
  final List<String> tags;
  final DateTime createdAt;

  WishlistItemDetails({
    required this.title,
    required this.description,
    required this.category,
    this.maxPrice,
    required this.isUrgent,
    required this.tags,
    required this.createdAt,
  });
}

class WishlistSearchDelegate extends SearchDelegate<String> {
  final List<String> wishlistItems;

  WishlistSearchDelegate(this.wishlistItems);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear),
      onPressed: () => query = '',
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) {
    final results = wishlistItems
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
    
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(results[index]),
        onTap: () => close(context, results[index]),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = wishlistItems
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
    
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(suggestions[index]),
        onTap: () {
          query = suggestions[index];
          showResults(context);
        },
      ),
    );
  }
}