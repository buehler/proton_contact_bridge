import 'package:dio/dio.dart';

final class ProtonContacts {
  const ProtonContacts(this._dio);

  final Dio _dio;

  Future<void> testContextFetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'contacts/v4',
        queryParameters: {'Page': 0, 'PageSize': 5},
      );

      final data = response.data;

      print(data);
    } catch (e) {
      print('Error fetching contacts: $e');
    }
  }
}
