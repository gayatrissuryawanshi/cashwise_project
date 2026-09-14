import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Talks to the real CashFlow Engine FastAPI backend (see
/// cashflow-engine/merged/main.py). The frontend previously targeted a
/// placeholder contract (/dashboard/{id}, /udhaar/{id}, /upload-excel, ...)
/// that the backend never implemented - this now matches the actual
/// endpoints the backend exposes.
///
/// IMPORTANT: change [baseUrl] to wherever `uvicorn main:app` is running.
/// - Android emulator talking to a backend on the SAME machine: 10.0.2.2
/// - Physical phone / iOS simulator: your computer's LAN IP (e.g. 192.168.x.x)
/// - Do not use 127.0.0.1 on a physical device - it points at the phone itself.
class ApiService {
  ApiService({String? baseUrl})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl ??
              'https://kept-rebecca-russia-jay.trycloudflare.com',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  final Dio dio;

  void updateBaseUrl(String baseUrl) {
    dio.options.baseUrl = baseUrl;
  }

  Options _authHeader(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  // ==========================================
  // AUTH
  // ==========================================

  Future<Response> signup({
    required String name,
    required String email,
    required String password,
  }) =>
      dio.post('/signup', data: {
        'name': name,
        'email': email,
        'password': password,
      });

  Future<Response> login({
    required String email,
    required String password,
  }) =>
      dio.post('/login', data: {
        'email': email,
        'password': password,
      });

  // ==========================================
  // ANALYZE - upload an Excel workbook
  // ==========================================

  /// Uploads the workbook and runs the full ML-adjusted decision-engine
  /// pipeline. Provide either [filePath] (mobile/desktop, where file_picker
  /// returns a real path) or [bytes] (web, where file_picker only returns
  /// bytes in memory).
  Future<Response> analyze({
    required String token,
    required String filename,
    String? filePath,
    Uint8List? bytes,
  }) async {
    assert(filePath != null || bytes != null,
        'analyze() needs either a filePath or bytes');

    final multipartFile = filePath != null
        ? await MultipartFile.fromFile(filePath, filename: filename)
        : MultipartFile.fromBytes(bytes!, filename: filename);

    final formData = FormData.fromMap({'file': multipartFile});

    return dio.post(
      '/analyze',
      data: formData,
      options: _authHeader(token),
    );
  }

  // ==========================================
  // HISTORY
  // ==========================================

  Future<Response> listAnalyses(String token) =>
      dio.get('/analyses', options: _authHeader(token));

  Future<Response> getAnalysis(int analysisId, String token) =>
      dio.get('/analyses/$analysisId', options: _authHeader(token));

  Future<Response> getLatestAnalysis(String token) =>
      dio.get('/analyses/latest', options: _authHeader(token));

  // ==========================================
  // RE-RUN "CAN I SPEND X?" / "WHAT IF I SPEND X?"
  // ==========================================

  Future<Response> evaluateSpend({
    required int analysisId,
    required num proposedAmount,
    required String token,
  }) =>
      dio.post(
        '/analyses/$analysisId/evaluate-spend',
        data: {'proposed_amount': proposedAmount},
        options: _authHeader(token),
      );

  Future<Response> simulate({
    required int analysisId,
    required num proposedAmount,
    required String token,
    int horizonDays = 30,
  }) =>
      dio.post(
        '/analyses/$analysisId/simulate',
        data: {
          'proposed_amount': proposedAmount,
          'horizon_days': horizonDays,
        },
        options: _authHeader(token),
      );
}
