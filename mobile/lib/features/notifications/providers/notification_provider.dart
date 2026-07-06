import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.notificationsUnreadCount);
  return resp.data['count'] as int;
});

final notificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.notifications);
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
