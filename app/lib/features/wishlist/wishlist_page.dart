import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../models/mock_data.dart';
import '../../services/workflow/workflow_controller.dart';
import '../../services/workflow/workflow_state.dart';
import '../../services/wishlist_firebase_service.dart';

/// Main Wishlist Page - Displays user's wishlist items and matches
/// Uses Firebase Firestore for permanent storage and real-time updates
class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key, required this.workflowController});

  final WorkflowController workflowController;

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> with SingleTickerProviderStateMixin {
  // ==================== SERVICES & CONTROLLERS ====================
  
  /// Firebase service for wishlist operations
  final WishlistFirebaseService _wishlistService = WishlistFirebaseService();
  
  /// Controller for the text input field (Quick Add)
  final TextEditingController _newItemController = TextEditingController();
  
  /// Tab controller for switching between Wishlist and Matches tabs
  late TabController _tabController;
  
  /// Current filter selection for matches (all, trade, sale)
  String _selectedFilter = 'all';
  
  /// Flag to prevent double-click and show loading state
  bool _isAdding = false;

  // ==================== LIFECYCLE METHODS ====================

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with 2 tabs (Wishlist & Matches)
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _newItemController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ==================== HELPER METHODS ====================

  /// Guess category based on item title keywords
  /// Used to auto-suggest category when adding items
  String _guessCategory(String itemTitle) {
    final title = itemTitle.toLowerCase();
    if (title.contains('textbook') || title.contains('book')) return 'Textbooks';
    if (title.contains('calc') || title.contains('calculator')) return 'Electronics';
    if (title.contains('furniture') || title.contains('desk')) return 'Furniture';
    if (title.contains('shirt') || title.contains('hoodie')) return 'Clothing';
    return 'Other';
  }

  /// Get icon based on category
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

  /// Find matches between wishlist items and available listings
  /// Uses mock data for now - can be replaced with Firebase queries later
  List<_WishlistMatch> _getMatches(List<String> wishlistTitles) {
    if (wishlistTitles.isEmpty) return [];
    
    // Normalize wishlist titles for matching
    final List<String> terms = wishlistTitles
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();

    // Search through mock listings for matches
    final matches = mockListings
        .where((listing) {
          // Combine all listing text for searching
          final haystack = '${listing.title} ${listing.courseCode} ${listing.description}'.toLowerCase();
          return terms.any(haystack.contains);
        })
        .map((listing) {
          // Calculate match score (0-1)
          double matchScore = 0.8; // Default score
          List<String> matchReasons = ['Matches your wishlist'];
          
          return _WishlistMatch(
            id: 'listing-${listing.id}',
            type: listing.isTrade ? MatchType.trade : MatchType.sale,
            title: listing.title,
            subtitle: listing.isTrade
                ? 'Trade listing • ${listing.courseCode}'
                : 'Sale listing • \$${listing.price?.toStringAsFixed(0) ?? ''}',
            listingId: listing.id,
            matchScore: matchScore,
            matchReasons: matchReasons,
          );
        })
        .toList();
    
    return matches;
  }

  // ==================== DIALOG METHODS ====================

  /// Show advanced add dialog with category, price, and urgency options
  void _showAddWishlistDialog() {
    String selectedCategory = 'Other';
    bool isUrgent = false;
    TextEditingController titleController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Add to Wishlist'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Item title input
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'What are you looking for? *',
                      hintText: 'e.g., CIS*1300 textbook',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
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
                        selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Max price input
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Max Price (optional)',
                      border: OutlineInputBorder(),
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  // Urgent checkbox
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isNotEmpty) {
                    try {
                      // Add to Firebase
                      await _wishlistService.addWishlistItem(
                        title: titleController.text.trim(),
                        category: selectedCategory,
                        isUrgent: isUrgent,
                        maxPrice: priceController.text.isNotEmpty 
                            ? double.parse(priceController.text) 
                            : null,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to wishlist!')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show edit dialog for existing wishlist item
  void _showEditWishlistItemDialog(String docId, Map<String, dynamic> itemData) {
    TextEditingController titleController = TextEditingController(text: itemData['title']);
    String category = itemData['category'] ?? 'Other';
    bool isUrgent = itemData['isUrgent'] ?? false;
    TextEditingController priceController = TextEditingController(
      text: itemData['maxPrice']?.toString() ?? '',
    );
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Wishlist Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title input
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Item',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Category dropdown
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
                // Price input
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Max Price (optional)',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                // Urgent checkbox
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
                onPressed: () async {
                  try {
                    // Update in Firebase
                    await _wishlistService.updateWishlistItem(
                      docId: docId,
                      title: titleController.text,
                      category: category,
                      isUrgent: isUrgent,
                      maxPrice: priceController.text.isNotEmpty 
                          ? double.parse(priceController.text) 
                          : null,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wishlist item updated!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation(String docId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove "$title" from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Delete from Firebase
                await _wishlistService.deleteWishlistItem(docId);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed $title from wishlist')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Show clear all wishlist confirmation dialog
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
            onPressed: () async {
              try {
                // Delete all items from Firebase
                await _wishlistService.clearAllWishlistItems();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wishlist cleared')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ==================== UI BUILDING METHODS ====================

  @override
  Widget build(BuildContext context) {
    // StreamBuilder for real-time Firebase updates
    return StreamBuilder<QuerySnapshot>(
      stream: _wishlistService.getUserWishlist(),
      builder: (context, snapshot) {
        // Handle errors
        if (snapshot.hasError) {
          return Scaffold(
            bottomNavigationBar: const AppBottomNav(currentRoute: '/wishlist'),
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        // Show loading indicator while fetching data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            bottomNavigationBar: const AppBottomNav(currentRoute: '/wishlist'),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Extract wishlist items from Firestore
        final wishlistDocs = snapshot.data?.docs ?? [];
        final wishlistItems = wishlistDocs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }).toList();
        
        // Get matches for current wishlist items
        final wishlistTitles = wishlistItems.map((item) => item['title'] as String).toList();
        final matches = _getMatches(wishlistTitles);
        
        // Separate matches by type for display
        final saleMatches = matches.where((m) => m.type == MatchType.sale).toList();
        final tradeMatches = matches.where((m) => m.type == MatchType.trade).toList();

        return Scaffold(
          bottomNavigationBar: const AppBottomNav(currentRoute: '/wishlist'),
          body: Column(
            children: <Widget>[
              // App header with title and search
              AppHeader(
                title: 'Wishlist',
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      // TODO: Implement search functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Search coming soon!')),
                      );
                    },
                  ),
                ],
              ),
              // Tab bar for switching between views
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF8B0000),
                indicatorColor: const Color(0xFF8B0000),
                tabs: <Widget>[
                  Tab(text: 'My Wishlist (${wishlistItems.length})'),
                  Tab(text: 'Matches (${matches.length})'),
                ],
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _buildWishlistTab(wishlistItems),
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

  /// Build the Wishlist tab content
  Widget _buildWishlistTab(List<Map<String, dynamic>> wishlistItems) {
    // StatefulBuilder allows local rebuilds without affecting parent
    return StatefulBuilder(
      builder: (context, setState) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // ========== ADD ITEM CARD ==========
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
                    // Quick Add row
                    Row(
                      children: [
                        // Text input field
                        Expanded(
                          child: TextField(
                            controller: _newItemController,
                            onChanged: (value) {
                              setState(() {}); // Trigger rebuild to update button state
                            },
                            decoration: const InputDecoration(
                              labelText: 'Wishlist Item',
                              hintText: 'e.g., CIS*1300 textbook',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Quick Add button (enables/disables based on text)
                        ElevatedButton(
                          onPressed: (_newItemController.text.trim().isEmpty || _isAdding)
                              ? null
                              : () async {
                                  setState(() {
                                    _isAdding = true; // Show loading state
                                  });
                                  try {
                                    await _wishlistService.addWishlistItem(
                                      title: _newItemController.text.trim(),
                                      category: _guessCategory(_newItemController.text),
                                    );
                                    _newItemController.clear();
                                    setState(() {
                                      _isAdding = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Added to wishlist!')),
                                    );
                                  } catch (e) {
                                    setState(() {
                                      _isAdding = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B0000), // GryphXChange red
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: _isAdding
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Quick Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Advanced Add button
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
            
            // ========== MANAGED WISHLIST CARD ==========
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Header with Clear All button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Managed Wishlist',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (wishlistItems.isNotEmpty)
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
                    
                    // Wishlist items list
                    if (wishlistItems.isEmpty)
                      // Empty state
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
                              const SizedBox(height: 8),
                              Text(
                                'Add items you\'re looking for',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // List of wishlist items
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: wishlistItems.length,
                        itemBuilder: (context, index) {
                          final item = wishlistItems[index];
                          final isUrgent = item['isUrgent'] ?? false;
                          final category = item['category'] ?? 'Other';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isUrgent
                                    ? Colors.red.shade100
                                    : Colors.grey.shade200,
                                child: Icon(
                                  isUrgent ? Icons.priority_high : _getCategoryIcon(category),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item['title'],
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showEditWishlistItemDialog(item['id'], item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: () => _showDeleteConfirmation(item['id'], item['title']),
                                  ),
                                ],
                              ),
                              onTap: () => _showEditWishlistItemDialog(item['id'], item),
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
      },
    );
  }

  /// Build the Matches tab content
  Widget _buildMatchesTab(
    List<_WishlistMatch> matches,
    List<_WishlistMatch> tradeMatches,
    List<_WishlistMatch> saleMatches,
  ) {
    // Apply filter based on selected filter
    List<_WishlistMatch> filteredMatches = matches;
    if (_selectedFilter == 'trade') {
      filteredMatches = tradeMatches;
    } else if (_selectedFilter == 'sale') {
      filteredMatches = saleMatches;
    }
    
    return Column(
      children: [
        // Filter chips
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
        
        // Matches list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Summary card
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
              
              // Matches content
              if (filteredMatches.isEmpty)
                // Empty state
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
                        const SizedBox(height: 8),
                        Text(
                          'Try adding more specific items to your wishlist',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredMatches.map((match) => _buildMatchCard(match)),
            ],
          ),
        ),
      ],
    );
  }

  /// Build a single match card
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
              // Title and type badge
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
                          ? const Color(0x40FFD700) // Yellow for trade
                          : const Color(0x1A8B0000), // Red for sale
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
              // Subtitle (price/course info)
              Text(match.subtitle),
              // Match score (if available)
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
              // Match reasons
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
              // View Listing button
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
}

// ==================== DATA MODELS ====================

/// Types of matches (Sale or Trade)
enum MatchType { sale, trade }

/// Internal model for wishlist matches
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