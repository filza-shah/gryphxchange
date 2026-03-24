import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/workflow_provider.dart';
import '../../core/widgets/star_rating.dart';
import '../../features/trade/presentation/providers/display_trades_provider.dart';
import '../../models/listing_firestore_mapper.dart';
import '../../models/mock_data.dart';
import '../../services/workflow/workflow_state.dart';
import 'widgets/offer_dialog.dart';

class ListingDetailPage extends ConsumerStatefulWidget {
  const ListingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends ConsumerState<ListingDetailPage> {
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _cashTopUpController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _meetupDateController = TextEditingController();

  String _selectedTradeItem = '';
  String _meetupLocation = '';
  bool _isSubmittingOffer = false;
  String _acceptingOfferId = '';

  Future<void> _pickDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) {
      return;
    }

    _meetupDateController.text =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    setState(() {});
  }

  bool _canSubmitOffer(Listing listing) {
    if (_isSubmittingOffer) {
      return false;
    }

    if (_meetupDateController.text.trim().isEmpty || _meetupLocation.isEmpty) {
      return false;
    }

    if (listing.isTrade) {
      return _selectedTradeItem.isNotEmpty;
    }

    final double? amount = double.tryParse(_cashAmountController.text.trim());
    return amount != null && amount > 0;
  }

  Future<void> _submitOffer(Listing listing) async {
    if (!_canSubmitOffer(listing)) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to make an offer.')),
      );
      return;
    }

    if (currentUser.uid == listing.sellerId) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot make an offer on your own listing.')),
      );
      return;
    }

    setState(() {
      _isSubmittingOffer = true;
    });

    final Map<String, dynamic> offerPayload = <String, dynamic>{
      'buyerId': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'listingId': listing.id,
      'message': _messageController.text.trim(),
      'offerType': listing.isTrade ? 'trade' : 'cash',
      'sellerId': listing.sellerId,
      'status': 'pending',
      'tradeItems': listing.isTrade && _selectedTradeItem.isNotEmpty
          ? <String>[_selectedTradeItem]
          : null,
      'amount': listing.isTrade
          ? null
          : double.tryParse(_cashAmountController.text.trim()),
      'cashTopUp': listing.isTrade
          ? double.tryParse(_cashTopUpController.text.trim())
          : null,
      'meetupDateTime': _meetupDateController.text.trim(),
      'meetupLocation': _meetupLocation,
      'participants': <String>[currentUser.uid, listing.sellerId],
    };

    try {
      await FirebaseFirestore.instance.collection('offers').add(offerPayload);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer sent successfully.')),
      );
      context.go('/trades');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send offer right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingOffer = false;
        });
      }
    }
  }

  Future<void> _acceptOffer({
    required String offerId,
    required Listing listing,
    required Map<String, dynamic> offerData,
  }) async {
    if (_acceptingOfferId.isNotEmpty) {
      return;
    }

    setState(() {
      _acceptingOfferId = offerId;
    });

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      final WriteBatch batch = firestore.batch();

      final DocumentReference<Map<String, dynamic>> offerRef =
          firestore.collection('offers').doc(offerId);
      final DocumentReference<Map<String, dynamic>> listingRef =
          firestore.collection('listings').doc(listing.id);

      batch.update(offerRef, <String, dynamic>{
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      batch.update(listingRef, <String, dynamic>{
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final pendingOffers = await firestore
          .collection('offers')
          .where('listingId', isEqualTo: listing.id)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingOffers.docs) {
        if (doc.id == offerId) {
          continue;
        }
        batch.update(doc.reference, <String, dynamic>{
          'status': 'rejected',
          'respondedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      final String offerType =
          ((offerData['offerType'] as String?) ?? '').toLowerCase();
      final TransactionMode mode =
          offerType == 'trade' ? TransactionMode.trade : TransactionMode.sale;

      ref.read(workflowControllerProvider).addPendingTrade(offerId, mode);
      ref.invalidate(displayTradesProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer accepted. Trade is now pending.')),
      );
      context.go('/trades');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to accept offer right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _acceptingOfferId = '';
        });
      }
    }
  }

  Future<void> _openOfferDialog(Listing listing) async {
    _cashAmountController.clear();
    _cashTopUpController.clear();
    _messageController.clear();
    _meetupDateController.clear();
    _selectedTradeItem = '';
    _meetupLocation = '';

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return OfferDialog(
              offerType: listing.isTrade ? 'trade' : 'cash',
              cashAmountController: _cashAmountController,
              cashTopUpController: _cashTopUpController,
              messageController: _messageController,
              meetupDateController: _meetupDateController,
              selectedTradeItem: _selectedTradeItem,
              meetupLocation: _meetupLocation,
              onTradeItemChanged: (String? value) {
                setDialogState(() {
                  _selectedTradeItem = value ?? '';
                });
                setState(() {});
              },
              onMeetupLocationChanged: (String? value) {
                setDialogState(() {
                  _meetupLocation = value ?? '';
                });
                setState(() {});
              },
              onPickDateTime: () async {
                await _pickDateTime();
                setDialogState(() {});
              },
              canSubmitOffer: () => _canSubmitOffer(listing),
              onSubmitOffer: () {
                _submitOffer(listing);
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _cashAmountController.dispose();
    _cashTopUpController.dispose();
    _messageController.dispose();
    _meetupDateController.dispose();
    super.dispose();
  }

  Widget _buildSellerOfferSection(Listing listing) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('listingId', isEqualTo: listing.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Unable to load offers right now.'),
            ),
          );
        }

        final offers = snapshot.data?.docs ?? const [];
        if (offers.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No offers yet for this listing.'),
            ),
          );
        }

        offers.sort((a, b) {
          final dynamic aCreated = a.data()['createdAt'];
          final dynamic bCreated = b.data()['createdAt'];
          final DateTime aDate = aCreated is Timestamp ? aCreated.toDate() : DateTime(1970);
          final DateTime bDate = bCreated is Timestamp ? bCreated.toDate() : DateTime(1970);
          return bDate.compareTo(aDate);
        });

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Incoming Offers',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                for (final doc in offers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildOfferCard(listing, doc),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfferCard(
    Listing listing,
    QueryDocumentSnapshot<Map<String, dynamic>> offerDoc,
  ) {
    final Map<String, dynamic> offer = offerDoc.data();
    final String status = ((offer['status'] as String?) ?? 'pending').toLowerCase();
    final String offerType = ((offer['offerType'] as String?) ?? '').toLowerCase();
    final String buyerId = (offer['buyerId'] as String?) ?? 'unknown';
    final String message = (offer['message'] as String?) ?? '';
    final List<String> tradeItems =
        ((offer['tradeItems'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<String>()
            .toList();

    final bool canAccept = status == 'pending';
    final bool isAcceptingThis = _acceptingOfferId == offerDoc.id;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Buyer: $buyerId',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Chip(
                label: Text(status.toUpperCase()),
                backgroundColor: status == 'accepted'
                    ? const Color(0xFFDFF5E2)
                    : status == 'rejected'
                        ? const Color(0xFFFFE0E0)
                        : const Color(0xFFFFF3CD),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Type: ${offerType.isEmpty ? 'cash' : offerType}'),
          if (offer['amount'] != null) ...<Widget>[
            const SizedBox(height: 2),
            Text('Amount: \$${offer['amount']}'),
          ],
          if (tradeItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text('Trade Items: ${tradeItems.join(', ')}'),
          ],
          if (message.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text('Message: $message'),
          ],
          const SizedBox(height: 8),
          if (canAccept)
            FilledButton(
              onPressed: isAcceptingThis
                  ? null
                  : () => _acceptOffer(
                        offerId: offerDoc.id,
                        listing: listing,
                        offerData: offer,
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
              ),
              child: isAcceptingThis
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Accept Offer'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listingId)
          .snapshots(),
      builder: (BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to load listing right now.')),
          );
        }

        final DocumentSnapshot<Map<String, dynamic>>? document = snapshot.data;
        if (document == null || !document.exists) {
          return const Scaffold(body: Center(child: Text('Listing not found')));
        }

        final Listing listing = listingFromFirestoreMap(
          id: document.id,
          data: document.data() ?? <String, dynamic>{},
        );

        final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final bool isOwner = currentUserId.isNotEmpty && currentUserId == listing.sellerId;

        return Scaffold(
          body: Column(
            children: <Widget>[
              Container(
                color: const Color(0xFF8B0000),
                padding: const EdgeInsets.only(top: 12, bottom: 12, left: 8, right: 8),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Text(
                        'Listing Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    SizedBox(
                      height: 300,
                      child: PageView(
                        children: (listing.images.isNotEmpty
                                ? listing.images
                                : <String>[
                                    'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400'
                                  ])
                            .map(
                              (String image) => Image.network(
                                image,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  listing.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 28,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              listing.isTrade
                                  ? const Chip(
                                      label: Text('Trade'),
                                      backgroundColor: Color(0xFFFFD700),
                                      labelStyle: TextStyle(fontWeight: FontWeight.w700),
                                    )
                                  : Text(
                                      '\$${listing.price?.toStringAsFixed(0) ?? ''}',
                                      style: const TextStyle(
                                        color: Color(0xFF8B0000),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 34,
                                      ),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: <Widget>[
                              Chip(
                                label: Text(listing.courseCode),
                                backgroundColor: const Color(0x1A8B0000),
                                labelStyle: const TextStyle(color: Color(0xFF8B0000)),
                              ),
                              Chip(label: Text(listing.semester)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            listing.description,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Seller Information',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: const Color(0xFF8B0000),
                                        child: Text(
                                          listing.seller.name.isEmpty
                                              ? '?'
                                              : listing.seller.name[0],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              listing.seller.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: <Widget>[
                                                StarRating(value: listing.seller.rating),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${listing.seller.rating} (${listing.seller.totalRatings} reviews)',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Safe Exchange Zones on Campus',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 10),
                                  for (final SafeZone zone in campusSafeZones.take(3))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: <Widget>[
                                          const Icon(
                                            Icons.place,
                                            size: 18,
                                            color: Color(0xFF8B0000),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(zone.name)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isOwner) _buildSellerOfferSection(listing),
                          const SizedBox(height: 18),
                          if (!isOwner)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  _openOfferDialog(listing);
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B0000),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Make Offer'),
                              ),
                            ),
                        ],
                      ),
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
