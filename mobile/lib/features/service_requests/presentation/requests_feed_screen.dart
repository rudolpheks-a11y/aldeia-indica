import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';

class RequestsFeedScreen extends ConsumerWidget {
  const RequestsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(_requestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de Serviço')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Novo pedido'),
        onPressed: () => context.push('/requests/new'),
      ),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Nenhum pedido aberto'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final req = list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(req['title'] as String? ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (req['category'] != null)
                            Text(req['category'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                          Text(req['requester'] as String? ?? ''),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final _requestsProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.requests, params: {'status': 'open'});
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
