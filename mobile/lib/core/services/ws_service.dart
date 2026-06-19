import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_endpoints.dart';
import 'storage_service.dart';

class WsService {
  final StorageService _storage;
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  bool _disposed = false;

  WsService(this._storage);

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> connect() async {
    final token = await _storage.getAccessToken();
    if (token == null) return;

    final uri = Uri.parse('${ApiEndpoints.wsUrl}${ApiEndpoints.wsChat}?token=$token');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        if (data is String) {
          final msg = json.decode(data) as Map<String, dynamic>;
          _controller.add(msg);
        }
      },
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
    );
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(json.encode(message));
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), connect);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
