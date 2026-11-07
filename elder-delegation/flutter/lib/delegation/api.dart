import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:http/http.dart' as http;

import 'models.dart';
import 'townpass/townpass_account.dart';

/// 後端回傳的錯誤。message 是可以直接顯示給使用者的中文。
class ApiError implements Exception {
  final int status;
  final String code;
  final String message;

  ApiError(this.status, this.code, this.message);

  /// 403：沒有授權 / 授權已收回 / 範圍不足
  bool get isForbidden => status == 403;

  @override
  String toString() => message;
}

class DelegationApi {
  /// 後端位址，可用 --dart-define=API_BASE=... 覆寫：
  /// - Android 模擬器：http://10.0.2.2:8080/api
  /// - iOS 模擬器 / Flutter Web：http://localhost:8080/api
  /// - 實機 Demo：筆電的區網 IP，例如 http://192.168.1.23:8080/api
  /// - 沒有設定時：Web 版自動用「網頁所在主機的 8080 port」（台北通 webview 開的網址同一台電腦）
  static String baseUrl = _defaultBaseUrl();

  static String _defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://${Uri.base.host}:8080/api';
    return 'http://10.0.2.2:8080/api';
  }

  /// 目前登入者。正式版改成台北通登入後的 token。
  final int userId;

  DelegationApi(this.userId);

  Map<String, String> get _headers => {
        'X-User-Id': '$userId',
        'Content-Type': 'application/json',
        // 後端透過 ngrok 對外時，略過 ngrok 免費版的警告頁（其他情況這個標頭沒有作用）
        'ngrok-skip-browser-warning': '1',
      };

  /// 網路不穩（例如會場 Wi-Fi 壅塞、ngrok 暫時斷線）時自動重試。
  /// 只有「重試也不會重複送出」的請求才重試：所有 GET、登入、標成已讀。
  /// 報名、確認、取消這類會改資料的請求不自動重試，避免重複送出。
  static const _retryDelays = [Duration(milliseconds: 700), Duration(milliseconds: 1500)];
  static const _timeout = Duration(seconds: 15);

  static bool _canRetry(String method, String path) =>
      method == 'GET' || path == '/auth/townpass' || path == '/notices/read';

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final retries = _canRetry(method, path) ? _retryDelays.length : 0;
    for (var attempt = 0;; attempt++) {
      try {
        return await _sendOnce(method, path, body);
      } on _Transient {
        if (attempt >= retries) {
          throw ApiError(0, 'NETWORK', '網路不穩定，連不到伺服器，請稍後再試');
        }
        await Future<void>.delayed(_retryDelays[attempt]);
      }
    }
  }

  Future<dynamic> _sendOnce(String method, String path, Object? body) async {
    final uri = Uri.parse('$baseUrl$path');
    http.Response res;
    try {
      final Future<http.Response> req;
      if (method == 'GET') {
        req = http.get(uri, headers: _headers);
      } else if (method == 'POST') {
        req = http.post(uri, headers: _headers, body: body == null ? null : jsonEncode(body));
      } else {
        req = http.delete(uri, headers: _headers);
      }
      res = await req.timeout(_timeout);
    } catch (_) {
      throw const _Transient(); // 連不上、逾時
    }
    // ngrok 暫時連不到這台電腦時會回 502 / 503 / 504 的錯誤網頁（不是 JSON）
    if (res.statusCode == 502 || res.statusCode == 503 || res.statusCode == 504) throw const _Transient();
    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      throw const _Transient();
    }
    if (res.statusCode >= 400) {
      final m = data is Map ? data : const {};
      throw ApiError(res.statusCode, '${m['code'] ?? 'ERROR'}', '${m['message'] ?? '發生錯誤（HTTP ${res.statusCode}），請再試一次'}');
    }
    return data;
  }


  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) f) =>
      (data as List).map((e) => f(e as Map<String, dynamic>)).toList();

  // ---------- 台北通登入 / 身分 ----------
  /// 用台北通帳號登入，回傳後端的使用者與身分（role 依綁定關係決定）。
  static Future<UserInfo> loginWithTownPass(TownPassAccount account) async {
    final data = await DelegationApi(0)._send('POST', '/auth/townpass', account.toLoginJson());
    lastLoginJson = data as Map<String, dynamic>;
    return UserInfo.fromJson(data);
  }

  /// 最近一次登入的原始回應（存到手機，下次打開先顯示）。
  static Map<String, dynamic>? lastLoginJson;

  Future<UserInfo> me() async => UserInfo.fromJson(await _send('GET', '/me') as Map<String, dynamic>);

  /// 選擇身分頁：ELDER / FAMILY
  Future<UserInfo> chooseRole(String role) async =>
      UserInfo.fromJson(await _send('POST', '/me/role', {'role': role}) as Map<String, dynamic>);

  /// 選錯了重選（沒有任何綁定才可以）
  Future<UserInfo> resetRole() async =>
      UserInfo.fromJson(await _send('POST', '/me/reset-role') as Map<String, dynamic>);

  // ---------- 授權流程 ----------
  Future<List<ScopeInfo>> scopes() async => _list(await _send('GET', '/scopes'), ScopeInfo.fromJson);

  Future<Invitation> createInvitation() async =>
      Invitation.fromJson(await _send('POST', '/invitations') as Map<String, dynamic>);

  Future<Delegation> acceptInvitation(String code) async =>
      Delegation.fromJson(await _send('POST', '/invitations/accept', {'code': code}) as Map<String, dynamic>);

  Future<List<Delegation>> myDelegations() async => _list(await _send('GET', '/delegations'), Delegation.fromJson);

  Future<List<Delegation>> pendingDelegations() async =>
      _list(await _send('GET', '/delegations/pending'), Delegation.fromJson);

  Future<Delegation> approve(int id, Set<String> scopes, int days) async => Delegation.fromJson(
      await _send('POST', '/delegations/$id/approve', {'scopes': scopes.toList(), 'days': days})
          as Map<String, dynamic>);

  Future<Delegation> reject(int id) async =>
      Delegation.fromJson(await _send('POST', '/delegations/$id/reject') as Map<String, dynamic>);

  Future<Delegation> revoke(int id) async =>
      Delegation.fromJson(await _send('POST', '/delegations/$id/revoke') as Map<String, dynamic>);

  // ---------- 代辦服務（長者本人或有授權的家屬） ----------
  Future<ElderProfile> elderProfile(int elderId) async =>
      ElderProfile.fromJson(await _send('GET', '/elders/$elderId/profile') as Map<String, dynamic>);

  Future<List<BookingInfo>> bookings(int elderId) async =>
      _list(await _send('GET', '/elders/$elderId/bookings'), BookingInfo.fromJson);

  Future<BookingInfo> createBooking(int elderId, int servicePointId) async => BookingInfo.fromJson(
      await _send('POST', '/elders/$elderId/bookings', {'servicePointId': servicePointId}) as Map<String, dynamic>);

  /// 報名活動場次（後端會檢查長輩年齡是否適合）。
  Future<BookingInfo> bookActivity(int elderId, int activityId) async => BookingInfo.fromJson(
      await _send('POST', '/elders/$elderId/bookings', {'activityId': activityId}) as Map<String, dynamic>);

  /// 依長輩年齡篩選的活動；category = HEALTH / LEARNING / LEISURE / MEAL / SOCIAL，district = 行政區。
  Future<ActivityList> activities(int elderId, {String? category, String? district}) async {
    final q = <String, String>{
      if (category != null) 'category': category,
      if (district != null) 'district': district,
    };
    final qs = q.isEmpty ? '' : '?${Uri(queryParameters: q).query}';
    return ActivityList.fromJson(await _send('GET', '/elders/$elderId/activities$qs') as Map<String, dynamic>);
  }

  /// 長輩確認家屬代為報名的活動（只有長輩本人可以）。
  Future<BookingInfo> confirmBooking(int elderId, int bookingId) async => BookingInfo.fromJson(
      await _send('POST', '/elders/$elderId/bookings/$bookingId/confirm') as Map<String, dynamic>);

  /// 長輩自己取消報名（只有長輩本人可以）。報名的家屬會收到通知。
  Future<BookingInfo> cancelBookingByElder(int elderId, int bookingId) async => BookingInfo.fromJson(
      await _send('POST', '/elders/$elderId/bookings/$bookingId/cancel') as Map<String, dynamic>);

  // ---------- 通知（家屬） ----------
  Future<List<NoticeInfo>> notices() async => _list(await _send('GET', '/notices'), NoticeInfo.fromJson);

  Future<void> markNoticesRead() async => _send('POST', '/notices/read');

  /// 自動更新：版本戳記（活動或授權有新動作時會改變）＋我的通知，一個請求拿完。
  Future<(String, List<NoticeInfo>)> sync() async {
    final m = await _send('GET', '/sync') as Map<String, dynamic>;
    final list = [for (final n in (m['notices'] as List? ?? const [])) NoticeInfo.fromJson(n as Map<String, dynamic>)];
    return ('${m['stamp']}', list);
  }

  Future<List<ActionLogEntry>> logs(int elderId) async =>
      _list(await _send('GET', '/elders/$elderId/logs'), ActionLogEntry.fromJson);

  // ---------- 開放資料 ----------
  Future<Map<String, int>> districts() async {
    final data = await _send('GET', '/service-points/districts') as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<List<ServicePoint>> servicePoints({String? district}) async {
    final q = district == null ? '' : '?district=${Uri.encodeQueryComponent(district)}';
    return _list(await _send('GET', '/service-points$q'), ServicePoint.fromJson);
  }
}

/// 暫時性的網路問題（可以重試）。
class _Transient implements Exception {
  const _Transient();
}
