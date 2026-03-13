import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.size = 16,
    this.onChanged,
    this.filledColor = const Color(0xFFFFD700),
  });

  final double value;
  final double size;
  final ValueChanged<double>? onChanged;
  final Color filledColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        final double starIndex = index + 1;
        IconData icon;
        // simple fill logic: full star, half star, or empty.
        if (value >= starIndex) {
          icon = Icons.star;
        } else if (value >= starIndex - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }

        return InkWell(
          // btw this can be read-only if onChanged is null.
          onTap: onChanged == null ? null : () => onChanged!(starIndex),
          borderRadius: BorderRadius.circular(size),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              icon,
              size: size,
              color: icon == Icons.star_border
                  ? Colors.grey.shade400
                  : filledColor,
            ),
          ),
        );
      }),
    );
  }
}
