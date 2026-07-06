import 'package:flutter/material.dart';
import '../../../shared/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
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
    final auth = ref.watch(authProvider).valueOrNull;
    final myUserId = auth is AuthAuthenticated ? auth.userId : null;

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
                  final isMine = myUserId != null && req['requester_id'] == myUserId;
                  final responseCount = req['response_count'] as int? ?? 0;
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
                      trailing: isMine
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  responseCount == 0
                                      ? 'Sem respostas'
                                      : '$responseCount ${responseCount == 1 ? 'resposta' : 'respostas'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: responseCount == 0
                                        ? AppColors.textSecondary
                                        : AppColors.primary,
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () => context.push('/requests/${req['id']}'),
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
