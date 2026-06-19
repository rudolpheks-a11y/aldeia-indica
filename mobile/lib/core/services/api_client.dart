import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import 'storage_service.dart';

class ApiClient {
  late final Dio _dio;
  final StorageService _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
        try {
          final resp = await _dio.post(
            ApiEndpoints.refresh,
            data: {'refresh_token': refreshToken},
            options: Options(headers: {}),
          );
          final newAccess = resp.data['AccessToken'] as String;
          final newRefresh = resp.data['RefreshToken'] as String;
          await _storage.saveTokens(
              accessToken: newAccess, refreshToken: newRefresh);

          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retried = await _dio.fetch(err.requestOptions);
          return handler.resolve(retried);
        } catch (_) {
          await _storage.clear();
        }
      }
    }
    handler.next(err);
  }

  Future<Response<T>> get<T>(String path,
          {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete(path);
}
