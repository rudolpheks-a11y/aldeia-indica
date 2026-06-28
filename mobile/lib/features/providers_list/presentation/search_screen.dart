import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/search_provider.dart';
import 'provider_card.dart';

const _days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Aldeia Indica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/conversations'),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.push('/requests'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar prestador ou serviço...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () => _showFilters(context),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (v) =>
                  ref.read(searchFiltersProvider.notifier).setQuery(v),
            ),
          ),
          const _CategoryChips(),
          const _DayChips(),
          Expanded(
            child: search.when(
              data: (providers) => providers.isEmpty
                  ? const Center(child: Text('Nenhum prestador encontrado'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: providers.length,
                      itemBuilder: (_, i) => ProviderCard(provider: providers[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _FilterSheet(),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final selected = ref.watch(searchFiltersProvider).categorySlug;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Todos'),
              selected: selected == '',
              onSelected: (_) =>
                  ref.read(searchFiltersProvider.notifier).setCategory(''),
            ),
          ),
          ...categories.when(
            data: (cats) => cats.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(c['name_pt'] as String),
                    selected: selected == c['slug'],
                    onSelected: (_) => ref
                        .read(searchFiltersProvider.notifier)
                        .setCategory(c['slug'] as String),
                  ),
                )),
            loading: () => [],
            error: (_, __) => [],
          ),
        ],
      ),
    );
  }
}

class _DayChips extends ConsumerWidget {
  const _DayChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(searchFiltersProvider).dayOfWeek;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Qualquer dia'),
              selected: selectedDay == -1,
              selectedColor: AppColors.primary.withOpacity(0.15),
              checkmarkColor: AppColors.primary,
              onSelected: (_) =>
                  ref.read(searchFiltersProvider.notifier).setDayOfWeek(-1),
            ),
          ),
          ...List.generate(7, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_days[i]),
                selected: selectedDay == i,
                selectedColor: AppColors.primary.withOpacity(0.15),
                checkmarkColor: AppColors.primary,
                onSelected: (_) => ref
                    .read(searchFiltersProvider.notifier)
                    .setDayOfWeek(selectedDay == i ? -1 : i),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFiltersProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filtros',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Ordenar por'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'score', label: Text('Score')),
              ButtonSegment(value: 'rating', label: Text('Nota')),
              ButtonSegment(value: 'recommendations', label: Text('Indicações')),
            ],
            selected: {filters.sort},
            onSelectionChanged: (v) =>
                ref.read(searchFiltersProvider.notifier).setSort(v.first),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}
