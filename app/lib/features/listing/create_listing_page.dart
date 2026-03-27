import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/widgets/app_bottom_nav.dart';

class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key});

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  static final FilteringTextInputFormatter _priceInputFormatter =
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'));

  // form controllers: all core listing inputs live here for now.
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _tradeForController = TextEditingController();
  final TextEditingController _courseCodeController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _editionController = TextEditingController();
  final TextEditingController _isbnController = TextEditingController(
    text: '9780131103627',
  );

  String _offerType = 'cash';
  String? _semester;
  final List<String> _images = <String>[];
  // scan status text + counters (just UI feedback stuff).
  bool _scanLoading = false;
  bool _isSubmitting = false;
  String _scanError = '';
  String _submitError = '';
  int _bookMatchesFound = 0;

  // quick local ISBN lookup so this flow works even if net is down.
  static const Map<String, _IsbnBook> _isbnSeed = <String, _IsbnBook>{
    '9780131103627': _IsbnBook(
      title: 'The C Programming Language',
      author: 'Brian W. Kernighan, Dennis M. Ritchie',
      edition: '2nd Edition',
      description:
          'Classic systems programming textbook. Great for low-level foundations.',
      cover: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=400',
    ),
    '9780132350884': _IsbnBook(
      title: 'Clean Code',
      author: 'Robert C. Martin',
      edition: '1st Edition',
      description:
          'Focuses on writing readable and maintainable code in real projects.',
      cover:
          'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=400',
    ),
    '9781491946008': _IsbnBook(
      title: 'Fluent Python',
      author: 'Luciano Ramalho',
      edition: '2nd Edition',
      description:
          'Deep dive into Python features with practical examples for dev work.',
      cover:
          'https://images.unsplash.com/photo-1532012197267-da84d127e765?w=400',
    ),
  };

  void _handleImageUpload() {
    // fake upload for now; keeps UX moving while backend upload is pending.
    const List<String> mockImages = <String>[
      'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400',
      'https://images.unsplash.com/photo-1532012197267-da84d127e765?w=400',
    ];

    setState(() {
      _images.add(mockImages[_images.length % mockImages.length]);
    });
  }

  Future<void> _handleScanBarcode() async {
    // normalize quickly so users can paste ISBN with dashes.
    final String isbn = _isbnController.text.trim().replaceAll('-', '');
    if (isbn.isEmpty) {
      setState(() {
        _scanError = 'Enter an ISBN before scanning.';
      });
      return;
    }

    setState(() {
      _scanLoading = true;
      _scanError = '';
      _bookMatchesFound = 0;
    });

    // small delay so scan action feels real in UI.
    await Future<void>.delayed(const Duration(milliseconds: 550));

    final _IsbnBook? book = _isbnSeed[isbn];
    if (book == null) {
      setState(() {
        _scanLoading = false;
        _scanError =
            'No match found in local ISBN seed. You can still fill fields manually.';
        _bookMatchesFound = 0;
      });
      return;
    }

    setState(() {
      _scanLoading = false;
      _bookMatchesFound = 1;
      _titleController.text = book.title;
      _authorController.text = book.author;
      _editionController.text = book.edition;
      _descriptionController.text = book.description;
      if (_images.isEmpty) {
        _images.add(book.cover);
      }
    });
  }

  bool get _isSubmitDisabled {
    // simple guardrails so we don't submit half-empty mock listings.
    final bool baseInvalid =
        _titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _courseCodeController.text.trim().isEmpty ||
        (_semester ?? '').isEmpty;

    if (baseInvalid || _isSubmitting) {
      return true;
    }

    if (_offerType == 'cash') {
      final double? parsedPrice = double.tryParse(_priceController.text.trim());
      return parsedPrice == null || parsedPrice <= 0;
    }

    return _tradeForController.text.trim().isEmpty;
  }

  List<String> get _missingRequiredFields {
    final List<String> missing = <String>[];

    if (_titleController.text.trim().isEmpty) {
      missing.add('Title');
    }
    if (_descriptionController.text.trim().isEmpty) {
      missing.add('Description');
    }
    if (_courseCodeController.text.trim().isEmpty) {
      missing.add('Course Code');
    }
    if ((_semester ?? '').isEmpty) {
      missing.add('Semester');
    }

    if (_offerType == 'cash') {
      final double? parsedPrice = double.tryParse(_priceController.text.trim());
      if (parsedPrice == null || parsedPrice <= 0) {
        missing.add('Valid Price');
      }
    } else if (_tradeForController.text.trim().isEmpty) {
      missing.add('Trade Preference');
    }

    return missing;
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitDisabled) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _submitError = 'You must be signed in to create a listing.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = '';
    });

    final String email = user.email ?? 'unknown@uoguelph.ca';
    final String fallbackName = email.split('@').first;
    final String sellerName = (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : fallbackName;

    final bool isTrade = _offerType == 'trade';
    final double? parsedPrice = double.tryParse(_priceController.text.trim());

    final Map<String, dynamic> listingPayload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'courseCode': _courseCodeController.text.trim().toUpperCase(),
      'semester': _semester,
      'category': 'Textbooks',
      'isTrade': isTrade,
      'price': isTrade ? null : parsedPrice,
      'tradeFor': isTrade ? _tradeForController.text.trim() : null,
      'images': List<String>.from(_images),
      'status': 'active',
      'author': _authorController.text.trim(),
      'edition': _editionController.text.trim(),
      'isbn': _isbnController.text.trim().replaceAll('-', ''),
      'sellerId': user.uid,
      'userId': user.uid,
      'seller': <String, dynamic>{
        'id': user.uid,
        'name': sellerName,
        'email': email,
        'avatar': user.photoURL,
        'rating': 0,
        'totalRatings': 0,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      // Keep a lightweight user profile doc in sync so listing/detail screens
      // can render seller info without extra joins.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': sellerName,
        'email': email,
        'avatar': user.photoURL,
        'rating': 0,
        'totalRatings': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Listing is created after profile upsert so the nested seller snapshot
      // and user document do not drift on first post.
      await FirebaseFirestore.instance.collection('listings').add(listingPayload);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing created successfully.')),
      );
      context.go('/home');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = 'Unable to create listing right now. Please try again.';
        _isSubmitting = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _tradeForController.dispose();
    _courseCodeController.dispose();
    _authorController.dispose();
    _editionController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentRoute: '/create'),
      body: Column(
        children: <Widget>[
          // same top bar vibe as the rest of GryphXChange.
          Container(
            color: const Color(0xFF8B0000),
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Create Listing',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // first card = ISBN helper so user can auto-fill quickly.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        const Icon(
                          Icons.qr_code_scanner,
                          size: 52,
                          color: Color(0xFF8B0000),
                        ),
                        const SizedBox(height: 8),
                        const Text('Intelligent Listing (ISBN Scan)'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _isbnController,
                          decoration: const InputDecoration(
                            labelText: 'ISBN Barcode Value',
                            hintText: 'e.g., 9780131103627',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _scanLoading ? null : _handleScanBarcode,
                            icon: _scanLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.qr_code_scanner),
                            label: Text(
                              _scanLoading
                                  ? 'Scanning ISBN...'
                                  : 'Scan Barcode & Auto-fill',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Matches found: $_bookMatchesFound',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                        if (_scanError.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              border: Border.all(
                                color: const Color(0xFFFFECB3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _scanError,
                              style: const TextStyle(color: Color(0xFF6D4C41)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // photo lane is mock-only but keeps create flow realistic.
                const Text(
                  'Photos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      for (int index = 0; index < _images.length; index++)
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _images[index],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _images.removeAt(index);
                                    });
                                  },
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Color(0xAA000000),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      OutlinedButton(
                        onPressed: _handleImageUpload,
                        child: const SizedBox(
                          width: 80,
                          height: 80,
                          child: Icon(Icons.camera_alt_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // main listing form fields start here.
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '* Required fields',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g., Data Structures Textbook',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Author',
                    hintText: 'Auto-filled from ISBN scan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _editionController,
                  decoration: const InputDecoration(
                    labelText: 'Edition',
                    hintText: 'Auto-filled from ISBN scan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  onChanged: (_) => setState(() {}),
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'Describe the condition and details',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _courseCodeController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Course Code *',
                    hintText: 'e.g., CIS*2520',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _semester,
                  decoration: const InputDecoration(
                    labelText: 'Semester *',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'Winter 2026',
                      child: Text('Winter 2026'),
                    ),
                    DropdownMenuItem(
                      value: 'Fall 2025',
                      child: Text('Fall 2025'),
                    ),
                    DropdownMenuItem(
                      value: 'Summer 2025',
                      child: Text('Summer 2025'),
                    ),
                    DropdownMenuItem(
                      value: 'Winter 2025',
                      child: Text('Winter 2025'),
                    ),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _semester = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // cash vs trade toggle copied from your prototype behavior.
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
                    setState(() {
                      _offerType = value.first;
                    });
                  },
                ),
                if (_offerType == 'cash') ...<Widget>[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[_priceInputFormatter],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Price (CAD) *',
                      prefixText: '\$',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_offerType == 'trade') ...<Widget>[
                  const SizedBox(height: 12),
                  const Chip(
                    label: Text('Open to trade offers'),
                    backgroundColor: Color(0x33FFD700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tradeForController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'What do you want in return? *',
                      hintText: 'e.g., Physics textbook, CIS notes...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.swap_horiz),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (_missingRequiredFields.isNotEmpty) ...<Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      border: Border.all(color: const Color(0xFFFFECB3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Please complete: ${_missingRequiredFields.join(', ')}',
                      style: const TextStyle(color: Color(0xFF6D4C41)),
                    ),
                  ),
                ],
                if (_submitError.isNotEmpty) ...<Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _submitError,
                      style: const TextStyle(color: Color(0xFFB71C1C)),
                    ),
                  ),
                ],
                FilledButton(
                  onPressed: _isSubmitDisabled ? null : _handleSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Listing'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IsbnBook {
  const _IsbnBook({
    required this.title,
    required this.author,
    required this.edition,
    required this.description,
    required this.cover,
  });

  final String title;
  final String author;
  final String edition;
  final String description;
  final String cover;
}