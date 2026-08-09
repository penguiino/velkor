import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/http_service.dart';
import '../../../main.dart';
import '../../auth/controller/auth_controller.dart';
import '../models/route_model.dart';
import '../repositories/route_repository.dart';

enum RouteLoadStatus { loading, error, noRoute, ready }

class RouteControllerState {
  final RouteLoadStatus status;
  final RouteModel? route;
  final String? error;
  final bool actionInProgress;

  const RouteControllerState({
    required this.status,
    this.route,
    this.error,
    this.actionInProgress = false,
  });

  RouteControllerState copyWith({
    RouteLoadStatus? status,
    RouteModel? route,
    String? error,
    bool? actionInProgress,
  }) {
    return RouteControllerState(
      status: status ?? this.status,
      route: route ?? this.route,
      error: error,
      actionInProgress: actionInProgress ?? this.actionInProgress,
    );
  }
}

class RouteController extends Notifier<RouteControllerState> {
  late final RouteRepository repository;

  Timer? _pingTimer;

  @override
  RouteControllerState build() {
    repository = ref.read(routeRepositoryProvider);

    ref.onDispose(() {
      _pingTimer?.cancel();
    });

    _loadToday();

    return const RouteControllerState(status: RouteLoadStatus.loading);
  }

  String? get _token => ref.read(authControllerProvider).token;

  Future<void> _handleAuthError(Object e) async {
    if (e is ApiException && e.statusCode == 401) {
      _pingTimer?.cancel();
      await WakelockPlus.disable();
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  // ---------------- LOAD TODAY'S ROUTE ----------------

  Future<void> _loadToday() async {
    final token = _token;
    if (token == null) return;

    try {
      final route = await repository.getTodayRoute(token);

      if (route == null) {
        state = const RouteControllerState(status: RouteLoadStatus.noRoute);
        return;
      }

      state = RouteControllerState(status: RouteLoadStatus.ready, route: route);

      // If the app was killed and reopened mid-route, resume tracking.
      if (route.status == 'active') {
        await WakelockPlus.enable();
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        _startPingLoop(route.id);
      }
    } catch (e) {
      await _handleAuthError(e);

      if (state.route != null) {
        // Keep showing the route already on screen; just surface the
        // failure so the UI can show a transient error (e.g. a snackbar)
        // instead of silently doing nothing.
        state = state.copyWith(error: e.toString());
      } else {
        state = RouteControllerState(
          status: RouteLoadStatus.error,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> refresh() => _loadToday();

  // ---------------- START ROUTE ----------------

  Future<void> startRoute() async {
    final token = _token;
    final route = state.route;

    if (token == null || route == null) return;
    if (state.actionInProgress) return;

    state = state.copyWith(actionInProgress: true, error: null);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        throw Exception('Location services disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final updated = await repository.startRoute(token, route.id);

      await WakelockPlus.enable();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      _startPingLoop(updated.id);

      state = state.copyWith(
        status: RouteLoadStatus.ready,
        route: updated,
        actionInProgress: false,
      );
    } catch (e) {
      await _handleAuthError(e);

      state = state.copyWith(
        actionInProgress: false,
        error: e.toString(),
      );
    }
  }

  // ---------------- PING LOOP ----------------

  void _startPingLoop(String routeId) {
    _pingTimer?.cancel();

    _pingTimer = Timer.periodic(AppConfig.routePingInterval, (_) async {
      final token = _token;
      if (token == null) return;

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );

        final updated = await repository.ping(
          token: token,
          routeId: routeId,
          lat: position.latitude,
          lng: position.longitude,
        );

        if (updated != null) {
          state = state.copyWith(status: RouteLoadStatus.ready, route: updated);

          if (updated.status == 'completed') {
            _pingTimer?.cancel();
            await WakelockPlus.disable();
            await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          }
        }
      } catch (e) {
        await _handleAuthError(e);
      }
    });
  }

  // ---------------- MANUAL OVERRIDES ----------------
  // For when GPS-based arrival/departure detection fails (weak signal,
  // indoors, etc). Re-fetches today's route afterward so the UI reflects
  // the new current/next stop immediately.

  Future<void> manualArrive(String stopId) async {
    final token = _token;
    final route = state.route;
    if (token == null || route == null) return;

    state = state.copyWith(actionInProgress: true, error: null);

    try {
      await repository.manualArrive(token: token, routeId: route.id, stopId: stopId);
      await _loadToday();
      state = state.copyWith(actionInProgress: false, error: state.error);
    } catch (e) {
      await _handleAuthError(e);
      state = state.copyWith(actionInProgress: false, error: e.toString());
    }
  }

  Future<void> manualDepart(String stopId) async {
    final token = _token;
    final route = state.route;
    if (token == null || route == null) return;

    state = state.copyWith(actionInProgress: true, error: null);

    try {
      await repository.manualDepart(token: token, routeId: route.id, stopId: stopId);
      await _loadToday();
      state = state.copyWith(actionInProgress: false, error: state.error);
    } catch (e) {
      await _handleAuthError(e);
      state = state.copyWith(actionInProgress: false, error: e.toString());
    }
  }
}
