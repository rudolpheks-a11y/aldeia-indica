import 'package:flutter/material.dart';
import '../../../shared/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../shared/widgets/app_scrollbar.dart';

class RequestsFeedScreen extends ConsumerStatefulWidget {
  const RequestsFeedScreen({super.key});

  @override
  ConsumerState<RequestsFeedScreen> createState() => _RequestsFeedScreenState();
}

class _RequestsFeedScreenState extends ConsumerState<RequestsFeedScreen> {
  final _listCtrl = ScrollController();

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(_requestsProvider);

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Pedidos de Serviço')),
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
            : AppScrollbar(
                controller: _listCtrl,
                child: ListView.builder(
                controller: _listCtrl,
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
      ),
    );
  }
}

final _requestsProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.requests, params: {'status': 'open'});
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
