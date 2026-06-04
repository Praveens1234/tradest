import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../shared/models/ea_model.dart';

final eaListProvider = FutureProvider<List<EAModel>>((ref) async {
  final response = await ApiClient.instance.get<List<dynamic>>('/ea/list');
  final list = response.data ?? [];
  return list
      .map((e) => EAModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class CompileResult {
  final bool success;
  final String? output;
  final List<String> errors;
  final List<String> warnings;

  const CompileResult({
    required this.success,
    this.output,
    this.errors = const [],
    this.warnings = const [],
  });
}

class EAOperationsState {
  final bool isLoading;
  final String? error;
  final CompileResult? compileResult;

  const EAOperationsState({
    this.isLoading = false,
    this.error,
    this.compileResult,
  });

  EAOperationsState copyWith({
    bool? isLoading,
    String? error,
    CompileResult? compileResult,
    bool clearError = false,
    bool clearCompile = false,
  }) {
    return EAOperationsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      compileResult:
          clearCompile ? null : (compileResult ?? this.compileResult),
    );
  }
}

class EAOperationsNotifier extends StateNotifier<EAOperationsState> {
  final Ref _ref;

  EAOperationsNotifier(this._ref) : super(const EAOperationsState());

  Future<CompileResult> compileEA(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearCompile: true);
    try {
      final response =
          await ApiClient.instance.post<Map<String, dynamic>>('/ea/$id/compile');
      final data = response.data ?? {};

      final status = data['status'] as String? ?? 'error';
      final success = status == 'success';
      final output = data['raw_log'] as String?;
      final errorsRaw = data['errors'] as List?;
      final warningsRaw = data['warnings'] as List?;

      String fmtEntry(dynamic e) => e is Map
          ? '${e['file']}(${e['line']},${e['col']}): ${e['message']}'
          : e.toString();

      final errors = errorsRaw?.map(fmtEntry).toList() ?? <String>[];
      final warnings = warningsRaw?.map(fmtEntry).toList() ?? <String>[];

      final result = CompileResult(
        success: success,
        output: output,
        errors: errors,
        warnings: warnings,
      );

      state = state.copyWith(isLoading: false, compileResult: result);
      return result;
    } on DioException catch (e) {
      final msg =
          e.response?.data?['detail']?.toString() ?? e.message ?? 'Compile failed';
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteEA(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ApiClient.instance.delete<dynamic>('/ea/$id');
      state = state.copyWith(isLoading: false);
      _ref.invalidate(eaListProvider);
    } on DioException catch (e) {
      final msg =
          e.response?.data?['detail']?.toString() ?? e.message ?? 'Delete failed';
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> createEA({
    required String name,
    required String content,
    String type = 'mq5',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ApiClient.instance.post<dynamic>(
        '/ea/create',
        data: {
          'name': name,
          'content': content,
          'type': type,
        },
      );
      state = state.copyWith(isLoading: false);
      _ref.invalidate(eaListProvider);
    } on DioException catch (e) {
      final msg =
          e.response?.data?['detail']?.toString() ?? e.message ?? 'Create failed';
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void clearCompileResult() {
    state = state.copyWith(clearCompile: true);
  }
}

final eaOperationsProvider =
    StateNotifierProvider<EAOperationsNotifier, EAOperationsState>(
  (ref) => EAOperationsNotifier(ref),
);
