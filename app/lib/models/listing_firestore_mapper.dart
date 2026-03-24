import 'package:cloud_firestore/cloud_firestore.dart';
import 'mock_data.dart';

// Converts Firestore document data into a Listing object, handling potential missing fields and type mismatches gracefully
Listing listingFromFirestoreMap({
  required String id,
  required Map<String, dynamic> data,
}) {
  final dynamic sellerData = data['seller'];
  final Map<String, dynamic> sellerMap =
      sellerData is Map<String, dynamic> ? sellerData : <String, dynamic>{};

  final dynamic createdAtData = data['createdAt'];
  final DateTime createdAt = createdAtData is Timestamp
      ? createdAtData.toDate()
      : DateTime.now();

  final bool isTrade = (data['isTrade'] as bool?) ??
      ((data['offerType'] as String?)?.toLowerCase() == 'trade');

  final dynamic priceData = data['price'];
  final double? price = priceData is num
      ? priceData.toDouble()
      : double.tryParse(priceData?.toString() ?? '');

  return Listing(
    id: id,
    title: (data['title'] as String?) ?? 'Untitled Listing',
    description: (data['description'] as String?) ?? '',
    price: price,
    isTrade: isTrade,
    tradeFor:
        (data['tradeFor'] as String?) ?? (data['tradeForDescription'] as String?),
    courseCode: (data['courseCode'] as String?) ?? 'N/A',
    semester: (data['semester'] as String?) ?? 'N/A',
    images: ((data['images'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<String>()
        .toList(),
    sellerId: (data['sellerId'] as String?) ?? (data['userId'] as String?) ?? 'unknown',
    seller: AppUser(
      id: (sellerMap['id'] as String?) ??
          (data['sellerId'] as String?) ??
          (data['userId'] as String?) ??
          'unknown',
      name: (sellerMap['name'] as String?) ?? 'Unknown Seller',
      email: (sellerMap['email'] as String?) ?? 'unknown@uoguelph.ca',
      avatar: sellerMap['avatar'] as String?,
      rating: (sellerMap['rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (sellerMap['totalRatings'] as num?)?.toInt() ?? 0,
    ),
    createdAt: createdAt,
    category: (data['category'] as String?) ?? 'General',
  );
}
