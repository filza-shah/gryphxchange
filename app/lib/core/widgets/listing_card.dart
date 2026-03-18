import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/mock_data.dart';

// Reusable card widget for displaying a single listing.
// Tapping it navigates to the listing detail page.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing});

  final Listing listing;

  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        // navigate to listing detail page on tap
        onTap: () => context.push('/listing/${listing.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // left side - fixed size image
              if (listing.images.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  listing.images.first,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  // show loading indicator while image loads
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  // show placeholder if image fails to load
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
            // right side - listing details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // listing title
                    Text(
                      listing.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // course code and semester
                    Text(
                      '${listing.courseCode} • ${listing.semester}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // category
                    Text(
                      listing.category,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    listing.isTrade
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.swap_horiz,
                                size: 14,
                                color: Color(0xFF8B0000),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  listing.tradeFor != null &&
                                          listing.tradeFor!.isNotEmpty
                                      ? 'Wants: ${listing.tradeFor}'
                                      : 'Trade',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8B0000),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            '\$${listing.price?.toStringAsFixed(0) ?? ''}',
                            style: const TextStyle(
                              color: Color(0xFF8B0000),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}