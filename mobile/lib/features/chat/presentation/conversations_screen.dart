import 'package:flutter/material.dart';
import '../../../shared/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../shared/widgets/app_scrollbar.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final _listCtrl = ScrollController();

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(_conversationsProvider);

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Mensagens')),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => list.isEmpty
            ? const Center(
                child: Text('Sem conversas ainda.\nContacte um prestador!',
                    textAlign: TextAlign.center))
            : AppScrollbar(
                controller: _listCtrl,
                child: ListView.builder(
                controller: _listCtrl,
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
      ),
    );
  }
}

final _conversationsProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.conversations);
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
