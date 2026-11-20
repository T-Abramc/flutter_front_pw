import 'dart:convert';
import 'package:flutter_front_pw/Models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'HTTP $statusCode: $message';
}

class ApiClient {
  static const String _tokenStorageKey = 'zai_jwt_token';

  String _baseUrl;
  String? _accessToken;

  ApiClient({String baseUrl = 'https://localhost:44343'})
      : _baseUrl = _normalizeUrl(baseUrl);

  String get baseUrl => _baseUrl;

  set baseUrl(String value) {
    _baseUrl = _normalizeUrl(value);
  }

  static String _normalizeUrl(String url) {
    var clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.startsWith('http://') && clean.contains(':443')) {
      clean = clean.replaceFirst('http://', 'https://');
    }
    return clean;
  }

  bool get isLoggedIn => _accessToken != null && _accessToken!.isNotEmpty;
  String? get currentToken => _accessToken;

  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenStorageKey);
  }

  Map<String, String> _headers({bool jsonBody = false}) {
    final map = <String, String>{'Accept': 'application/json'};
    if (jsonBody) map['Content-Type'] = 'application/json';
    if (isLoggedIn) {
      map['Authorization'] = 'Bearer $_accessToken';
    }
    return map;
  }

  void _checkError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String msg = res.body;
    if (res.body.isNotEmpty) {
      try {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
            final firstErr = (data['errors'] as List).first;
            if (firstErr is Map && firstErr['message'] != null) {
              msg = '${data['title'] ?? 'Błąd'}: ${firstErr['message']}';
            } else {
              msg = data['detail'] ?? data['title'] ?? res.body;
            }
          } else {
            msg = data['detail'] ?? data['title'] ?? res.body;
          }
        }
      } catch (_) {}
    }
    throw ApiException(res.statusCode, msg);
  }

  Future<String> checkHealth() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/health'),
      headers: _headers(),
    );
    _checkError(res);
    return 'Status ${res.statusCode}: ${res.body}';
  }

  Future<LoginResponse> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({'username': username, 'password': password}),
    );
    _checkError(res);
    final loginRes = LoginResponse.fromJson(jsonDecode(res.body));
    _accessToken = loginRes.accessToken;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, _accessToken!);
    return loginRes;
  }

  Future<int> logout() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/auth/logout'),
        headers: _headers(),
      );
      _checkError(res);
      return res.statusCode;
    } finally {
      _accessToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenStorageKey);
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/auth/password'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    _checkError(res);
  }

  Future<List<Series>> getSeries() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/series'),
      headers: _headers(),
    );
    _checkError(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Series.fromJson(e)).toList();
  }

  Future<Series> createSeries(Series series) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/series'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(series.toInputJson()),
    );
    _checkError(res);
    return Series.fromJson(jsonDecode(res.body));
  }

  Future<Series> updateSeries(String id, Series series) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/series/$id'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(series.toInputJson()),
    );
    _checkError(res);
    return Series.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteSeries(String id) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/series/$id'),
      headers: _headers(),
    );
    _checkError(res);
  }

  Future<List<Measurement>> getMeasurements({
    List<String>? seriesIds,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{
      'limit': '1000',
      'sort': 'timestamp',
    };
    if (seriesIds != null && seriesIds.isNotEmpty) {
      query['series'] = seriesIds.join(',');
    }
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();

    final uri = Uri.parse('$_baseUrl/api/measurements').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers());
    _checkError(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Measurement.fromJson(e)).toList();
  }

  Future<List<Sensor>> getSensors() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/sensors'),
      headers: _headers(),
    );
    _checkError(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Sensor.fromJson(e)).toList();
  }

  Future<Sensor> createSensor(String name, String seriesId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/sensors'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({'name': name, 'seriesId': seriesId}),
    );
    _checkError(res);
    return Sensor.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteSensor(String id) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/sensors/$id'),
      headers: _headers(),
    );
    _checkError(res);
  }
}