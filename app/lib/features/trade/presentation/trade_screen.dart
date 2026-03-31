import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../models/display_trade.dart';
import 'providers/incoming_offers_provider.dart';
import 'providers/sent_offers_provider.dart';
import 'providers/display_trades_provider.dart';
import 'widgets/transaction_card.dart';

class TradeScreen extends ConsumerWidget {
  const TradeScreen({super.key});

  // Trades screen always keeps the same bottom nav wiring.
  Widget _buildScaffoldWithBody(Widget body) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentRoute: '/trades'),
      body: body,
    );
  }

  // Shared fallback for provider failures to reduce repeated scaffold code.
  Widget _buildErrorScaffold(Object error) {
    return _buildScaffoldWithBody(
      Center(child: Text('Error: $error')),
    );
  }

  // Shared loading state while any part of trades/offers data is resolving.
  Widget _buildLoadingScaffold() {
    return _buildScaffoldWithBody(
      const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trades and offers come from separate sources; we merge them per tab.
    final tradesAsync = ref.watch(displayTradesProvider);
    final incomingOffersAsync = ref.watch(incomingOffersProvider);
    final sentOffersAsync = ref.watch(sentOffersProvider);

    return tradesAsync.when(
      data: (trades) {
        final pending = trades
            .where((DisplayTrade trade) => trade.isPending)
            .toList(growable: false);
        final active = trades
            .where((DisplayTrade trade) => trade.isActive)
            .toList(growable: false);
        final completed = trades
            .where((DisplayTrade trade) => trade.isCompleted)
            .toList(growable: false);

        return incomingOffersAsync.when(
          data: (incomingOffers) => sentOffersAsync.when(
            data: (sentOffers) {
              // Sent offers are grouped by lifecycle status for tab counts/sections.
              final sentPending = sentOffers
                  .where((offer) => offer.status == 'pending')
                  .toList(growable: false);
              final sentInProgress = sentOffers
                  .where(
                  (offer) =>
                    offer.status == 'accepted' ||
                    offer.status == 'in_progress' ||
                    offer.status == 'scheduled' ||
                    offer.status == 'ready',
                  )
                  .toList(growable: false);
              final sentRejected = sentOffers
                  .where((offer) => offer.status == 'rejected')
                  .toList(growable: false);
              final sentCompleted = sentOffers
                  .where((offer) => offer.status == 'completed')
                  .toList(growable: false);

              // Final UI merges workflow trades with offer streams in one place.
              return DefaultTabController(
                length: 3,
                child: Scaffold(
                  bottomNavigationBar:
                      const AppBottomNav(currentRoute: '/trades'),
                  appBar: AppBar(
                    title: const Text('Active Trades & Offers'),
                    bottom: TabBar(
                      tabs: <Widget>[
                        Tab(
                          text:
                              'PENDING (${pending.length + incomingOffers.length + sentPending.length})',
                        ),
                        Tab(
                          text:
                              'IN PROGRESS (${active.length + sentInProgress.length})',
                        ),
                        Tab(
                          text:
                          'CLOSED (${completed.length + sentCompleted.length + sentRejected.length})',
                        ),
                      ],
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      indicatorColor: const Color(0xFFFFD700),
                    ),
                  ),
                  body: TabBarView(
                    children: [
                      _buildPendingList(
                        context,
                        pending,
                        incomingOffers,
                        sentPending,
                      ),
                      _buildInProgressList(context, active, sentInProgress),
                      _buildCompletedList(
                        context,
                        completed,
                        sentCompleted,
                        sentRejected,
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: _buildLoadingScaffold,
            error: (err, _) => _buildErrorScaffold(err),
          ),
          loading: _buildLoadingScaffold,
          error: (err, _) => _buildErrorScaffold(err),
        );
      },
      loading: _buildLoadingScaffold,
      error: (err, _) => _buildErrorScaffold(err),
    );
  }

  Widget _buildPendingList(
    BuildContext context,
    List<DisplayTrade> pendingTrades,
    List<IncomingOffer> incomingOffers,
    List<SentOffer> sentPendingOffers,
  ) {
    // Pending combines action-needed items for both seller and buyer views.
    if (pendingTrades.isEmpty && incomingOffers.isEmpty && sentPendingOffers.isEmpty) {
      return const Center(child: Text('No transactions'));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      children: <Widget>[
        if (incomingOffers.isNotEmpty) ...<Widget>[
          _sectionTitle('Incoming Offers'),
          for (final offer in incomingOffers)
            _IncomingOfferCard(
              offer: offer,
              onOpenListing: () => context.push('/listing/${offer.listingId}'),
            ),
        ],
        if (sentPendingOffers.isNotEmpty) ...<Widget>[
          _sectionTitle('Sent Offers'),
          for (final offer in sentPendingOffers)
            _SentOfferCard(
              offer: offer,
              onOpenListing: () => context.push('/listing/${offer.listingId}'),
            ),
        ],
        if (pendingTrades.isNotEmpty) ...<Widget>[
          _sectionTitle('Pending Trades'),
          for (final trade in pendingTrades)
            TransactionCard(trade: trade),
        ],
      ],
    );
  }

  Widget _buildInProgressList(
    BuildContext context,
    List<DisplayTrade> activeTrades,
    List<SentOffer> sentInProgressOffers,
  ) {
    // In-progress includes workflow-managed trades and accepted/scheduled offers.
    if (activeTrades.isEmpty && sentInProgressOffers.isEmpty) {
      return const Center(child: Text('No transactions'));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      children: <Widget>[
        if (sentInProgressOffers.isNotEmpty) ...<Widget>[
          _sectionTitle('Sent Offers'),
          for (final offer in sentInProgressOffers)
            _SentOfferCard(
              offer: offer,
              onOpenListing: () => context.push('/listing/${offer.listingId}'),
            ),
        ],
        if (activeTrades.isNotEmpty) ...<Widget>[
          _sectionTitle('Workflow Trades'),
          for (final trade in activeTrades)
            TransactionCard(trade: trade),
        ],
      ],
    );
  }

  Widget _buildCompletedList(
    BuildContext context,
    List<DisplayTrade> completedTrades,
    List<SentOffer> sentCompletedOffers,
    List<SentOffer> sentRejectedOffers,
  ) {
    // Closed tab intentionally groups successful and unsuccessful final outcomes.
    if (completedTrades.isEmpty &&
        sentCompletedOffers.isEmpty &&
        sentRejectedOffers.isEmpty) {
      return const Center(child: Text('No transactions'));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      children: <Widget>[
        if (sentCompletedOffers.isNotEmpty) ...<Widget>[
          _sectionTitle('Sent Offers - Closed (Completed)'),
          for (final offer in sentCompletedOffers)
            _SentOfferCard(
              offer: offer,
              onOpenListing: () => context.push('/listing/${offer.listingId}'),
            ),
        ],
        if (sentRejectedOffers.isNotEmpty) ...<Widget>[
          _sectionTitle('Sent Offers - Closed (Rejected)'),
          for (final offer in sentRejectedOffers)
            _SentOfferCard(
              offer: offer,
              onOpenListing: () => context.push('/listing/${offer.listingId}'),
            ),
        ],
        if (completedTrades.isNotEmpty) ...<Widget>[
          _sectionTitle('Workflow Trades'),
          for (final trade in completedTrades)
            TransactionCard(trade: trade),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _IncomingOfferCard extends StatefulWidget {
  const _IncomingOfferCard({
    required this.offer,
    required this.onOpenListing,
  });

  final IncomingOffer offer;
  final VoidCallback onOpenListing;

  @override
  State<_IncomingOfferCard> createState() => _IncomingOfferCardState();
}

class _IncomingOfferCardState extends State<_IncomingOfferCard> {
  bool _isRejecting = false;

  Future<void> _rejectOffer() async {
    // Confirm destructive actions so sellers do not reject by accident.
    final bool confirmed = await _confirmReject();
    if (!confirmed || _isRejecting) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isRejecting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offer.id)
          .update(<String, dynamic>{
        'status': 'rejected',
        'rejectionReason': 'Seller declined the offer.',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer rejected.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to reject offer right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRejecting = false;
        });
      }
    }
  }

  Future<bool> _confirmReject() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Offer?'),
        content: const Text(
          'This will notify the buyer that their offer was rejected.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final String typeLabel =
        widget.offer.offerType.isEmpty ? 'cash' : widget.offer.offerType;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.offer.listingTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Buyer: ${widget.offer.buyerName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text('Type: $typeLabel'),
            if (widget.offer.amount != null) ...<Widget>[
              const SizedBox(height: 2),
              Text('Amount: \$${widget.offer.amount}'),
            ],
            if (widget.offer.message.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('Message: ${widget.offer.message.trim()}'),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                OutlinedButton(
                  onPressed: widget.onOpenListing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B0000),
                    side: const BorderSide(color: Color(0xFF8B0000)),
                  ),
                  child: const Text('Open Listing'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _isRejecting ? null : _rejectOffer,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000),
                    foregroundColor: Colors.white,
                  ),
                  child: _isRejecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Reject Offer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SentOfferCard extends StatelessWidget {
  const _SentOfferCard({
    required this.offer,
    required this.onOpenListing,
  });

  final SentOffer offer;
  final VoidCallback onOpenListing;

  @override
  Widget build(BuildContext context) {
    // Buyers always get status context directly on the card.
    final String typeLabel = offer.offerType.isEmpty ? 'cash' : offer.offerType;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    offer.listingTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(status: offer.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Seller: ${offer.sellerId}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text('Type: $typeLabel'),
            if (offer.amount != null) ...<Widget>[
              const SizedBox(height: 2),
              Text('Amount: \$${offer.amount}'),
            ],
            if (offer.message.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('Message: ${offer.message.trim()}'),
            ],
            if (offer.status == 'rejected') ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Result: ${offer.rejectionReason.isEmpty ? 'Seller declined the offer.' : offer.rejectionReason}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onOpenListing,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B0000),
                side: const BorderSide(color: Color(0xFF8B0000)),
              ),
              child: const Text('Open Listing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    // Keep chip color mapping in one place for status consistency.
    late final Color bg;
    late final Color fg;

    switch (status) {
      case 'accepted':
        bg = const Color(0xFFDFF5E2);
        fg = const Color(0xFF1B5E20);
        break;
      case 'completed':
        bg = const Color(0xFFE1F5FE);
        fg = const Color(0xFF01579B);
        break;
      case 'rejected':
        bg = const Color(0xFFFFE0E0);
        fg = const Color(0xFF8B0000);
        break;
      default:
        bg = const Color(0xFFFFF3CD);
        fg = const Color(0xFF6A4B00);
        break;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
      backgroundColor: bg,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
