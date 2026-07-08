import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../providers_list/providers/search_provider.dart';
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

/// Invalida TODOS os providers que exibem dados de um prestador, em qualquer
/// tela: perfil, avaliações, busca, destaques da home e favoritos.
///
/// Chamar após qualquer mutação que altere nota, score, selos, categorias ou
/// disponibilidade — mesmo quando a tela da mutação não exibe esses dados.
/// Invalidar só o provider da própria tela deixa as outras com cache velho
/// pelo resto da sessão (classe de bug já ocorrida nos Favoritos e nas
/// avaliações); concentre a lista aqui em vez de repeti-la em cada tela.
void invalidateProviderData(WidgetRef ref, String providerId) {
  ref.invalidate(providerProfileProvider(providerId));
  ref.invalidate(ratingsProvider(providerId));
  ref.invalidate(recommendationCountProvider(providerId));
  ref.invalidate(searchProvider);
  ref.invalidate(featuredProvidersProvider);
  ref.invalidate(favoriteProvidersProvider);
  ref.invalidate(allProvidersProvider);
}

/// Variante para quando o prestador edita o PRÓPRIO perfil (habilidades,
/// anúncio, agenda): "Ver meu perfil público" usa providerProfileProvider
/// com o userId do próprio prestador, não prestadorProfileProvider.
void invalidateOwnProviderData(WidgetRef ref) {
  final auth = ref.read(authProvider).valueOrNull;
  if (auth is AuthAuthenticated) {
    invalidateProviderData(ref, auth.userId);
  }
}
