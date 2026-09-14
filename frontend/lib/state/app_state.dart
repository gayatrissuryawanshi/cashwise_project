import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// Single source of truth for the signed-in user and the most recently
/// analyzed business.
class AppState extends ChangeNotifier {
  AppState({ApiService? api}) : api = api ?? ApiService();

  final ApiService api;

  // ============================================================
  // AUTH
  // ============================================================

  String? token;
  String? userName;
  String? userEmail;

  bool get isAuthenticated => token != null;

  // ============================================================
  // REQUEST STATUS
  // ============================================================

  bool isBusy = false;
  String? errorMessage;

  // ============================================================
  // CURRENT ANALYSIS
  // ============================================================

  int? analysisId;

  Map<String, dynamic>? business;
  Map<String, dynamic>? cashBreakdown;

  List<dynamic> obligations = [];

  Map<String, dynamic>? recommendation;

  List<dynamic>? salesForecast;
  List<dynamic>? udharPredictions;
  List<dynamic>? cashForecast;

  List<dynamic> mlNotes = [];

  // ============================================================
  // SIMULATION
  // ============================================================

  Map<String, dynamic>? baselineSimulation;
  Map<String, dynamic>? lastSpendCheck;
  Map<String, dynamic>? lastSimulation;

  // ============================================================
  // HISTORY
  // ============================================================

  List<dynamic> history = [];

  bool get hasAnalysis =>
      analysisId != null && recommendation != null;

  // ============================================================
  // DERIVED GETTERS
  // ============================================================

  String get businessName {
    final name = business?['business_name'];

    if (name is String && name.trim().isNotEmpty) {
      return name;
    }

    return 'Your Business';
  }

  num get currentCash {
    return _numValue(cashBreakdown?['cash']);
  }

  num get totalObligationsAmount {
    return _numValue(
      cashBreakdown?['total_obligations'],
    );
  }

  num get reserve {
    return _numValue(
      cashBreakdown?['reserve'],
    );
  }

  num get riskBuffer {
    return _numValue(
      cashBreakdown?['risk_buffer'],
    );
  }

  num get requiredReserve {
    return reserve + riskBuffer;
  }

  num get safeToDeploy {
    return _numValue(
      recommendation?['safe_to_deploy'],
    );
  }

  num get totalAllocated {
    return _numValue(
      recommendation?['total_allocated'],
    );
  }

  num get remainingCash {
    return _numValue(
      recommendation?['remaining_cash'],
    );
  }

  String get riskLevel {
    final value = recommendation?['risk_level'];

    if (value is String && value.isNotEmpty) {
      return value;
    }

    return 'LOW';
  }

