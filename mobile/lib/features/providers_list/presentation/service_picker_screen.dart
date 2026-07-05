import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../providers/search_provider.dart';

class ServicePickerScreen extends ConsumerStatefulWidget {
  const ServicePickerScreen({super.key});

  @override
  ConsumerState<ServicePickerScreen> createState() =>
      _ServicePickerScreenState();
}

class _ServicePickerScreenState extends ConsumerState<ServicePickerScreen> {
  final _ctrl = TextEditingController();
  final _listCtrl = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Encontre um serviço'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar serviço...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: categoriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Erro ao carregar serviços: $e')),
              data: (categories) {
                final filtered = _query.isEmpty
                    ? categories
                    : categories
                        .where((c) =>
                            c.namePt.toLowerCase().contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum prestador encontrado',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return AppScrollbar(
                  controller: _listCtrl,
                  child: ListView.separated(
                  controller: _listCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _CategoryTile(category: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final ServiceCategory category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProviders = category.providerCount > 0;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: hasProviders
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _iconFor(category.iconName),
          color: hasProviders ? AppColors.primary : Colors.grey[400],
          size: 24,
        ),
      ),
      title: Text(
        category.namePt,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: hasProviders ? AppColors.textPrimary : Colors.grey[400],
        ),
      ),
      subtitle: Text(
        hasProviders
            ? '${category.providerCount} prestador${category.providerCount > 1 ? 'es' : ''}'
            : 'Nenhum prestador encontrado',
        style: TextStyle(
          fontSize: 12,
          color: hasProviders ? AppColors.textSecondary : Colors.grey[400],
        ),
      ),
      trailing: hasProviders
          ? const Icon(Icons.chevron_right, color: AppColors.primary)
          : null,
      onTap: hasProviders
          ? () {
              ref
                  .read(searchFiltersProvider.notifier)
                  .selectService(category.slug);
              context.push('/search');
            }
          : null,
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
