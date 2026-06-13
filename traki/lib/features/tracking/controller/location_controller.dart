import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/config/app_config.dart';
import '../services/local_storage_service.dart';
import '../repositories/location_repository_impl.dart';

enum LocationStatus {
  idle,
  active,
  loading,
  error,
}

class LocationState {
  final LocationStatus status;
  final String? jobId;
  final String? error;

  const LocationState({
    required this.status,
    this.jobId,
    this.error,
  });

  LocationState copyWith({
    LocationStatus? status,
    String? jobId,
    String? error,
  }) {
    return LocationState(
      status: status ?? this.status,
      jobId: jobId ?? this.jobId,
      error: error,
    );
  }
}

class LocationController
    extends StateNotifier<LocationState> {

  final LocationRepositoryImpl repository;

  final LocalStorageService localStorage;

  Timer? _pingTimer;

  LocationController(
      this.repository,
      this.localStorage,
      ) : super(
    const LocationState(
      status: LocationStatus.idle,
    ),
  ) {
    _init();
  }

  // ---------------- INIT ----------------

  Future<void> _init() async {
    try {
      final savedJobId =
      await localStorage.getJobId();

      if (savedJobId != null) {

        state = state.copyWith(
          status: LocationStatus.active,
          jobId: savedJobId,
          error: null,
        );

        // keep screen awake
        await WakelockPlus.enable();

        // immersive sticky
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        );

        // restart timer after app reopen
        _startPingLoop(savedJobId);
      }

    } catch (e) {

      state = state.copyWith(
        status: LocationStatus.error,
        error: e.toString(),
      );
    }
  }

  // ---------------- START JOB ----------------

  Future<void> startJob(
      String workerId,
      ) async {

    if (workerId.trim().isEmpty) {

      state = state.copyWith(
        status: LocationStatus.error,
        error: "Worker ID required",
      );

      return;
    }

    if (state.status ==
        LocationStatus.loading) {
      return;
    }

    try {

      state = state.copyWith(
        status: LocationStatus.loading,
        error: null,
      );

      if (state.jobId != null) {

        state = state.copyWith(
          status: LocationStatus.active,
        );

        return;
      }

      final enabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!enabled) {
        throw Exception(
          "Location services disabled",
        );
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {

        permission =
        await Geolocator
            .requestPermission();
      }

      if (permission ==
          LocationPermission.denied ||
          permission ==
              LocationPermission
                  .deniedForever) {

        throw Exception(
          "Location permission denied",
        );
      }

      final position =
      await Geolocator
          .getCurrentPosition(
        desiredAccuracy:
        LocationAccuracy.low,
        timeLimit:
        const Duration(seconds: 10),
      );

      final result =
      await repository.startJob(
        workerId: workerId.trim(),
        lat: position.latitude,
        lng: position.longitude,
      );

      final jobId = result['jobId'];

      await localStorage.saveJobId(
        jobId,
      );

      // keep device awake
      await WakelockPlus.enable();

      // immersive sticky mode
      await SystemChrome
          .setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );

      // start pings
      _startPingLoop(jobId);

      state = state.copyWith(
        status: LocationStatus.active,
        jobId: jobId,
        error: null,
      );

    } catch (e) {

      state = state.copyWith(
        status: LocationStatus.error,
        error: e.toString(),
      );

      rethrow;
    }
  }

  // ---------------- PING LOOP ----------------

  void _startPingLoop(
      String jobId,
      ) {

    _pingTimer?.cancel();

    _pingTimer = Timer.periodic(
      AppConfig.pingInterval,
          (_) async {

        try {

          final position =
          await Geolocator
              .getCurrentPosition(
            desiredAccuracy:
            LocationAccuracy.low,
            timeLimit: const Duration(
              seconds: 10,
            ),
          );

          await repository.sendPing(
            jobId: jobId,
            lat: position.latitude,
            lng: position.longitude,
          );

          debugPrint(
            'PING SENT',
          );

        } catch (e) {

          debugPrint(
            'PING FAILED: $e',
          );
        }
      },
    );
  }

  // ---------------- END JOB ----------------

  Future<void> endJob() async {

    final jobId = state.jobId;

    if (jobId == null) {
      return;
    }

    if (state.status ==
        LocationStatus.loading) {
      return;
    }

    try {

      state = state.copyWith(
        status: LocationStatus.loading,
        error: null,
      );

      final enabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!enabled) {
        throw Exception(
          "Location services disabled",
        );
      }

      final position =
      await Geolocator
          .getCurrentPosition(
        desiredAccuracy:
        LocationAccuracy.low,
        timeLimit:
        const Duration(seconds: 10),
      );

      await repository.endJob(
        jobId: jobId,
        lat: position.latitude,
        lng: position.longitude,
      );

      _pingTimer?.cancel();

      await WakelockPlus.disable();

      // restore normal UI
      await SystemChrome
          .setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );

      await localStorage.clearJobId();

      await localStorage.clearQueue();

      state = const LocationState(
        status: LocationStatus.idle,
      );

    } catch (e) {

      state = state.copyWith(
        status: LocationStatus.error,
        error: e.toString(),
      );

      rethrow;
    }
  }

  // ---------------- DISPOSE ----------------

  @override
  void dispose() {

    _pingTimer?.cancel();

    super.dispose();
  }
}