import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';

/// Providers compartilhados da feature de Pedidos de Serviço.
///
/// Ficam aqui (e não privados em cada tela) porque as mutações de uma tela
/// precisam invalidar os providers das outras: encerrar/criar um pedido tem
/// que refletir na lista, responder tem que refletir no detalhe.

final requestsProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.requests, params: {'status': 'open'});
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});

final requestDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.requestById(id));
  return resp.data as Map<String, dynamic>;
});

final requestResponsesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.requestResponses(id));
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
