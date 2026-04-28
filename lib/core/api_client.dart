import 'package:dio/dio.dart';

import 'auth_api.dart';

class ApiClient {
  ApiClient({Dio? dio, AuthApi? authApi, String? baseUrl})
    : _authApi = authApi ?? AuthApi(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: (baseUrl ?? AuthApi.defaultBaseUrl).replaceFirst(
                RegExp(r'/$'),
                '',
              ),
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {'Accept': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authApi.storedAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode == 401 &&
              request.extra['retried'] != true) {
            try {
              final session = await _authApi.refresh();
              request.extra['retried'] = true;
              request.headers['Authorization'] =
                  'Bearer ${session.accessToken}';
              handler.resolve(await _dio.fetch<dynamic>(request));
              return;
            } on AuthApiException {
              await _authApi.clearSession();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthApi _authApi;

  Future<Map<String, dynamic>> getProfile() => _request('GET', '/api/profile');

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String language,
    required bool darkMode,
  }) {
    return _request(
      'PUT',
      '/api/profile',
      body: {
        'full_name': fullName,
        'language': language,
        'dark_mode': darkMode,
      },
    );
  }

  Future<Map<String, dynamic>> updateNotificationSettings({
    required bool appNotificationsEnabled,
    required bool emailNotificationsEnabled,
    required bool telegramNotificationsEnabled,
  }) {
    return _request(
      'PUT',
      '/api/profile/notification-settings',
      body: {
        'app_notifications_enabled': appNotificationsEnabled,
        'email_notifications_enabled': emailNotificationsEnabled,
        'telegram_notifications_enabled': telegramNotificationsEnabled,
      },
    );
  }

  Future<Map<String, dynamic>> updateEmail(String email) {
    return _request('PUT', '/api/profile/email', body: {'email': email});
  }

  Future<List<Map<String, dynamic>>> getMedicines({
    bool? active,
    int? familyMemberId,
    String? search,
  }) async {
    final json = await _request(
      'GET',
      '/api/medicines',
      query: {
        if (active != null) 'active': active.toString(),
        if (familyMemberId != null) 'family_member_id': '$familyMemberId',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return _listData(json);
  }

  Future<Map<String, dynamic>> getMedicine(int medicineId) {
    return _request('GET', '/api/medicines/$medicineId').then(_dataMap);
  }

  Future<Map<String, dynamic>> createMedicine(Map<String, dynamic> body) {
    return _request('POST', '/api/medicines', body: body).then(_dataMap);
  }

  Future<Map<String, dynamic>> updateMedicine(
    int medicineId,
    Map<String, dynamic> body,
  ) {
    return _request(
      'PUT',
      '/api/medicines/$medicineId',
      body: body,
    ).then(_dataMap);
  }

  Future<void> deleteMedicine(int medicineId) async {
    await _request('DELETE', '/api/medicines/$medicineId');
  }

  Future<Map<String, dynamic>> markTaken({
    required int medicineId,
    required int scheduleId,
    required String plannedAt,
  }) {
    return _medicineAction(
      medicineId,
      'mark-taken',
      scheduleId: scheduleId,
      plannedAt: plannedAt,
    );
  }

  Future<Map<String, dynamic>> markMissed({
    required int medicineId,
    required int scheduleId,
    required String plannedAt,
  }) {
    return _medicineAction(
      medicineId,
      'mark-missed',
      scheduleId: scheduleId,
      plannedAt: plannedAt,
    );
  }

  Future<Map<String, dynamic>> snooze({
    required int medicineId,
    required int scheduleId,
    required String plannedAt,
    required int minutes,
  }) {
    return _medicineAction(
      medicineId,
      'snooze',
      scheduleId: scheduleId,
      plannedAt: plannedAt,
      minutes: minutes,
    );
  }

  Future<int> syncMedicineActions(List<Map<String, dynamic>> actions) async {
    if (actions.isEmpty) return 0;
    final json = await _request(
      'POST',
      '/api/medicines/actions/bulk',
      body: {'actions': actions},
    );
    final data = _dataMap(json);
    final processed = data['processed'];
    if (processed is int) return processed;
    return int.tryParse(processed?.toString() ?? '') ?? 0;
  }

  Future<Map<String, dynamic>> getTodayDashboard() {
    return _request('GET', '/api/dashboard/today').then(_dataMap);
  }

  Future<Map<String, dynamic>> getCalendarMonth(String month) {
    return _request(
      'GET',
      '/api/calendar',
      query: {'month': month},
    ).then(_dataMap);
  }

  Future<Map<String, dynamic>> getCalendarDay(String date) {
    return _request(
      'GET',
      '/api/calendar/day',
      query: {'date': date},
    ).then(_dataMap);
  }

  Future<List<Map<String, dynamic>>> getHistory({
    String? date,
    int? medicineId,
    int? familyMemberId,
    String? status,
  }) async {
    final query = <String, String>{};
    if (date != null) query['date'] = date;
    if (medicineId != null) query['medicine_id'] = '$medicineId';
    if (familyMemberId != null) {
      query['family_member_id'] = '$familyMemberId';
    }
    if (status != null) query['status'] = status;

    final json = await _request('GET', '/api/history', query: query);
    return _listData(json);
  }

  Future<Map<String, dynamic>> getStatistics({required int period}) {
    return _request(
      'GET',
      '/api/statistics',
      query: {'period': '$period'},
    ).then(_dataMap);
  }

  Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    return _listData(await _request('GET', '/api/family-members'));
  }

  Future<Map<String, dynamic>> getFamilyMember(int memberId) {
    return _request('GET', '/api/family-members/$memberId').then(_dataMap);
  }

  Future<Map<String, dynamic>> createFamilyMember({
    required String fullName,
    required String relationship,
    required String avatarColor,
  }) {
    return _request(
      'POST',
      '/api/family-members',
      body: {
        'full_name': fullName,
        'relationship': relationship,
        'avatar_color': avatarColor,
      },
    ).then(_dataMap);
  }

  Future<Map<String, dynamic>> updateFamilyMember({
    required int memberId,
    required String fullName,
    required String relationship,
    required String avatarColor,
  }) {
    return _request(
      'PUT',
      '/api/family-members/$memberId',
      body: {
        'full_name': fullName,
        'relationship': relationship,
        'avatar_color': avatarColor,
      },
    ).then(_dataMap);
  }

  Future<void> deleteFamilyMember(int memberId) async {
    await _request('DELETE', '/api/family-members/$memberId');
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    return _listData(await _request('GET', '/api/notifications'));
  }

  Future<Map<String, dynamic>> getTelegramConnectLink() {
    return _request('GET', '/api/telegram/connect-link').then(_dataMap);
  }

  Future<Map<String, dynamic>> getTelegramConnectStatus(String code) {
    return _request(
      'GET',
      '/api/telegram/connect-status',
      query: {'code': code},
    ).then(_dataMap);
  }

  Future<void> disconnectTelegram() async {
    await _request('DELETE', '/api/telegram/disconnect');
  }

  Future<Map<String, dynamic>> _medicineAction(
    int medicineId,
    String action, {
    required int scheduleId,
    required String plannedAt,
    int? minutes,
  }) {
    final body = <String, dynamic>{
      'schedule_id': scheduleId,
      'planned_at': plannedAt,
    };
    if (minutes != null) body['minutes'] = minutes;

    return _request(
      'POST',
      '/api/medicines/$medicineId/$action',
      body: body,
    ).then(_dataMap);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final token = await _authApi.storedAccessToken();
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Access token topilmadi',
        kind: AuthApiErrorKind.unauthorized,
      );
    }
    try {
      final response = await switch (method) {
        'GET' => _dio.get<dynamic>(path, queryParameters: query),
        'POST' => _dio.post<dynamic>(path, data: body, queryParameters: query),
        'PUT' => _dio.put<dynamic>(path, data: body, queryParameters: query),
        'DELETE' => _dio.delete<dynamic>(
          path,
          data: body,
          queryParameters: query,
        ),
        _ => throw AuthApiException('HTTP method notogri: $method'),
      };
      return _decodeData(response.data, response.statusCode ?? 200);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const AuthApiException(
          'Internet yoki server bilan aloqa yo‘q. Tarmoqni tekshirib qayta urinib ko‘ring.',
          kind: AuthApiErrorKind.network,
        );
      }
      final response = error.response;
      if (response != null) {
        return _decodeData(response.data, response.statusCode ?? 500);
      }
      throw AuthApiException(
        'Serverga ulanishda xatolik: ${error.message}',
        kind: AuthApiErrorKind.server,
      );
    } on AuthApiException {
      rethrow;
    } catch (error) {
      throw AuthApiException('Kutilmagan xatolik: $error');
    }
  }

  Map<String, dynamic> _decodeData(Object? raw, int statusCode) {
    final decoded = switch (raw) {
      Map<String, dynamic>() => raw,
      Map() => Map<String, dynamic>.from(raw),
      null => <String, dynamic>{},
      _ => throw const AuthApiException(
        'Server notogri JSON response qaytardi',
      ),
    };
    final success = decoded['success'] != false && statusCode < 400;
    if (!success) {
      throw AuthApiException(
        AuthApi.messageFrom(decoded),
        statusCode: statusCode,
        kind: _kindFor(statusCode),
      );
    }
    return decoded;
  }

  static AuthApiErrorKind _kindFor(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return AuthApiErrorKind.unauthorized;
    }
    if (statusCode == 400 || statusCode == 422) {
      return AuthApiErrorKind.validation;
    }
    if (statusCode >= 500) return AuthApiErrorKind.server;
    return AuthApiErrorKind.unknown;
  }

  static Map<String, dynamic> _dataMap(Map<String, dynamic> json) {
    final data = json['data'];
    return data is Map<String, dynamic> ? data : json;
  }

  static List<Map<String, dynamic>> _listData(Map<String, dynamic> json) {
    final data = json['data'];
    final items = switch (data) {
      List<dynamic>() => data,
      {'items': final List<dynamic> items} => items,
      {'medicines': final List<dynamic> items} => items,
      {'family_members': final List<dynamic> items} => items,
      {'notifications': final List<dynamic> items} => items,
      {'history': final List<dynamic> items} => items,
      _ => const <dynamic>[],
    };
    return items.whereType<Map<String, dynamic>>().toList();
  }
}
