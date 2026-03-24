import 'package:flutter/material.dart';
import '../../../models/mock_data.dart';

class OfferDialog extends StatefulWidget {
  const OfferDialog({
    super.key,
    required this.offerType,
    required this.cashAmountController,
    required this.cashTopUpController,
    required this.messageController,
    required this.meetupDateController,
    required this.selectedTradeItem,
    required this.meetupLocation,
    required this.onTradeItemChanged,
    required this.onMeetupLocationChanged,
    required this.onPickDateTime,
    required this.canSubmitOffer,
    required this.onSubmitOffer,
  });

  final String offerType;
  final TextEditingController cashAmountController;
  final TextEditingController cashTopUpController;
  final TextEditingController messageController;
  final TextEditingController meetupDateController;
  final String selectedTradeItem;
  final String meetupLocation;
  final ValueChanged<String?> onTradeItemChanged;
  final ValueChanged<String?> onMeetupLocationChanged;
  final Future<void> Function() onPickDateTime;
  final bool Function() canSubmitOffer;
  final VoidCallback onSubmitOffer;

  @override
  State<OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<OfferDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Make an Offer'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Offer Type',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.maxFinite,
              child: Row(
                children: <Widget>[
                  Icon(
                    widget.offerType == 'cash' ? Icons.attach_money : Icons.swap_horiz,
                    color: const Color(0xFF8B0000),
                  ),
                  const SizedBox(width: 8),
                  Expanded( // Wrapped the Text in Expanded to prevent overflow
                    child: Text(
                      widget.offerType == 'cash' ? 'Cash' : 'Trade',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),  
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.offerType == 'cash')
              TextField(
                controller: widget.cashAmountController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Your Offer (CAD)',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
              )
            else
              Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: widget.selectedTradeItem.isEmpty
                        ? null
                        : widget.selectedTradeItem,
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
                    onChanged: widget.onTradeItemChanged,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: widget.cashTopUpController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Cash Top-up (Optional)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.messageController,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Message to Seller (optional)',
                hintText: 'Add details about your offer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Proposed Meetup',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.meetupDateController,
              readOnly: true,
              onTap: () async {
                await widget.onPickDateTime();
                if (mounted) {
                  setState(() {});
                }
              },
              decoration: const InputDecoration(
                labelText: 'Date & Time',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_month),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: widget.meetupLocation.isEmpty
                  ? null
                  : widget.meetupLocation,
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
                widget.onMeetupLocationChanged(value);
                setState(() {});
              },
            ),
          ],
        ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: widget.canSubmitOffer() ? widget.onSubmitOffer : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B0000),
          ),
          child: const Text('Submit Offer'),
        ),
      ],
    );
  }
}