  Map<String, dynamic> get recommendedAllocation {
    final value =
        recommendation?['recommended_allocation'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  Map<String, dynamic> get why {
    final value = recommendation?['why'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  List<String> get allocationReasons {
    final value = why['allocation_reasons'];

    if (value is List) {
      return value
          .map((e) => e.toString())
          .toList();
    }

    return [];
  }

  String get headline {
    final value = why['headline'];

    return value is String ? value : '';
  }

  String get riskNote {
    final value = why['risk_note'];

    return value is String ? value : '';
  }

  String get fragilityNote {
    final value =
        recommendation?['fragility']?['explanation'];

    return value is String ? value : '';
  }

  // ============================================================
  // RECEIVABLE RISK
  // ============================================================

  Map<String, dynamic> get receivablesRisk {
    final value =
        recommendation?['receivables_risk'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  num get receivablesFaceValue {
    return _numValue(
      receivablesRisk['total_face_value'],
    );
  }

  num get receivablesRiskAdjusted {
    return _numValue(
      receivablesRisk['total_risk_adjusted'],
    );
  }

  num get receivablesAtRisk {
    return _numValue(
      receivablesRisk['at_risk_amount'],
    );
  }

  List<dynamic> get receivablesBreakdown {
    final value =
        receivablesRisk['receivables'];

    if (value is List) {
      return List<dynamic>.from(value);
    }

    return [];
  }

  // ============================================================
  // FORECAST / SIMULATION GETTERS
  // ============================================================

  num get lowestProjectedCash {
    final value =
        baselineSimulation?['minimum_projected_cash'];

    if (value != null) {
      return _numValue(value);
    }

    return currentCash;
  }

  int get lowestProjectedCashDay {
    final value =
        baselineSimulation?['minimum_at_day'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  List<dynamic> get baselineTimeline {
    final value =
        baselineSimulation?['timeline'];

    if (value is List) {
      return List<dynamic>.from(value);
    }

    return [];
  }

  // ============================================================
  // HELPERS
  // ============================================================

  num _numValue(dynamic value) {
    if (value is num) {
      return value;
    }

    if (value is String) {
      return num.tryParse(value) ?? 0;
    }

    return 0;
  }

  void _setBusy(bool value) {
    isBusy = value;
    notifyListeners();
  }

  String _errorFrom(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map &&
          data['detail'] != null) {
        return data['detail'].toString();
      }

      return error.message ??
          'Network error. Check the server address.';
    }

    return error.toString();
  }

  // ============================================================
  // AUTH
  // ============================================================

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    _setBusy(true);
    errorMessage = null;

    try {
      await api.signup(
        name: name,
        email: email,
        password: password,
      );

      return await login(
        email: email,
        password: password,
      );
    } catch (e) {
      errorMessage = _errorFrom(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setBusy(true);
    errorMessage = null;

    try {
      final res = await api.login(
        email: email,
        password: password,
      );

      token = res.data['access_token'] as String;
      userEmail = email;

      // These are optional background refreshes.
      await loadLatest(silent: true);
      await loadHistory(silent: true);

      return true;
    } catch (e) {
      errorMessage = _errorFrom(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  void logout() {
    token = null;
    userEmail = null;
    userName = null;

    analysisId = null;
    business = null;
    cashBreakdown = null;
    obligations = [];
    recommendation = null;

    salesForecast = null;
    udharPredictions = null;
    cashForecast = null;
    mlNotes = [];

    baselineSimulation = null;
    lastSpendCheck = null;
    lastSimulation = null;

    history = [];

    errorMessage = null;

    notifyListeners();
  }

  // ============================================================
  // ANALYZE EXCEL
  // ============================================================

  Future<bool> uploadAndAnalyze({
    required String filename,
    String? filePath,
    Uint8List? bytes,
  }) async {
    if (token == null) {
      errorMessage = 'Please login again.';
      return false;
    }

    _setBusy(true);
    errorMessage = null;

    try {
      // ----------------------------------------------------------
      // STEP 1: Upload Excel + run backend analysis
      // ----------------------------------------------------------

      final res = await api.analyze(
        token: token!,
        filename: filename,
        filePath: filePath,
        bytes: bytes,
      );

      // ----------------------------------------------------------
      // STEP 2: Store backend result immediately
      // ----------------------------------------------------------

      final data =
          (res.data as Map).cast<String, dynamic>();

      _applyAnalysisPayload(data);

      // ----------------------------------------------------------
      // IMPORTANT:
      //
      // Do NOT wait for /simulate or /analyses here.
      //
      // The /analyze response already contains the recommendation.
      // The upload screen can therefore move to 100% immediately.
      // ----------------------------------------------------------

      _refreshBaselineSimulation();

      loadHistory(silent: true);

      return true;
    } catch (e) {
      errorMessage = _errorFrom(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // ============================================================
  // APPLY /ANALYZE RESPONSE
  // ============================================================

  void _applyAnalysisPayload(
    Map<String, dynamic> data,
  ) {
    analysisId = _intValue(
      data['analysis_id'],
    );

    final businessData = data['business'];

    if (businessData is Map) {
      business =
          Map<String, dynamic>.from(businessData);
    } else {
      business = null;
    }

    final cashData =
        data['cash_breakdown'];

    if (cashData is Map) {
      cashBreakdown =
          Map<String, dynamic>.from(cashData);
    } else {
      cashBreakdown = null;
    }

    final obligationsData =
        data['obligations'];

    if (obligationsData is List) {
      obligations =
          List<dynamic>.from(obligationsData);
    } else {
      obligations = [];
    }

    final recommendationData =
        data['recommendation'];

    if (recommendationData is Map) {
      recommendation =
          Map<String, dynamic>.from(
        recommendationData,
      );
    } else {
      recommendation = null;
    }

    final salesData =
        data['sales_forecast'];

    salesForecast = salesData is List
        ? List<dynamic>.from(salesData)
        : null;

    final udharData =
        data['udhar_predictions'];

    udharPredictions = udharData is List
        ? List<dynamic>.from(udharData)
        : null;

    final cashForecastData =
        data['cash_forecast'];

    cashForecast = cashForecastData is List
        ? List<dynamic>.from(cashForecastData)
        : null;

    final notes =
        data['ml_notes'];

    mlNotes = notes is List
        ? List<dynamic>.from(notes)
        : [];

    notifyListeners();
  }

  // ============================================================
  // LATEST ANALYSIS
  // ============================================================

  Future<bool> loadLatest({
    bool silent = false,
  }) async {
    if (token == null) return false;

    if (!silent) {
      _setBusy(true);
    }

    try {
      final res =
          await api.getLatestAnalysis(token!);

      final data =
          (res.data as Map).cast<String, dynamic>();

      _applyAnalysisDetail(data);

      // Background request.
      _refreshBaselineSimulation();

      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        errorMessage = _errorFrom(e);
      }

      return false;
    } catch (e) {
      errorMessage = _errorFrom(e);
      return false;
    } finally {
      if (!silent) {
        _setBusy(false);
      }
    }
  }

  // ============================================================
  // LOAD SPECIFIC ANALYSIS
  // ============================================================

  Future<bool> loadAnalysis(
    int id,
  ) async {
    if (token == null) return false;

    _setBusy(true);
    errorMessage = null;

    try {
      final res =
          await api.getAnalysis(
        id,
        token!,
      );

      final data =
          (res.data as Map).cast<String, dynamic>();

      _applyAnalysisDetail(data);

      _refreshBaselineSimulation();

      return true;
    } catch (e) {
      errorMessage = _errorFrom(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // ============================================================
  // APPLY ANALYSIS DETAIL
  // ============================================================

  void _applyAnalysisDetail(
    Map<String, dynamic> data,
  ) {
    analysisId = _intValue(
      data['analysis_id'],
    );

    business = {
      'business_name':
          data['business_name'],
      'business_type':
          data['business_type'],
      'location':
          data['location'],
      'reporting_date':
          data['reporting_date'],
      'monthly_sales':
          data['monthly_sales'],
      'monthly_expenses':
          data['monthly_expenses'],
    };

    final recommendationData =
        data['recommendation'];

    if (recommendationData is Map) {
      recommendation =
          Map<String, dynamic>.from(
        recommendationData,
      );
    } else {
      recommendation = null;
    }

    final salesData =
        data['sales_forecast'];

    salesForecast = salesData is List
        ? List<dynamic>.from(salesData)
        : null;

    final udharData =
        data['udhar_predictions'];

    udharPredictions = udharData is List
        ? List<dynamic>.from(udharData)
        : null;

    final cashData =
        data['cash_forecast'];

    cashForecast = cashData is List
        ? List<dynamic>.from(cashData)
        : null;

    final notes =
        data['ml_notes'];

    mlNotes = notes is List
        ? List<dynamic>.from(notes)
        : [];

    // Derive cash from recommendation.
    cashBreakdown = {
      'cash':
          remainingCash + totalAllocated,
      'total_obligations':
          0,
      'reserve':
          0,
      'risk_buffer':
          0,
    };

    notifyListeners();
  }

  // ============================================================
  // BASELINE SIMULATION
  // ============================================================

  Future<void> _refreshBaselineSimulation() async {
    if (analysisId == null ||
        token == null) {
      return;
    }

    try {
      final res = await api.simulate(
        analysisId: analysisId!,
        proposedAmount: 0,
        token: token!,
      );

      final data =
          (res.data as Map).cast<String, dynamic>();

      baselineSimulation = data;

      notifyListeners();
    } catch (_) {
      // Non-critical.
      // The dashboard/forecast can work without this.
    }
  }

  // ============================================================
  // HISTORY
  // ============================================================

  Future<void> loadHistory({
    bool silent = false,
  }) async {
    if (token == null) return;

    try {
      final res =
          await api.listAnalyses(token!);

      final data = res.data;

      if (data is List) {
        history =
            List<dynamic>.from(data);
      } else {
        history = [];
      }

      notifyListeners();
    } catch (e) {
      if (!silent) {
        errorMessage = _errorFrom(e);
      }
    }
  }

  // ============================================================
  // WHAT-IF: CHECK SPEND
  // ============================================================

  Future<Map<String, dynamic>?> checkSpend(
    num amount,
  ) async {
    if (analysisId == null ||
        token == null) {
      return null;
    }

    _setBusy(true);
    errorMessage = null;

    try {
      final res =
          await api.evaluateSpend(
        analysisId: analysisId!,
        proposedAmount: amount,
        token: token!,
      );

      final data =
          (res.data as Map).cast<String, dynamic>();

      lastSpendCheck = data;

      notifyListeners();

      return lastSpendCheck;
    } catch (e) {
      errorMessage = _errorFrom(e);
      return null;
    } finally {
      _setBusy(false);
    }
  }

  // ============================================================
  // WHAT-IF: SIMULATION
  // ============================================================

  Future<Map<String, dynamic>?> runSimulation(
    num amount, {
    int horizonDays = 30,
  }) async {
    if (analysisId == null ||
        token == null) {
      return null;
    }

    _setBusy(true);
    errorMessage = null;

    try {
      final res =
          await api.simulate(
        analysisId: analysisId!,
        proposedAmount: amount,
        token: token!,
        horizonDays: horizonDays,
      );

      final data =
          (res.data as Map).cast<String, dynamic>();

      lastSimulation = data;

      notifyListeners();

      return lastSimulation;
    } catch (e) {
      errorMessage = _errorFrom(e);
      return null;
    } finally {
      _setBusy(false);
    }
  }

  // ============================================================
  // INTEGER HELPER
  // ============================================================

  int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }
}