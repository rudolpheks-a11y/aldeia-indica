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

final _currentUserIdProvider = FutureProvider<String?>((ref) async {
  return ref.watch(storageServiceProvider).getUserId();
});

// FamilyAsyncNotifier receives the conversationId via build(arg)
class ChatNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  StreamSubscription? _sub;
  late String _conversationId;

  @override
  Future<List<Map<String, dynamic>>> build(String arg) async {
    _conversationId = arg;
    final myId = await ref.read(_currentUserIdProvider.future);

    final api = ref.read(apiClientProvider);
    final resp = await api.get(ApiEndpoints.messages(arg));
    final history = (resp.data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((m) => _withMine(m, myId))
        .toList();

    final ws = ref.read(wsServiceProvider);
    await ws.connect();

    _sub = ws.messages.listen((msg) {
      if (msg['conversation_id'] == _conversationId &&
          msg['type'] == 'message') {
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data([_withMine(msg, myId), ...current]);
      }
    });

    ref.onDispose(() => _sub?.cancel());

    return history;
  }

  void sendText(String text) {
    ref.read(wsServiceProvider).send({
      'type': 'message',
      'conversation_id': _conversationId,
      'body': text,
    });
  }

  Map<String, dynamic> _withMine(Map<String, dynamic> msg, String? myId) {
    return {
      ...msg,
      'is_mine': myId != null && msg['sender_id'] == myId,
    };
  }
}

final chatProvider = AsyncNotifierProvider.family<ChatNotifier,
    List<Map<String, dynamic>>, String>(ChatNotifier.new);
