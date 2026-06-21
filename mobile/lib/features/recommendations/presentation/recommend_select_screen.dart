import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers_list/providers/search_provider.dart';
import '../../providers_list/presentation/provider_card.dart';

/// Passo 1 do fluxo "Recomende um prestador": o morador escolhe quem avaliar.
/// Reusa a mesma lista/busca da tela de busca; ao tocar, vai para a tela de
/// nota em estrelas (/recommend/:id) em vez do perfil.
class RecommendSelectScreen extends ConsumerStatefulWidget {
  const RecommendSelectScreen({super.key});

  @override
  ConsumerState<RecommendSelectScreen> createState() =>
      _RecommendSelectScreenState();
}

class _RecommendSelectScreenState extends ConsumerState<RecommendSelectScreen> {
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
      appBar: AppBar(title: const Text('Recomende um prestador')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar prestador pelo nome...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (v) =>
                  ref.read(searchFiltersProvider.notifier).setQuery(v),
            ),
          ),
          _CategoryChips(),
          Expanded(
            child: search.when(
              data: (providers) => providers.isEmpty
                  ? const Center(child: Text('Nenhum prestador encontrado'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: providers.length,
                      itemBuilder: (_, i) => ProviderCard(
                        provider: providers[i],
                        onTap: () =>
                            context.push('/recommend/${providers[i].userId}'),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
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
