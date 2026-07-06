import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

final _requestDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.requestById(id));
  return resp.data as Map<String, dynamic>;
});

final _requestResponsesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.requestResponses(id));
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final _messageCtrl = TextEditingController(
      text: 'Tenho interesse nesse serviço, posso te ajudar!');
  final _scrollCtrl = ScrollController();
  bool _submitting = false;
  bool _closing = false;
  bool _responded = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _respond() async {
    if (_messageCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).post(
        ApiEndpoints.requestResponses(widget.requestId),
        data: {'message': _messageCtrl.text.trim()},
      );
      if (mounted) {
        setState(() => _responded = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interesse enviado ao morador!')),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        setState(() => _responded = true);
      }
      final msg = e.response?.statusCode == 409
          ? 'Você já demonstrou interesse nesse pedido.'
          : 'Não foi possível enviar. Tente novamente.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error900),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _closeRequest() async {
    setState(() => _closing = true);
    try {
      await ref.read(apiClientProvider).put(
        ApiEndpoints.requestById(widget.requestId),
        data: {'status': 'closed'},
      );
      ref.invalidate(_requestDetailProvider(widget.requestId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido encerrado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error900),
        );
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _startChat(String providerId) async {
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api
          .post('/chat/conversations', data: {'other_user_id': providerId});
      final convId = resp.data['id'] as String;
      if (mounted) context.push('/chat/$convId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar conversa: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(_requestDetailProvider(widget.requestId));
    final auth = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
          leading: const AppBackButton(), title: const Text('Pedido de Serviço')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (req) {
          final isOwner =
              auth is AuthAuthenticated && auth.userId == req['requester_id'];
          final isPrestador = auth is AuthAuthenticated && auth.role == 'prestador';
          final isOpen = req['status'] == 'open';

          return AppScrollbar(
            controller: _scrollCtrl,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req['title'] as String? ?? '',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (req['category'] != null)
                        Chip(
                          label: Text(req['category'] as String),
                          backgroundColor: AppColors.primary50,
                        ),
                      Chip(
                        label: Text(isOpen ? 'Aberto' : 'Encerrado'),
                        backgroundColor:
                            isOpen ? AppColors.primary50 : AppColors.neutral100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Publicado por ${req['requester']}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  if ((req['description'] as String?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    Text(req['description'] as String,
                        style: const TextStyle(fontSize: 15)),
                  ],
                  const Divider(height: 40),
                  if (isOwner) ...[
                    Row(
                      children: [
                        Text('Respostas',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (isOpen)
                          TextButton(
                            onPressed: _closing ? null : _closeRequest,
                            child: _closing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Encerrar pedido'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ResponsesList(
                        requestId: widget.requestId, onChat: _startChat),
                  ] else if (isPrestador && isOpen) ...[
                    Text('Demonstrar interesse',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_responded)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: AppColors.primary),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    'Você já demonstrou interesse. O morador pode iniciar uma conversa com você.')),
                          ],
                        ),
                      )
                    else ...[
                      TextField(
                        controller: _messageCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Mensagem para o morador',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _respond,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Tenho interesse'),
                        ),
                      ),
                    ],
                  ] else if (!isOpen) ...[
                    const Text('Este pedido já foi encerrado.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResponsesList extends ConsumerWidget {
  final String requestId;
  final ValueChanged<String> onChat;
  const _ResponsesList({required this.requestId, required this.onChat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responses = ref.watch(_requestResponsesProvider(requestId));
    return responses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erro ao carregar respostas: $e'),
      data: (list) => list.isEmpty
          ? const Text('Nenhum prestador demonstrou interesse ainda.',
              style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: list.map((r) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['provider'] as String? ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(r['message'] as String? ?? ''),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Conversar'),
                            onPressed: () =>
                                onChat(r['provider_id'] as String),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
