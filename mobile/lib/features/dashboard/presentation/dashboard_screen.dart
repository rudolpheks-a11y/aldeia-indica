import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../shared/widgets/score_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(_dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Painel')),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ScoreBadge(
                        score: (data['score_aldeia'] as num? ?? 0).toDouble(),
                        size: 80,
                      ),
                      Column(
                        children: [
                          _Stat('Visualizações',
                              data['view_count']?.toString() ?? '0'),
                          const SizedBox(height: 8),
                          _Stat('Contatos',
                              data['contact_count']?.toString() ?? '0'),
                        ],
                      ),
                      Column(
                        children: [
                          _Stat('Avaliação',
                              (data['avg_rating'] as num? ?? 0)
                                  .toStringAsFixed(1)),
                          const SizedBox(height: 8),
                          _Stat('Contratações',
                              data['total_hires']?.toString() ?? '0'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

final _dashboardProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.dashboardSummary);
  return resp.data as Map<String, dynamic>;
});
