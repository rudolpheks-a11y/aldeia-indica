import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(_conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mensagens')),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => list.isEmpty
            ? const Center(
                child: Text('Sem conversas ainda.\nContacte um prestador!',
                    textAlign: TextAlign.center))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c['other_name'] as String? ?? ''),
                    subtitle: Text(
                      c['last_message'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => context.push('/chat/${c['id']}'),
                  );
                },
              ),
      ),
    );
  }
}

final _conversationsProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.conversations);
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
