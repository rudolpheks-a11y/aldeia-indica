import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../providers/search_provider.dart';

class ServicePickerScreen extends ConsumerWidget {
  const ServicePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(serviceCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Encontre um serviço'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar serviços: $e')),
        data: (categories) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: categories.length,
          itemBuilder: (_, i) => _ServiceTile(category: categories[i]),
        ),
      ),
    );
  }
}

class _ServiceTile extends ConsumerWidget {
  final ServiceCategory category;

  const _ServiceTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProviders = category.providerCount > 0;
    final color = hasProviders ? AppColors.primary : Colors.grey[400]!;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasProviders
            ? () {
                ref
                    .read(searchFiltersProvider.notifier)
                    .selectService(category.slug);
                context.push('/search');
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _iconFor(category.iconName),
                color: Colors.white,
                size: 36,
              ),
              const Spacer(),
              Text(
                category.namePt,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                hasProviders
                    ? '${category.providerCount} prestador${category.providerCount > 1 ? 'es' : ''}'
                    : 'Nenhum prestador\nencontrado',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String? name) {
    const map = {
      'cleaning_services': Icons.cleaning_services,
      'home': Icons.home,
      'grass': Icons.grass,
      'pool': Icons.pool,
      'electrical_services': Icons.electrical_services,
      'plumbing': Icons.plumbing,
      'format_paint': Icons.format_paint,
      'construction': Icons.construction,
      'handyman': Icons.handyman,
      'child_care': Icons.child_care,
      'elderly': Icons.elderly,
      'school': Icons.school,
      'pets': Icons.pets,
      'computer': Icons.computer,
      'ac_unit': Icons.ac_unit,
      'directions_car': Icons.directions_car,
    };
    return map[name] ?? Icons.build;
  }
}
