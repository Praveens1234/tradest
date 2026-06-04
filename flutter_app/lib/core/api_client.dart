import 'package:dio/dio.dart';
import 'storage_service.dart';

typedef OnUnauthorized = void Function();

class ApiClient {
  static ApiClient? _instance;
  late Dio _dio;
  OnUnauthorized? _onUnauthorized;

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.instance.getToken();
          final baseUrl = await StorageService.instance.getServerUrl();
          options.baseUrl = baseUrl;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await StorageService.instance.clear();
            _onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  void setOnUnauthorized(OnUnauthorized callback) {
    _onUnauthorized = callback;
  }

  /// Build a WebSocket URL by swapping http(s) scheme to ws(s).
  static Future<String> buildWsUrl(String path) async {
    final base = await StorageService.instance.getServerUrl();
    return base.replaceFirst(RegExp(r'^http'), 'ws') + path;
  }

  /// Extract a human-readable error message from DioException or other errors.
  static String extractError(Object e) {
    if (e is DioException) {
      final detail = e.response?.data?['detail'];
      if (detail is String) return detail;
      if (detail is Map) {
        // Handle 409 ConflictInfo object
        if (detail['conflict'] == true) {
          final suggested = detail['suggested_name'];
          if (suggested != null) {
            return 'File already exists. Suggested name: $suggested';
          }
          return 'File already exists';
        }
        return detail['msg']?.toString() ?? detail['message']?.toString() ?? detail.toString();
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) return first['msg']?.toString() ?? first.toString();
      }
      return e.message ?? e.toString();
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? params}) {
    return _dio.get<T>(path, queryParameters: params);
  }

  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? params}) {
    return _dio.post<T>(path, data: data, queryParameters: params);
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) {
    return _dio.put<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path, {dynamic data}) {
    return _dio.delete<T>(path, data: data);
  }

  /// Download bytes — used for report downloads.
  Future<List<int>> getBytes(String path) async {
    final response = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }
}
