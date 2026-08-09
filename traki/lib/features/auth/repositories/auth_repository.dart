import '../../../core/network/http_service.dart';

class AuthRepository {
  final HttpService httpService;

  AuthRepository(this.httpService);

  Future<Map<String, dynamic>> login({
    required String workerCode,
    required String pin,
  }) async {
    final data = await httpService.post('/auth/worker/login', {
      'workerCode': workerCode,
      'pin': pin,
    });

    final token = data['token'];
    final worker = data['worker'];

    if (token is! String || worker is! Map) {
      throw Exception('Invalid login response');
    }

    return {
      'token': token,
      'workerId': worker['id'],
      'workerCode': worker['workerCode'],
      'workerName': worker['name'],
    };
  }
}
