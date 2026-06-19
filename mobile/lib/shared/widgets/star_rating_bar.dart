import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class StarRatingBar extends StatelessWidget {
  final double rating;
  final int maxStars;
  final double size;

  const StarRatingBar({
    super.key,
    required this.rating,
    this.maxStars = 5,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          filled
              ? Icons.star
              : half
                  ? Icons.star_half
                  : Icons.star_border,
          color: AppColors.starColor,
          size: size,
        );
      }),
    );
  }
}

class InteractiveStarRating extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const InteractiveStarRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return GestureDetector(
          onTap: () => widget.onChanged(i + 1),
          child: Icon(
            i < widget.value ? Icons.star : Icons.star_border,
            color: AppColors.starColor,
            size: widget.size,
          ),
        );
      }),
    );
  }
}
