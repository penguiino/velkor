import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/location_controller.dart';

final locationControllerProvider =
StateNotifierProvider<
    LocationController,
    LocationState>(
      (ref) => throw UnimplementedError(),
);

class LocationSharingPage
    extends ConsumerStatefulWidget {

  const LocationSharingPage({
    super.key,
  });

  @override
  ConsumerState<LocationSharingPage>
  createState() =>
      _LocationSharingPageState();
}

class _LocationSharingPageState
    extends ConsumerState<
        LocationSharingPage> {

  final workerIdController =
  TextEditingController(
    text: "",
  );

  Timer? _timer;

  Duration elapsed =
      Duration.zero;

  DateTime? startedAt;

  @override
  void initState() {
    super.initState();

    workerIdController.addListener(() {
      setState(() {});
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (startedAt != null) {
          setState(() {
            elapsed = DateTime.now()
                .difference(startedAt!);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    workerIdController.dispose();
    super.dispose();
  }

  String _formatDuration(
      Duration d,
      ) {

    final hours =
    d.inHours
        .toString()
        .padLeft(2, '0');

    final minutes =
    (d.inMinutes % 60)
        .toString()
        .padLeft(2, '0');

    final seconds =
    (d.inSeconds % 60)
        .toString()
        .padLeft(2, '0');

    return "$hours:$minutes:$seconds";
  }

  Color _statusColor(
      LocationStatus status,
      ) {

    switch (status) {

      case LocationStatus.active:
        return Colors.green;

      case LocationStatus.idle:
        return Colors.orange;

      case LocationStatus.loading:
        return Colors.blue;

      case LocationStatus.error:
        return Colors.red;
    }
  }

  String _statusText(
      LocationStatus status,
      ) {

    switch (status) {

      case LocationStatus.active:
        return "ACTIVE";

      case LocationStatus.idle:
        return "IDLE";

      case LocationStatus.loading:
        return "LOADING";

      case LocationStatus.error:
        return "ERROR";
    }
  }

  IconData _statusIcon(
      LocationStatus status,
      ) {

    switch (status) {

      case LocationStatus.active:
        return Icons.location_on;

      case LocationStatus.idle:
        return Icons.pause_circle;

      case LocationStatus.loading:
        return Icons.sync;

      case LocationStatus.error:
        return Icons.error;
    }
  }

  Future<void> _handleAction(
      LocationController controller,
      LocationState state,
      ) async {

    FocusScope.of(context).unfocus();

    try {

      if (state.status ==
          LocationStatus.active) {

        await controller.endJob();

        setState(() {
          startedAt = null;
          elapsed = Duration.zero;
        });

      } else {

        await controller.startJob(
          workerIdController.text,
        );

        setState(() {
          startedAt = DateTime.now();
        });
      }

    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {

    final state = ref.watch(
      locationControllerProvider,
    );

    final controller = ref.read(
      locationControllerProvider
          .notifier,
    );

    final statusColor =
    _statusColor(state.status);

    final isLoading =
        state.status ==
            LocationStatus.loading;

    final isActive =
        state.status ==
            LocationStatus.active;

    final workerId =
    workerIdController.text.trim();

    return Scaffold(
      backgroundColor:
      const Color(0xFF0B1220),

      appBar: AppBar(
        title: const Text(
          "Traki",
        ),

        centerTitle: true,

        backgroundColor:
        const Color(0xFF111827),
      ),

      body: SafeArea(
        child: Center(
          child:
          SingleChildScrollView(
            padding:
            const EdgeInsets.all(
              20,
            ),

            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 420,
              ),

              child: Card(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    24,
                  ),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,

                    children: [

                      // STATUS ICON

                      Icon(
                        _statusIcon(
                          state.status,
                        ),
                        size: 56,
                        color: statusColor,
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      Text(
                        _statusText(
                          state.status,
                        ),

                        textAlign:
                        TextAlign.center,

                        style: TextStyle(
                          fontSize: 24,
                          fontWeight:
                          FontWeight.bold,
                          color:
                          statusColor,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Text(
                        isActive
                            ? "Tracking active"
                            : "Tracking inactive",

                        textAlign:
                        TextAlign.center,

                        style:
                        const TextStyle(
                          color:
                          Colors.white70,
                        ),
                      ),

                      const SizedBox(
                        height: 30,
                      ),

                      // TIMER

                      Container(
                        padding:
                        const EdgeInsets
                            .all(20),

                        decoration:
                        BoxDecoration(
                          color:
                          const Color(
                            0xFF1F2937,
                          ),

                          borderRadius:
                          BorderRadius
                              .circular(
                            18,
                          ),
                        ),

                        child: Column(
                          children: [

                            const Text(
                              "SESSION TIMER",

                              style:
                              TextStyle(
                                fontSize:
                                12,
                                color: Colors
                                    .white54,
                                letterSpacing:
                                1.2,
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            Text(
                              _formatDuration(
                                elapsed,
                              ),

                              style:
                              const TextStyle(
                                fontSize:
                                38,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // WORKER ID

                      TextField(
                        controller:
                        workerIdController,

                        enabled:
                        !isActive &&
                            !isLoading,

                        style:
                        const TextStyle(
                          color:
                          Colors.white,
                        ),

                        decoration:
                        const InputDecoration(
                          labelText:
                          "Worker ID",

                          hintText:
                          "Enter worker ID",

                          prefixIcon:
                          Icon(
                            Icons.badge,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // JOB ID

                      if (state.jobId !=
                          null)
                        Container(
                          padding:
                          const EdgeInsets
                              .all(14),

                          decoration:
                          BoxDecoration(
                            color:
                            const Color(
                              0xFF1F2937,
                            ),

                            borderRadius:
                            BorderRadius
                                .circular(
                              14,
                            ),
                          ),

                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [

                              const Text(
                                "Current Job ID",

                                style:
                                TextStyle(
                                  fontSize:
                                  12,
                                  color: Colors
                                      .white54,
                                ),
                              ),

                              const SizedBox(
                                height: 6,
                              ),

                              SelectableText(
                                state.jobId!,

                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (state.jobId !=
                          null)
                        const SizedBox(
                          height: 20,
                        ),

                      // BUTTON

                      SizedBox(
                        height: 54,

                        child:
                        ElevatedButton
                            .icon(

                          onPressed:
                          isLoading ||
                              (!isActive &&
                                  workerId
                                      .isEmpty)
                              ? null
                              : () =>
                              _handleAction(
                                controller,
                                state,
                              ),

                          icon: Icon(
                            isActive
                                ? Icons.stop
                                : Icons
                                .play_arrow,
                          ),

                          label: Text(
                            isActive
                                ? "End Job"
                                : "Start Job",
                          ),
                        ),
                      ),

                      if (isLoading) ...[
                        const SizedBox(
                          height: 24,
                        ),

                        const Center(
                          child:
                          CircularProgressIndicator(),
                        ),
                      ],

                      if (state.error !=
                          null &&
                          state.error!
                              .isNotEmpty) ...[

                        const SizedBox(
                          height: 20,
                        ),

                        Container(
                          padding:
                          const EdgeInsets
                              .all(14),

                          decoration:
                          BoxDecoration(
                            color: Colors.red
                                .withValues(
                              alpha: 0.12,
                            ),

                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),

                          child: Text(
                            state.error!,

                            textAlign:
                            TextAlign.center,

                            style:
                            const TextStyle(
                              color:
                              Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}