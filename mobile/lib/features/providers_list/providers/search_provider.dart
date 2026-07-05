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
  final int dayOfWeek; // -1 = sem filtro, 0-6 = dia da semana

  const SearchFilters({
    this.categorySlug = '',
    this.city = '',
    this.minRating = 0,
    this.sort = 'score',
    this.query = '',
    this.dayOfWeek = -1,
  });

  SearchFilters copyWith({
    String? categorySlug,
    String? city,
    double? minRating,
    String? sort,
    String? query,
    int? dayOfWeek,
  }) =>
      SearchFilters(
        categorySlug: categorySlug ?? this.categorySlug,
        city: city ?? this.city,
        minRating: minRating ?? this.minRating,
        sort: sort ?? this.sort,
        query: query ?? this.query,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
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
  void setDayOfWeek(int day) => state = state.copyWith(dayOfWeek: day);
  void selectService(String slug) => state = SearchFilters(categorySlug: slug);
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
      if (filters.dayOfWeek >= 0) 'day_of_week': filters.dayOfWeek,
      'sort': filters.sort,
    };

    final resp = await api.get(ApiEndpoints.providers, params: params);
    final list = resp.data as List<dynamic>;
    var providers = list
        .map((e) => ProviderSummary.fromJson(e as Map<String, dynamic>))
        .toList();

    // Busca por nome filtrada no cliente (backend não tem param de texto ainda).
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

final categoriesProvider = FutureProvider<List<ServiceCategory>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.categories);
  return parseServiceCategories(resp.data as List<dynamic>);
});

List<ServiceCategory> parseServiceCategories(List<dynamic> json) {
  return json.cast<Map<String, dynamic>>().map((c) {
    return ServiceCategory(
      slug: c['slug'] as String,
      namePt: c['name_pt'] as String,
      iconName: c['icon_name'] as String?,
      providerCount: c['provider_count'] as int? ?? 0,
    );
  }).toList();
}

final featuredProvidersProvider =
    FutureProvider<List<ProviderSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.providersFeatured);
  return (resp.data as List<dynamic>)
      .map((e) => ProviderSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ServiceCategory {
  final String slug;
  final String namePt;
  final String? iconName;
  final int providerCount;

  const ServiceCategory({
    required this.slug,
    required this.namePt,
    this.iconName,
    required this.providerCount,
  });
}

final allProvidersProvider = FutureProvider<List<ProviderSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.providers,
      params: {'sort': 'score', 'limit': '200'});
  return (resp.data as List<dynamic>)
      .map((e) => ProviderSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

