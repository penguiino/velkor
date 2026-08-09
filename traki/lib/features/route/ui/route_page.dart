import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../main.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/route_controller.dart';
import '../models/route_model.dart';

class RoutePage extends ConsumerWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<RouteControllerState>(routeControllerProvider, (previous, next) {
      if (next.error != null &&
          next.status == RouteLoadStatus.ready &&
          next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), duration: const Duration(seconds: 3)),
        );
      }
    });

    final state = ref.watch(routeControllerProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(authState.workerName ?? 'Velkor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(routeControllerProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, RouteControllerState state) {
    switch (state.status) {
      case RouteLoadStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case RouteLoadStatus.error:
        return _ErrorView(
          message: state.error ?? 'Something went wrong',
          onRetry: () => ref.read(routeControllerProvider.notifier).refresh(),
        );

      case RouteLoadStatus.noRoute:
        return _NoRouteView(
          onRetry: () => ref.read(routeControllerProvider.notifier).refresh(),
        );

      case RouteLoadStatus.ready:
        final route = state.route;
        if (route == null) {
          return _NoRouteView(
            onRetry: () => ref.read(routeControllerProvider.notifier).refresh(),
          );
        }
        return _RouteView(route: route, actionInProgress: state.actionInProgress);
    }
  }
}

class _NoRouteView extends StatelessWidget {
  final VoidCallback onRetry;

  const _NoRouteView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 56, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text(
              'No route assigned for today',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back once your manager assigns one.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Check again')),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _RouteView extends ConsumerWidget {
  final RouteModel route;
  final bool actionInProgress;

  const _RouteView({required this.route, required this.actionInProgress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = route.totalStopCount == 0
        ? 0.0
        : route.completedStopCount / route.totalStopCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          route.name?.isNotEmpty == true ? route.name! : 'Today\'s Route',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(route.routeDate, style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 14),

        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${route.completedStopCount} of ${route.totalStopCount} stops completed',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 20),

        if (route.status == 'pending') _StartRouteCard(actionInProgress: actionInProgress),

        if (route.status == 'active' && route.currentStop != null) ...[
          _CurrentStopCard(stop: route.currentStop!, actionInProgress: actionInProgress),
          const SizedBox(height: 14),
        ],

        if (route.status == 'active' && route.currentStop == null) ...[
          const _AllStopsResolvedBanner(),
          const SizedBox(height: 14),
        ],

        if (route.nextStop != null) ...[
          _NextStopPreview(stop: route.nextStop!),
          const SizedBox(height: 14),
        ],

        if (route.status == 'completed') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent),
                SizedBox(width: 10),
                Text('Route complete — nice work!'),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        const Text('All Stops', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),

        ...route.stops.map((s) => _StopListTile(stop: s, isCurrent: s.id == route.currentStopId)),
      ],
    );
  }
}

class _StartRouteCard extends ConsumerWidget {
  final bool actionInProgress;

  const _StartRouteCard({required this.actionInProgress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Ready to head out?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: actionInProgress
                  ? null
                  : () => ref.read(routeControllerProvider.notifier).startRoute(),
              child: actionInProgress
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
                  : const Text('Start Route'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllStopsResolvedBanner extends StatelessWidget {
  const _AllStopsResolvedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Finishing up the route...'),
    );
  }
}

class _CurrentStopCard extends ConsumerWidget {
  final StopModel stop;
  final bool actionInProgress;

  const _CurrentStopCard({required this.stop, required this.actionInProgress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('CURRENT STOP', style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold)),
              const Spacer(),
              _StatusPill(status: stop.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(stop.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (stop.address != null && stop.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(stop.address!, style: TextStyle(color: Colors.grey.shade300)),
          ],
          if (stop.notes != null && stop.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(stop.notes!, style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openNavigation(stop),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Navigate'),
                ),
              ),
              const SizedBox(width: 10),
              if (stop.status == 'pending')
                Expanded(
                  child: ElevatedButton(
                    onPressed: actionInProgress
                        ? null
                        : () => ref.read(routeControllerProvider.notifier).manualArrive(stop.id),
                    child: const Text('Mark Arrived'),
                  ),
                ),
              if (stop.status == 'arrived')
                Expanded(
                  child: ElevatedButton(
                    onPressed: actionInProgress
                        ? null
                        : () => ref.read(routeControllerProvider.notifier).manualDepart(stop.id),
                    child: const Text('Mark Departed'),
                  ),
                ),
            ],
          ),
          if (stop.status == 'pending') ...[
            const SizedBox(height: 8),
            Text(
              'Arrival is detected automatically when you\'re close enough — use "Mark Arrived" only if GPS isn\'t picking it up.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openNavigation(StopModel stop) async {
    final label = Uri.encodeComponent(stop.customerName);
    final geoUri = Uri.parse('geo:${stop.lat},${stop.lng}?q=${stop.lat},${stop.lng}($label)');

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return;
    }

    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${stop.lat},${stop.lng}',
    );

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}

class _NextStopPreview extends StatelessWidget {
  final StopModel stop;

  const _NextStopPreview({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_forward, color: Colors.grey.shade500, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UP NEXT', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, letterSpacing: 1)),
                Text(stop.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopListTile extends StatelessWidget {
  final StopModel stop;
  final bool isCurrent;

  const _StopListTile({required this.stop, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.grey.shade800 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey.shade700,
            child: Text('${stop.orderIndex + 1}', style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(stop.customerName, overflow: TextOverflow.ellipsis),
          ),
          _StatusPill(status: stop.status),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  Color get _color {
    switch (status) {
      case 'arrived':
      case 'completed':
        return Colors.greenAccent;
      case 'skipped':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _color),
      ),
    );
  }
}
