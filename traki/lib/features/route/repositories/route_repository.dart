import '../../../core/network/http_service.dart';
import '../models/route_model.dart';

class RouteRepository {
  final HttpService httpService;

  RouteRepository(this.httpService);

  /// Returns null if the worker has no route assigned today (server 404).
  Future<RouteModel?> getTodayRoute(String token) async {
    try {
      final data = await httpService.get('/worker/routes/today', token: token);
      return RouteModel.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<RouteModel> startRoute(String token, String routeId) async {
    final data = await httpService.post(
      '/worker/routes/$routeId/start',
      {},
      token: token,
    );

    return RouteModel.fromJson(data);
  }

  /// Sends a GPS ping. The server determines arrival/departure and
  /// returns the updated route state directly, so the app doesn't need
  /// a second round trip to refresh.
  Future<RouteModel?> ping({
    required String token,
    required String routeId,
    required double lat,
    required double lng,
  }) async {
    final data = await httpService.post(
      '/worker/routes/$routeId/ping',
      {'lat': lat, 'lng': lng},
      token: token,
    );

    if (data['ignored'] == true || data['route'] == null) {
      return null;
    }

    return RouteModel.fromJson(data['route'] as Map<String, dynamic>);
  }

  Future<void> manualArrive({
    required String token,
    required String routeId,
    required String stopId,
  }) async {
    await httpService.post(
      '/worker/routes/$routeId/stops/$stopId/arrive',
      {},
      token: token,
    );
  }

  Future<void> manualDepart({
    required String token,
    required String routeId,
    required String stopId,
  }) async {
    await httpService.post(
      '/worker/routes/$routeId/stops/$stopId/depart',
      {},
      token: token,
    );
  }
}
