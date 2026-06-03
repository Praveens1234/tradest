import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/storage_service.dart';
import '../../core/api_client.dart';

class AuthNotifier extends StateNotifier<AsyncValue<String?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final token = await StorageService.instance.getToken();
      state = AsyncValue.data(token);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String serverUrl, String apiKey) async {
    state = const AsyncValue.loading();
    try {
      await StorageService.instance.saveServerUrl(serverUrl);

      final dio = Dio(
        BaseOptions(
          baseUrl: serverUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'api_key': apiKey},
      );

      final token = response.data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('No token in response');
      }

      await StorageService.instance.saveToken(token);
      state = AsyncValue.data(token);
    } on DioException catch (e, st) {
      final message = e.response?.data?['detail'] ?? e.message ?? 'Login failed';
      state = AsyncValue.error(Exception(message), st);
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await StorageService.instance.clear();
    state = const AsyncValue.data(null);
  }

  bool get isAuthenticated => state.valueOrNull != null;
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<String?>>(
  (ref) => AuthNotifier(),
);

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.valueOrNull != null;
});
