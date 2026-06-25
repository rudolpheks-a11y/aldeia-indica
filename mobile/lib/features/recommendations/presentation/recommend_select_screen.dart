import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../providers_list/data/models/provider_summary.dart';
import '../../providers_list/providers/search_provider.dart';

class RecommendSelectScreen extends ConsumerStatefulWidget {
  const RecommendSelectScreen({super.key});

  @override
  ConsumerState<RecommendSelectScreen> createState() =>
      _RecommendSelectScreenState();
}

class _RecommendSelectScreenState
    extends ConsumerState<RecommendSelectScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allProvidersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Recomende um prestador'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar prestador pelo nome...',
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
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (providers) {
                final filtered = _query.isEmpty
                    ? providers
                    : providers
                        .where((p) =>
                            p.fullName.toLowerCase().contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum prestador encontrado',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      _ProviderTile(provider: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final ProviderSummary provider;
  const _ProviderTile({required this.provider});

  @override
  Widget build(BuildContext context) {
    final initials = provider.fullName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        provider.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: provider.categories.isNotEmpty
          ? Text(
              provider.categories.join(' · '),
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
      onTap: () => context.push('/recommend/${provider.userId}'),
    );
  }
}
