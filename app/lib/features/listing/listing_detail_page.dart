import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/star_rating.dart';
import '../../models/mock_data.dart';

class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  String _offerType = 'cash';
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

    if (_offerType == 'cash') {
      return _cashAmountController.text.trim().isNotEmpty;
    }

    return _selectedTradeItem.isNotEmpty;
  }

  Future<void> _openOfferDialog() async {
    // all offer inputs live in one dialog so user stays in context.
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  title: const Text('Make an Offer'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Offer Type',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'cash',
                              icon: Icon(Icons.attach_money),
                              label: Text('Cash'),
                            ),
                            ButtonSegment<String>(
                              value: 'trade',
                              icon: Icon(Icons.swap_horiz),
                              label: Text('Trade'),
                            ),
                          ],
                          selected: <String>{_offerType},
                          onSelectionChanged: (Set<String> value) {
                            setDialogState(() {
                              _offerType = value.first;
                            });
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_offerType == 'cash')
                          TextField(
                            controller: _cashAmountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Your Offer (CAD)',
                              prefixText: '\$',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setDialogState(() {});
                              setState(() {});
                            },
                          )
                        else
                          Column(
                            children: <Widget>[
                              DropdownButtonFormField<String>(
                                initialValue: _selectedTradeItem.isEmpty
                                    ? null
                                    : _selectedTradeItem,
                                decoration: const InputDecoration(
                                  labelText: 'Select Your Item to Trade',
                                  border: OutlineInputBorder(),
                                ),
                                items: const <DropdownMenuItem<String>>[
                                  DropdownMenuItem(
                                    value: 'listing-1',
                                    child: Text('Data Structures Textbook'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'listing-3',
                                    child: Text('Organic Chemistry Lab Manual'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'listing-6',
                                    child: Text('Python Programming Textbook'),
                                  ),
                                ],
                                onChanged: (String? value) {
                                  setDialogState(() {
                                    _selectedTradeItem = value ?? '';
                                  });
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _cashTopUpController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Cash Top-up (Optional)',
                                  prefixText: '\$',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        const Text(
                          'Proposed Meetup',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _meetupDateController,
                          readOnly: true,
                          onTap: () async {
                            await _pickDateTime();
                            setDialogState(() {});
                          },
                          decoration: const InputDecoration(
                            labelText: 'Date & Time',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_month),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _meetupLocation.isEmpty
                              ? null
                              : _meetupLocation,
                          decoration: const InputDecoration(
                            labelText: 'Safe Exchange Zone',
                            border: OutlineInputBorder(),
                          ),
                          items: campusSafeZones
                              .map(
                                (SafeZone zone) => DropdownMenuItem<String>(
                                  value: zone.id.toString(),
                                  child: Text(zone.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (String? value) {
                            setDialogState(() {
                              _meetupLocation = value ?? '';
                            });
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: _canSubmitOffer
                          ? () {
                              Navigator.of(context).pop();
                              this.context.go('/trades');
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B0000),
                      ),
                      child: const Text('Submit Offer'),
                    ),
                  ],
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
    _meetupDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // quick lookup from mock data until real backend wiring lands.
    final Listing? listing = mockListings
        .where((Listing item) => item.id == widget.listingId)
        .firstOrNull;

    if (listing == null) {
      return const Scaffold(body: Center(child: Text('Listing not found')));
    }

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
                    children: listing.images
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
                          onPressed: _openOfferDialog,
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
  }
}
