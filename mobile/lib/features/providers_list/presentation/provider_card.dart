import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/models/provider_summary.dart';
import '../../../shared/widgets/star_rating_bar.dart';
import '../../../shared/widgets/score_badge.dart';
import '../../../core/constants/app_colors.dart';

class ProviderCard extends StatelessWidget {
  final ProviderSummary provider;
  final VoidCallback? onTap;

  const ProviderCard({super.key, required this.provider, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => context.push('/provider/${provider.userId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.neutral200,
                child: provider.avatarKey != null
                    ? null
                    : Text(
                        provider.fullName[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.fullName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      provider.categories.take(2).join(' • '),
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (provider.avgRating != null) ...[
                          StarRatingBar(
                              rating: provider.avgRating!, size: 14),
                          const SizedBox(width: 4),
                          Text(provider.avgRating!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.thumb_up_alt_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text('${provider.recommendationCount}',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${provider.city} · ${provider.yearsInNeighborhood} anos no bairro',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ScoreBadge(score: provider.scoreAldeia, size: 48),
            ],
          ),
        ),
      ),
    );
  }
}
