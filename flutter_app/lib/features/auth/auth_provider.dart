import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/storage_service.dart';

class AuthNotifier extends StateNotifier<AsyncValue<String?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final apiKey = await StorageService.instance.getApiKey();
      state = AsyncValue.data(apiKey);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String serverUrl, String apiKey) async {
    state = const AsyncValue.loading();
    try {
      await StorageService.instance.saveServerUrl(serverUrl);

      // Validate the API key against the server
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

      await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'api_key': apiKey},
      );

      // Store the raw API key — it never expires unlike JWT tokens
      await StorageService.instance.saveApiKey(apiKey);
      state = AsyncValue.data(apiKey);
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
