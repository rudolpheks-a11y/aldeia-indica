import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';

final providerProfileProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.providerById(id));
  return resp.data as Map<String, dynamic>;
});

// Retorna apenas o count — identidade dos indicadores é preservada.
final recommendationCountProvider =
    FutureProvider.family<int, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.recommendationsByProvider(id));
  final data = resp.data as Map<String, dynamic>;
  return data['count'] as int? ?? 0;
});

final ratingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.ratingsByProvider(id));
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
