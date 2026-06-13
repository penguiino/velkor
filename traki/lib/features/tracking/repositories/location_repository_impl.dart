
import '../../../../core/network/http_service.dart';

class LocationRepositoryImpl {
  final HttpService httpService;

  LocationRepositoryImpl(
      this.httpService,
      );

  // ---------------- START JOB ----------------

  Future<Map<String, dynamic>> startJob({
    required String workerId,
    required double lat,
    required double lng,
  }) async {
    final data = await httpService.post(
      '/start-job',
      {
        'workerId': workerId,
        'lat': lat,
        'lng': lng,
      },
    );

    final jobId = data['jobId'];

    if (jobId == null || jobId is! String) {
      throw Exception(
        'Invalid jobId response',
      );
    }

    return {
      'jobId': jobId,
      'alreadyActive':
      data['alreadyActive'] == true,
    };
  }

  // ---------------- SEND PING ----------------

  Future<void> sendPing({
    required String jobId,
    required double lat,
    required double lng,
  }) async {
    await httpService.post(
      '/job-ping',
      {
        'jobId': jobId,
        'lat': lat,
        'lng': lng,
      },
    );
  }

  // ---------------- END JOB ----------------

  Future<void> endJob({
    required String jobId,
    required double lat,
    required double lng,
  }) async {
    await httpService.post(
      '/end-job',
      {
        'jobId': jobId,
        'lat': lat,
        'lng': lng,
      },
    );
  }

  // ---------------- GET JOBS ----------------

  Future<List<dynamic>> getJobs({
    required String workerId,
  }) async {
    final encodedWorkerId =
    Uri.encodeComponent(workerId);

    return await httpService.getList(
      '/jobs?workerId=$encodedWorkerId',
    );
  }
}