import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== USER MANAGEMENT ====================
  
  /// Get the currently logged-in user
  User? get currentUser => _auth.currentUser;

  /// Get reference to current user's wishlist collection in Firestore
  /// Throws exception if user is not logged in
  CollectionReference get _wishlistCollection {
    if (currentUser == null) {
      throw Exception('User not logged in. Please log in first.');
    }
    return _firestore
        .collection('users')           // Root collection: users
        .doc(currentUser!.uid)         // User document
        .collection('wishlist');       // Subcollection: wishlist
  }

  // ==================== CREATE OPERATIONS ====================

  /// Add a new item to user's wishlist
  /// Parameters:
  ///   - title: Required - the item name (e.g., "Data Structures Textbook")
  ///   - description: Optional - detailed description
  ///   - category: Optional - Textbooks, Electronics, Furniture, Clothing, Other
  ///   - maxPrice: Optional - maximum price user is willing to pay
  ///   - isUrgent: Optional - mark as high priority (red highlight)
  ///   - tags: Optional - keywords for better matching
  Future<void> addWishlistItem({
    required String title,
    String description = '',
    String category = 'Other',
    double? maxPrice,
    bool isUrgent = false,
    List<String> tags = const [],
  }) async {
    await _wishlistCollection.add({
      'title': title,
      'description': description,
      'category': category,
      'maxPrice': maxPrice,
      'isUrgent': isUrgent,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),     // Auto-set by Firebase
      'updatedAt': FieldValue.serverTimestamp(),     // Auto-set by Firebase
      'isFulfilled': false,                          // Track if item was purchased
    });
  }

  // ==================== READ OPERATIONS ====================

  /// Get user's wishlist with real-time updates
  /// Returns a Stream that automatically updates when data changes
  /// Items are sorted by creation date (newest first)
  /// 
  /// NOTE: Removed .where('isFulfilled', isEqualTo: false) to avoid needing 
  /// a composite index. If you want filtering, create the index in Firebase Console:
  /// Collection: wishlist, Fields: isFulfilled (Ascending), createdAt (Descending)
  Stream<QuerySnapshot> getUserWishlist() {
    return _wishlistCollection
        .orderBy('createdAt', descending: true)  // Show newest items first
        .snapshots();                            // Real-time updates
  }

  /// Get a single wishlist item by its document ID
  Future<DocumentSnapshot> getWishlistItem(String docId) async {
    return await _wishlistCollection.doc(docId).get();
  }

  // ==================== UPDATE OPERATIONS ====================

  /// Update an existing wishlist item
  /// Parameters:
  ///   - docId: Required - the Firestore document ID
  ///   - title: Required - updated title
  ///   - category: Optional - updated category
  ///   - isUrgent: Optional - updated urgency status
  ///   - maxPrice: Optional - updated max price
  Future<void> updateWishlistItem({
    required String docId,
    required String title,
    String? category,
    bool? isUrgent,
    double? maxPrice,
  }) async {
    Map<String, dynamic> updates = {
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),  // Update timestamp
    };
    
    // Only add fields that were actually changed
    if (category != null) updates['category'] = category;
    if (isUrgent != null) updates['isUrgent'] = isUrgent;
    if (maxPrice != null) updates['maxPrice'] = maxPrice;
    
    await _wishlistCollection.doc(docId).update(updates);
  }

  /// Mark a wishlist item as fulfilled (purchased/traded)
  /// This hides it from the active wishlist but keeps for history
  Future<void> markAsFulfilled(String docId) async {
    await _wishlistCollection.doc(docId).update({
      'isFulfilled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== DELETE OPERATIONS ====================

  /// Delete a single wishlist item
  Future<void> deleteWishlistItem(String docId) async {
    await _wishlistCollection.doc(docId).delete();
  }

  /// Delete ALL wishlist items for the current user
  /// Use with caution - shows confirmation dialog in UI
  Future<void> clearAllWishlistItems() async {
    final items = await _wishlistCollection.get();
    // Delete each document individually
    for (var doc in items.docs) {
      await doc.reference.delete();
    }
  }
}