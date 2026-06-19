import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ScoreBadge extends StatelessWidget {
  final double score;
  final double size;

  const ScoreBadge({super.key, required this.score, this.size = 56});

  Color get _color {
    if (score >= 85) return AppColors.success;
    if (score >= 65) return AppColors.secondary;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score.round().toString(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.32,
            ),
          ),
          Text(
            'score',
            style: TextStyle(
              color: Colors.white70,
              fontSize: size * 0.16,
            ),
          ),
        ],
      ),
    );
  }
}
