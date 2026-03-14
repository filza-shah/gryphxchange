import 'package:flutter/material.dart';

// Reusable search bar widget used to filter listings across pages.

class ListingSearchBar extends StatelessWidget {
  const ListingSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search by title, course code...',
  });

  // Controls the text field value and lets the parent read or clear it
  final TextEditingController controller;

  // Called whenever the user types — parent uses this to update search query
  final ValueChanged<String> onChanged;

  // Placeholder text shown when the search bar is empty
  // Defaults to a generic listing search hint but can be overridden per page
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(''),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}