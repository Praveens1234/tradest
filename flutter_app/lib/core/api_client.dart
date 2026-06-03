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

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    final baseUrl = await StorageService.instance.getServerUrl();
    return _dio.get<T>(
      path,
      queryParameters: params,
      options: Options(extra: {'baseUrl': baseUrl}),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
  }) async {
    final baseUrl = await StorageService.instance.getServerUrl();
    return _dio.post<T>(
      path,
      data: data,
      options: Options(extra: {'baseUrl': baseUrl}),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) async {
    final baseUrl = await StorageService.instance.getServerUrl();
    return _dio.put<T>(
      path,
      data: data,
      options: Options(extra: {'baseUrl': baseUrl}),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
  }) async {
    final baseUrl = await StorageService.instance.getServerUrl();
    return _dio.delete<T>(
      path,
      data: data,
      options: Options(extra: {'baseUrl': baseUrl}),
    );
  }
}
