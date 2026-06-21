import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/provider_summary.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';

class SearchFilters {
  final String categorySlug;
  final String city;
  final double minRating;
  final String sort;
  final String query;

  const SearchFilters({
    this.categorySlug = '',
    this.city = '',
    this.minRating = 0,
    this.sort = 'score',
    this.query = '',
  });

  SearchFilters copyWith({
    String? categorySlug,
    String? city,
    double? minRating,
    String? sort,
    String? query,
  }) =>
      SearchFilters(
        categorySlug: categorySlug ?? this.categorySlug,
        city: city ?? this.city,
        minRating: minRating ?? this.minRating,
        sort: sort ?? this.sort,
        query: query ?? this.query,
      );
}

class SearchFiltersNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => const SearchFilters();

  void setCategory(String slug) => state = state.copyWith(categorySlug: slug);
  void setSort(String sort) => state = state.copyWith(sort: sort);
  void setCity(String city) => state = state.copyWith(city: city);
  void setMinRating(double r) => state = state.copyWith(minRating: r);
  void setQuery(String q) => state = state.copyWith(query: q);
}

final searchFiltersProvider =
    NotifierProvider<SearchFiltersNotifier, SearchFilters>(
        SearchFiltersNotifier.new);

class SearchNotifier extends AsyncNotifier<List<ProviderSummary>> {
  @override
  Future<List<ProviderSummary>> build() => _fetch();

  Future<List<ProviderSummary>> _fetch() async {
    final api = ref.watch(apiClientProvider);
    final filters = ref.watch(searchFiltersProvider);

    final params = <String, dynamic>{
      if (filters.categorySlug.isNotEmpty) 'category': filters.categorySlug,
      if (filters.city.isNotEmpty) 'city': filters.city,
      if (filters.minRating > 0) 'min_rating': filters.minRating,
      'sort': filters.sort,
    };

    final resp = await api.get(ApiEndpoints.providers, params: params);
    final list = resp.data as List<dynamic>;
    var providers = list
        .map((e) => ProviderSummary.fromJson(e as Map<String, dynamic>))
        .toList();

    // Busca por nome é filtrada no cliente: o backend /providers ainda não
    // aceita parâmetro de texto (apenas category/city/min_rating/sort).
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      providers = providers
          .where((p) =>
              p.fullName.toLowerCase().contains(q) ||
              p.categories.any((c) => c.toLowerCase().contains(q)))
          .toList();
    }
    return providers;
  }
}

final searchProvider =
    AsyncNotifierProvider<SearchNotifier, List<ProviderSummary>>(
        SearchNotifier.new);

final categoriesProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.categories);
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
