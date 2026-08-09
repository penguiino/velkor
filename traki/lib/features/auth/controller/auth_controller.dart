import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_service.dart';
import '../../../main.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_storage_service.dart';

enum AuthStatus { checking, loggedOut, loggedIn, loading, error }

class AuthState {
  final AuthStatus status;
  final String? token;
  final String? workerId;
  final String? workerCode;
  final String? workerName;
  final String? error;

  const AuthState({
    required this.status,
    this.token,
    this.workerId,
    this.workerCode,
    this.workerName,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    String? workerId,
    String? workerCode,
    String? workerName,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      workerId: workerId ?? this.workerId,
      workerCode: workerCode ?? this.workerCode,
      workerName: workerName ?? this.workerName,
      error: error,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  late final AuthRepository repository;
  late final AuthStorageService storage;

  @override
  AuthState build() {
    repository = ref.read(authRepositoryProvider);
    storage = ref.read(authStorageProvider);

    _restoreSession();

    return const AuthState(status: AuthStatus.checking);
  }

  Future<void> _restoreSession() async {
    final token = await storage.getToken();

    if (token == null) {
      state = const AuthState(status: AuthStatus.loggedOut);
      return;
    }

    final name = await storage.getWorkerName();
    final code = await storage.getWorkerCode();

    // We trust the persisted token at startup without re-validating it
    // against the server -- if it has expired, the first authenticated
    // request in RouteController will fail with a 401 and call
    // logout() below, dropping the user back to the login screen.
    state = AuthState(
      status: AuthStatus.loggedIn,
      token: token,
      workerCode: code,
      workerName: name,
    );
  }

  Future<void> login(String workerCode, String pin) async {
    if (workerCode.trim().isEmpty || pin.trim().isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Worker ID and PIN are required',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final result = await repository.login(
        workerCode: workerCode.trim(),
        pin: pin.trim(),
      );

      await storage.saveSession(
        token: result['token'],
        workerId: result['workerId'],
        workerCode: result['workerCode'],
        workerName: result['workerName'],
      );

      state = AuthState(
        status: AuthStatus.loggedIn,
        token: result['token'],
        workerId: result['workerId'],
        workerCode: result['workerCode'],
        workerName: result['workerName'],
      );
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.message);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> logout() async {
    await storage.clear();
    state = const AuthState(status: AuthStatus.loggedOut);
  }
}
