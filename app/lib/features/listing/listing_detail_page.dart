import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/widgets/star_rating.dart';
import '../../models/mock_data.dart';
import '../../models/listing_firestore_mapper.dart';
import 'widgets/offer_dialog.dart';

class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _cashTopUpController = TextEditingController();
  final TextEditingController _meetupDateController = TextEditingController();
  String _selectedTradeItem = '';
  String _meetupLocation = '';

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

  bool get _canSubmitOffer {
    // basic gate: need meetup details first, then offer details.
    if (_meetupDateController.text.trim().isEmpty || _meetupLocation.isEmpty) {
      return false;
    }
    return _selectedTradeItem.isNotEmpty;
  }

  Future<void> _openOfferDialog(Listing listing) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return OfferDialog(
          offerType: listing.isTrade ? 'trade' : 'cash',
          cashAmountController: _cashAmountController,
          cashTopUpController: _cashTopUpController,
          meetupDateController: _meetupDateController,
          selectedTradeItem: _selectedTradeItem,
          meetupLocation: _meetupLocation,
          onTradeItemChanged: (String? value) {
            setState(() {
              _selectedTradeItem = value ?? '';
            });
          },
          onMeetupLocationChanged: (String? value) {
            setState(() {
              _meetupLocation = value ?? '';
            });
          },
          onPickDateTime: _pickDateTime,
          canSubmitOffer: _canSubmitOffer,
          onSubmitOffer: () {
            Navigator.of(context).pop();
            this.context.go('/trades');
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _cashAmountController.dispose();
    _cashTopUpController.dispose();
    _meetupDateController.dispose();
    super.dispose();
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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

        return Scaffold(
          body: Column(
            children: <Widget>[
              Container(
                color: const Color(0xFF8B0000),
                padding: const EdgeInsets.only(
                  top: 12,
                  bottom: 12,
                  left: 8,
                  right: 8,
                ),
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
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
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
                            labelStyle: const TextStyle(
                              color: Color(0xFF8B0000),
                            ),
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
                                      listing.seller.name[0],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          listing.seller.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: <Widget>[
                                            StarRating(
                                              value: listing.seller.rating,
                                            ),
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
                              for (final SafeZone zone in campusSafeZones.take(
                                3,
                              ))
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
                      const SizedBox(height: 18),
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
