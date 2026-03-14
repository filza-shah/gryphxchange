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

class _WishlistPageState extends State<WishlistPage> {
  final TextEditingController _newItemController = TextEditingController();

  String _normalize(String value) {
    // keep matching chill and case-insensitive.
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

    // pull listing matches from static mock data for now.
    final List<_WishlistMatch> listingMatches = mockListings
        .where(
          (Listing listing) =>
              !workflowState.hiddenListingIds.contains(listing.id),
        )
        .where((Listing listing) {
          final String haystack =
              '${listing.title} ${listing.courseCode} ${listing.description}'
                  .toLowerCase();
          return terms.any(haystack.contains);
        })
        .map((Listing listing) {
          return _WishlistMatch(
            id: 'listing-${listing.id}',
            type: listing.isTrade ? MatchType.trade : MatchType.sale,
            title: listing.title,
            subtitle: listing.isTrade
                ? 'Trade listing • ${listing.courseCode}'
                : 'Sale listing • \$${listing.price?.toStringAsFixed(0) ?? ''} • ${listing.courseCode}',
            listingId: listing.id,
          );
        })
        .toList(growable: false);

    final List<_WishlistMatch> activeTradeMatches = mockTrades
        .where((Trade trade) {
          final WorkflowTradeState? workflowTrade =
              workflowState.tradeStates[trade.id];
          if (workflowTrade == null) {
            return false;
          }
          return workflowTrade.status == WorkflowTradeStatus.accepted ||
              workflowTrade.status == WorkflowTradeStatus.scheduled ||
              workflowTrade.status == WorkflowTradeStatus.ready;
        })
        .map(
          (Trade trade) => _WishlistMatch(
            id: 'trade-${trade.id}',
            type: trade.offerType == OfferType.trade
                ? MatchType.trade
                : MatchType.sale,
            title: '${trade.listing.title} (${trade.id.toUpperCase()})',
            subtitle: trade.offerType == OfferType.trade
                ? 'Trade match found'
                : 'Sale match found',
            listingId: trade.listingId,
          ),
        )
        .toList(growable: false);

    // de-dupe so repeated hits don't spam the UI.
    final Set<String> seen = <String>{};
    return <_WishlistMatch>[...activeTradeMatches, ...listingMatches]
        .where((_WishlistMatch match) {
          if (seen.contains(match.id)) {
            return false;
          }
          seen.add(match.id);
          return true;
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
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

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            bottomNavigationBar: const AppBottomNav(currentRoute: '/wishlist'),
            body: Column(
              children: <Widget>[
                AppHeader(
                  title: 'Wishlist',
                ),
                TabBar(
                  labelColor: const Color(0xFF8B0000),
                  indicatorColor: const Color(0xFF8B0000),
                  tabs: <Widget>[
                    Tab(text: 'My Wishlist (${workflowState.wishlist.length})'),
                    Tab(text: 'Matches (${matches.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      ListView(
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _newItemController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Wishlist Item',
                                      hintText: 'e.g., CIS*1300 textbook',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed:
                                          _newItemController.text.trim().isEmpty
                                          ? null
                                          : () {
                                              // quick add + clear flow so it feels snappy.
                                              widget.workflowController
                                                  .addWishlistItem(
                                                    _newItemController.text,
                                                  );
                                              _newItemController.clear();
                                              setState(() {});
                                            },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF8B0000,
                                        ),
                                      ),
                                      child: const Text('Add to Wishlist'),
                                    ),
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
                                  const Text(
                                    'Managed Wishlist',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (workflowState.wishlist.isEmpty)
                                    Text(
                                      'No items yet.',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: workflowState.wishlist
                                          .map(
                                            (String item) => Chip(
                                              label: Text(item),
                                              onDeleted: () {
                                                widget.workflowController
                                                    .removeWishlistItem(item);
                                              },
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      ListView(
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
                            Text(
                              'No matches yet. Add more wishlist keywords.',
                              style: TextStyle(color: Colors.grey.shade700),
                            )
                          else
                            for (final _WishlistMatch match in matches)
                              Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              match.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              match.type == MatchType.trade
                                                  ? 'Trade Match'
                                                  : 'Sale Match',
                                            ),
                                            backgroundColor:
                                                match.type == MatchType.trade
                                                ? const Color(0x40FFD700)
                                                : const Color(0x1A8B0000),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(match.subtitle),
                                      const SizedBox(height: 8),
                                      OutlinedButton(
                                        onPressed: () {
                                          context.push(
                                            '/listing/${match.listingId}',
                                          );
                                        },
                                        child: const Text('View Listing'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
  });

  final String id;
  final MatchType type;
  final String title;
  final String subtitle;
  final String listingId;
}
