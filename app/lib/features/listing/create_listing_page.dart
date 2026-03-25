import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/widgets/app_bottom_nav.dart';

class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key});

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  static const String _googleBooksApiKey = '';
  static const int _maxImages = 6;

  static final FilteringTextInputFormatter _priceInputFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'));
  static final FilteringTextInputFormatter _isbnInputFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx-]'));

  final ImagePicker _imagePicker = ImagePicker();
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
  final List<_ListingImage> _images = <_ListingImage>[];
  bool _scanLoading = false;
  bool _imageLoading = false;
  bool _isSubmitting = false;
  String _scanError = '';
  String _imageError = '';
  String _submitError = '';
  int _bookMatchesFound = 0;

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

  int get _remainingImageSlots => _maxImages - _images.length;

  String _normalizeIsbn(String value) {
    return value.trim().replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
  }

  bool _isValidIsbn(String isbn) {
    return isbn.length == 10 || isbn.length == 13;
  }

  void _applyBookCover(String coverUrl) {
    if (coverUrl.trim().isEmpty) {
      return;
    }

    final int existingCoverIndex = _images.indexWhere(
      (_ListingImage image) => image.isBookCover,
    );
    final _ListingImage image = _ListingImage.remoteBookCover(coverUrl);

    if (existingCoverIndex >= 0) {
      _images[existingCoverIndex] = image;
      return;
    }

    if (_images.length < _maxImages) {
      _images.insert(0, image);
    }
  }

  Future<void> _lookupIsbn(String rawInput) async {
    final String isbn = _normalizeIsbn(rawInput);
    if (isbn.isEmpty) {
      setState(() {
        _scanError = 'Enter an ISBN first.';
      });
      return;
    }

    if (!_isValidIsbn(isbn)) {
      setState(() {
        _scanError = 'Enter a valid 10 or 13 digit ISBN.';
        _bookMatchesFound = 0;
      });
      return;
    }

    setState(() {
      _scanLoading = true;
      _scanError = '';
      _bookMatchesFound = 0;
      _isbnController.text = isbn;
    });

    final _BookLookupResult lookupResult = await _fetchBookFromGoogleBooks(
      isbn,
    );
    final _IsbnBook? apiBook = lookupResult.book;
    final _IsbnBook? book = apiBook ?? _isbnSeed[isbn];

    if (!mounted) {
      return;
    }

    if (book == null) {
      setState(() {
        _scanLoading = false;
        _scanError =
            lookupResult.error ?? 'Could not find book details for that ISBN.';
        _bookMatchesFound = 0;
      });
      return;
    }

    setState(() {
      _scanLoading = false;
      _bookMatchesFound = 1;
      _scanError = '';
      _titleController.text = book.title;
      _authorController.text = book.author;
      _editionController.text = book.edition;
      _descriptionController.text = book.description;
      _applyBookCover(book.cover);
      if (apiBook == null && lookupResult.error != null) {
        _scanError =
            'API lookup failed: ${lookupResult.error}\nUsing local fallback data.';
      }
    });
  }

  Future<void> _handleScanBarcode() async {
    await _lookupIsbn(_isbnController.text);
  }

  Future<void> _openIsbnScanner() async {
    final String? scannedIsbn = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return const FractionallySizedBox(
          heightFactor: 0.88,
          child: _IsbnScannerSheet(),
        );
      },
    );

    if (scannedIsbn == null || scannedIsbn.isEmpty || !mounted) {
      return;
    }

    await _lookupIsbn(scannedIsbn);
  }

  Future<_BookLookupResult> _fetchBookFromGoogleBooks(String isbn) async {
    final String encodedIsbn = Uri.encodeQueryComponent('isbn:$isbn');
    String url =
        'https://www.googleapis.com/books/v1/volumes?q=$encodedIsbn&maxResults=1&printType=books';

    if (_googleBooksApiKey.trim().isNotEmpty) {
      url += '&key=${Uri.encodeQueryComponent(_googleBooksApiKey.trim())}';
    }

    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return _BookLookupResult(
          error:
              'HTTP ${response.statusCode}: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}',
        );
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const _BookLookupResult(
          error: 'Unexpected API response shape: root is not a JSON object.',
        );
      }

      final List<dynamic> items =
          (decoded['items'] as List<dynamic>?) ?? const <dynamic>[];
      if (items.isEmpty) {
        return const _BookLookupResult(
          error: 'Google Books returned no items for this ISBN.',
        );
      }

      final Map<String, dynamic> firstItem =
          (items.first as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final Map<String, dynamic> volumeInfo =
          (firstItem['volumeInfo'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      final String title =
          (volumeInfo['title'] as String?)?.trim().isNotEmpty == true
          ? (volumeInfo['title'] as String).trim()
          : 'Unknown Title';

      final List<String> authors =
          ((volumeInfo['authors'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<String>()
              .where((String name) => name.trim().isNotEmpty)
              .toList(growable: false);

      final String author = authors.isEmpty
          ? 'Unknown Author'
          : authors.join(', ');
      final String description =
          (volumeInfo['description'] as String?)?.trim() ??
          'No description available.';
      final String publishedDate =
          (volumeInfo['publishedDate'] as String?)?.trim() ?? '';

      final Map<String, dynamic> imageLinks =
          (volumeInfo['imageLinks'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final String rawCover =
          (imageLinks['thumbnail'] as String?) ??
          (imageLinks['smallThumbnail'] as String?) ??
          'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400';
      final String cover = rawCover.replaceFirst('http://', 'https://');

      return _BookLookupResult(
        book: _IsbnBook(
          title: title,
          author: author,
          edition: publishedDate.isEmpty ? 'N/A' : publishedDate,
          description: description,
          cover: cover,
        ),
      );
    } on FormatException catch (error) {
      return _BookLookupResult(error: 'Failed to parse API response: $error');
    } catch (error) {
      return _BookLookupResult(error: 'Request failed: $error');
    }
  }

  Future<void> _pickPhotoFromCamera() async {
    if (_remainingImageSlots <= 0) {
      setState(() {
        _imageError = 'You can add up to $_maxImages photos per listing.';
      });
      return;
    }

    setState(() {
      _imageLoading = true;
      _imageError = '';
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2000,
      );

      if (image != null && mounted) {
        setState(() {
          _images.add(_ListingImage.local(image.path));
        });
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageError = _describeImagePickerError(
          error,
          permissionLabel: 'Camera',
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageError = 'Unable to open the camera right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _imageLoading = false;
        });
      }
    }
  }

  Future<void> _pickPhotosFromGallery() async {
    if (_remainingImageSlots <= 0) {
      setState(() {
        _imageError = 'You can add up to $_maxImages photos per listing.';
      });
      return;
    }

    setState(() {
      _imageLoading = true;
      _imageError = '';
    });

    try {
      final List<XFile> pickedImages = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2000,
      );

      if (!mounted || pickedImages.isEmpty) {
        return;
      }

      final int allowedCount = pickedImages.length > _remainingImageSlots
          ? _remainingImageSlots
          : pickedImages.length;

      setState(() {
        _images.addAll(
          pickedImages
              .take(allowedCount)
              .map((_picked) => _ListingImage.local(_picked.path)),
        );
        if (pickedImages.length > allowedCount) {
          _imageError =
              'Only the first $allowedCount image(s) were added. Listings support up to $_maxImages photos.';
        }
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageError = _describeImagePickerError(
          error,
          permissionLabel: 'Photo library',
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageError =
            'Unable to open the photo library right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _imageLoading = false;
        });
      }
    }
  }

  String _describeImagePickerError(
    PlatformException error, {
    required String permissionLabel,
  }) {
    final String message = '${error.code} ${error.message ?? ''}'
        .trim()
        .toLowerCase();
    if (message.contains('permission') ||
        message.contains('access_denied') ||
        message.contains('denied')) {
      return '$permissionLabel permission is required for this action. Allow access and try again.';
    }
    return 'Unable to access $permissionLabel right now. Please try again.';
  }

  Future<List<String>> _resolveListingImageUrls({
    required String userId,
    required String listingId,
  }) async {
    if (_images.isEmpty) {
      return const <String>[];
    }

    final int uploadBatchId = DateTime.now().millisecondsSinceEpoch;
    final List<String> imageUrls = <String>[];

    for (int index = 0; index < _images.length; index++) {
      final _ListingImage image = _images[index];
      if (!image.isLocal) {
        imageUrls.add(image.value);
        continue;
      }

      final Reference reference = FirebaseStorage.instance.ref().child(
        'listings/$userId/$listingId/${uploadBatchId}_$index.jpg',
      );

      await reference.putFile(
        File(image.value),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      imageUrls.add(await reference.getDownloadURL());
    }

    return imageUrls;
  }

  bool get _isSubmitDisabled {
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
    final String sellerName =
        (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : fallbackName;

    final bool isTrade = _offerType == 'trade';
    final double? parsedPrice = double.tryParse(_priceController.text.trim());
    final DocumentReference<Map<String, dynamic>> listingReference =
        FirebaseFirestore.instance.collection('listings').doc();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': sellerName,
        'email': email,
        'avatar': user.photoURL,
        'rating': 0,
        'totalRatings': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final List<String> imageUrls = await _resolveListingImageUrls(
        userId: user.uid,
        listingId: listingReference.id,
      );

      final Map<String, dynamic> listingPayload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'courseCode': _courseCodeController.text.trim().toUpperCase(),
        'semester': _semester,
        'category': 'Textbooks',
        'isTrade': isTrade,
        'price': isTrade ? null : parsedPrice,
        'tradeFor': isTrade ? _tradeForController.text.trim() : null,
        'images': imageUrls,
        'status': 'active',
        'author': _authorController.text.trim(),
        'edition': _editionController.text.trim(),
        'isbn': _normalizeIsbn(_isbnController.text),
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

      await listingReference.set(listingPayload);

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
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.search,
                          inputFormatters: <TextInputFormatter>[
                            _isbnInputFormatter,
                          ],
                          onChanged: (_) {
                            if (_scanError.isNotEmpty) {
                              setState(() {
                                _scanError = '';
                              });
                            }
                          },
                          onSubmitted: (_) => _handleScanBarcode(),
                          decoration: const InputDecoration(
                            labelText: 'ISBN Barcode Value',
                            hintText: 'e.g., 9780131103627',
                            helperText:
                                'Type an ISBN or scan the barcode to auto-fill.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _scanLoading
                                    ? null
                                    : _handleScanBarcode,
                                icon: _scanLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.search),
                                label: Text(
                                  _scanLoading
                                      ? 'Looking up ISBN...'
                                      : 'Lookup ISBN',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _scanLoading
                                    ? null
                                    : _openIsbnScanner,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B0000),
                                ),
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('Scan Barcode'),
                              ),
                            ),
                          ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Photos',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_images.length}/$_maxImages',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Use your camera or gallery.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _imageLoading ? null : _pickPhotoFromCamera,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Take Photo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _imageLoading
                            ? null
                            : _pickPhotosFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Upload Photos'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                                child: _ListingImagePreview(
                                  image: _images[index],
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
                              if (_images[index].isBookCover)
                                Positioned(
                                  left: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xCC8B0000),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Book cover',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_imageLoading)
                        Container(
                          width: 100,
                          height: 100,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_imageError.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      border: Border.all(color: const Color(0xFFFFECB3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _imageError,
                      style: const TextStyle(color: Color(0xFF6D4C41)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
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

class _ListingImagePreview extends StatelessWidget {
  const _ListingImagePreview({required this.image});

  final _ListingImage image;

  @override
  Widget build(BuildContext context) {
    if (image.isLocal) {
      return Image.file(
        File(image.value),
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 100,
            height: 100,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          );
        },
      );
    }

    return Image.network(
      image.value,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          width: 100,
          height: 100,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}

class _IsbnScannerSheet extends StatefulWidget {
  const _IsbnScannerSheet();

  @override
  State<_IsbnScannerSheet> createState() => _IsbnScannerSheetState();
}

class _IsbnScannerSheetState extends State<_IsbnScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  bool _isProcessing = false;
  String _statusMessage =
      'Point the camera at the barcode on the back of the book.';

  String _normalizeBarcode(String rawValue) {
    return rawValue.trim().replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
  }

  Future<void> _handleBarcodeCapture(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) {
      return;
    }

    final String? rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    final String isbn = _normalizeBarcode(rawValue);
    if (isbn.length != 10 && isbn.length != 13) {
      setState(() {
        _statusMessage =
            'That barcode does not look like an ISBN. Try the printed ISBN barcode on the book.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'ISBN detected. Finishing scan...';
    });

    await _scannerController.stop();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(isbn);
  }

  void _handleScannerError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }

    final String message = switch (error) {
      MobileScannerException exception
          when exception.errorCode == MobileScannerErrorCode.permissionDenied =>
        'Camera permission is required to scan ISBN barcodes. Allow camera access and try again.',
      _ => 'Unable to access the camera right now. Please try again.',
    };

    setState(() {
      _statusMessage = message;
    });
  }

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final bool permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            permissionDenied
                ? 'Camera permission is required to scan ISBN barcodes. Allow camera access in the prompt or device settings and try again.'
                : 'Unable to start the camera preview. Please try again.',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
              const Expanded(
                child: Text(
                  'Scan ISBN Barcode',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _handleBarcodeCapture,
                onDetectError: _handleScannerError,
                errorBuilder: _buildScannerError,
                tapToFocus: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.keyboard),
            label: const Text('Enter ISBN Manually'),
          ),
        ],
      ),
    );
  }
}

class _ListingImage {
  const _ListingImage._({
    required this.value,
    required this.isLocal,
    required this.isBookCover,
  });

  const _ListingImage.local(String path)
    : this._(value: path, isLocal: true, isBookCover: false);

  const _ListingImage.remoteBookCover(String url)
    : this._(value: url, isLocal: false, isBookCover: true);

  final String value;
  final bool isLocal;
  final bool isBookCover;
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

class _BookLookupResult {
  const _BookLookupResult({this.book, this.error});

  final _IsbnBook? book;
  final String? error;
}
