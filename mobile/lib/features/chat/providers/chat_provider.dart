import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/ws_service.dart';

final wsServiceProvider = Provider((ref) {
  final ws = WsService(ref.watch(storageServiceProvider));
  ref.onDispose(ws.dispose);
  return ws;
});

class ChatNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  late String _conversationId;
  StreamSubscription? _sub;

  @override
  Future<List<Map<String, dynamic>>> build() async => [];

  Future<void> init(String conversationId) async {
    _conversationId = conversationId;

    final api = ref.read(apiClientProvider);
    final resp = await api.get(ApiEndpoints.messages(conversationId));
    final history = (resp.data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .reversed
        .toList();

    state = AsyncValue.data(history);

    final ws = ref.read(wsServiceProvider);
    await ws.connect();

    _sub = ws.messages.listen((msg) {
      if (msg['conversation_id'] == _conversationId &&
          msg['type'] == 'message') {
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data([msg, ...current]);
      }
    });

    ref.onDispose(() => _sub?.cancel());
  }

  void sendText(String text) {
    ref.read(wsServiceProvider).send({
      'type': 'message',
      'conversation_id': _conversationId,
      'body': text,
    });
  }
}

final chatProvider = AsyncNotifierProvider.family<ChatNotifier,
    List<Map<String, dynamic>>, String>((ref, conversationId) {
  final notifier = ChatNotifier();
  Future.microtask(() => notifier.init(conversationId));
  return notifier;
});
