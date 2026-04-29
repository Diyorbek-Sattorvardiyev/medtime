import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/$'), '');

  static const defaultBaseUrl = String.fromEnvironment(
    'https://medtime-u0es.onrender.com',
    defaultValue: 'https://medtime-u0es.onrender.com',
  );

  static const _secureStorage = FlutterSecureStorage();
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userIdKey = 'auth_user_id';

  final http.Client _client;
  final String _baseUrl;

  Future<RegisterResult> register({
    required String fullName,
    required String email,
    required String password,
    required String avatarUrl,
  }) async {
    final json = await _post(
      '/api/auth/register',
      body: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'avatar_url': avatarUrl,
      },
    );
    final data = _dataMap(json);
    return RegisterResult(
      userId: data['user_id']?.toString(),
      verificationCode: data['verification_code']?.toString(),
      message: _message(json),
    );
  }

  Future<AuthSession> verifyEmail({
    required String email,
    required String code,
  }) async {
    final json = await _post(
      '/api/auth/verify-email',
      body: {'email': email, 'code': code},
    );
    return _saveSession(AuthSession.fromJson(_dataMap(json)));
  }

  Future<CodeResult> resendCode({required String email}) async {
    final json = await _post('/api/auth/resend-code', body: {'email': email});
    return CodeResult.fromJson(_dataMap(json), _message(json));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    return _saveSession(AuthSession.fromJson(_dataMap(json)));
  }

  Future<AuthSession> googleLogin({required String idToken}) async {
    final json = await _post('/api/auth/google', body: {'id_token': idToken});
    return _saveSession(AuthSession.fromJson(_dataMap(json)));
  }

  Future<AuthSession> refresh({String? refreshToken}) async {
    final token = refreshToken ?? await storedRefreshToken();
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Refresh token topilmadi',
        kind: AuthApiErrorKind.unauthorized,
      );
    }
    final json = await _post(
      '/api/auth/refresh',
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _dataMap(json);
    data.putIfAbsent('refresh_token', () => token);
    return _saveSession(AuthSession.fromJson(data));
  }

  Future<void> logout({String? refreshToken}) async {
    final token = refreshToken ?? await storedRefreshToken();
    try {
      if (token != null && token.isNotEmpty) {
        await _post(
          '/api/auth/logout',
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } finally {
      await clearSession();
    }
  }

  Future<CodeResult> forgotPassword({required String email}) async {
    final json = await _post(
      '/api/auth/forgot-password',
      body: {'email': email},
    );
    return CodeResult.fromJson(_dataMap(json), _message(json));
  }

  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final json = await _post(
      '/api/auth/reset-password',
      body: {'email': email, 'code': code, 'new_password': newPassword},
    );
    return _message(json);
  }

  Future<String?> storedUserId() async {
    return _secureStorage.read(key: _userIdKey);
  }

  Future<String?> storedAccessToken() async {
    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> storedRefreshToken() async {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> clearSession() async {
    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
      _secureStorage.delete(key: _userIdKey),
    ]);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          if (body != null) 'Content-Type': 'application/json',
          ...?headers,
        },
        body: body == null ? null : jsonEncode(body),
      );

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      final success = decoded['success'] != false && response.statusCode < 400;
      if (!success) {
        throw AuthApiException(
          _message(decoded),
          statusCode: response.statusCode,
          kind: _kindFor(response.statusCode),
        );
      }
      return decoded;
    } on AuthApiException {
      rethrow;
    } on SocketException {
      throw AuthApiException(
        'Serverga ulanib bolmadi: ${uri.host}:${uri.port}. Backend ishlayotganini va telefon shu tarmoqdan kira olishini tekshiring.',
        kind: AuthApiErrorKind.network,
      );
    } on http.ClientException catch (error) {
      throw AuthApiException(
        'Serverga ulanishda xatolik: ${error.message}',
        kind: AuthApiErrorKind.server,
      );
    } on FormatException {
      throw const AuthApiException('Server notogri JSON response qaytardi');
    }
  }

  Future<AuthSession> _saveSession(AuthSession session) async {
    await _secureStorage.write(
      key: _accessTokenKey,
      value: session.accessToken,
    );
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: session.refreshToken,
    );
    if (session.userId != null) {
      await _secureStorage.write(key: _userIdKey, value: session.userId!);
    }
    return session;
  }

  static Map<String, dynamic> _dataMap(Map<String, dynamic> json) {
    final data = json['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  static String _message(Map<String, dynamic> json) {
    return messageFrom(json);
  }

  static String messageFrom(Map<String, dynamic> json) {
    final message = json['message'];
    return message is String && message.isNotEmpty ? message : 'OK';
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
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    this.userId,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token']?.toString();
    final refreshToken = json['refresh_token']?.toString();
    if (accessToken == null || refreshToken == null) {
      throw const AuthApiException('Token response notogri');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: json['user_id']?.toString(),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String? userId;
}

class RegisterResult {
  const RegisterResult({
    required this.message,
    this.userId,
    this.verificationCode,
  });

  final String message;
  final String? userId;
  final String? verificationCode;
}

class CodeResult {
  const CodeResult({required this.message, this.code});

  factory CodeResult.fromJson(Map<String, dynamic> json, String message) {
    return CodeResult(
      message: message,
      code: (json['verification_code'] ?? json['code'])?.toString(),
    );
  }

  final String message;
  final String? code;
}

class AuthApiException implements Exception {
  const AuthApiException(
    this.message, {
    this.statusCode,
    this.kind = AuthApiErrorKind.unknown,
  });

  final String message;
  final int? statusCode;
  final AuthApiErrorKind kind;

  String get userMessage {
    return switch (kind) {
      AuthApiErrorKind.network =>
        'Internet yoki server bilan aloqa yo‘q. Ulanishni tekshirib qayta urinib ko‘ring.',
      AuthApiErrorKind.unauthorized =>
        'Sessiya muddati tugagan. Iltimos, qayta kiring.',
      AuthApiErrorKind.validation => message,
      AuthApiErrorKind.server =>
        'Serverda xatolik yuz berdi. Birozdan keyin qayta urinib ko‘ring.',
      AuthApiErrorKind.unknown => message,
    };
  }

  @override
  String toString() => message;
}

enum AuthApiErrorKind { network, unauthorized, validation, server, unknown }
