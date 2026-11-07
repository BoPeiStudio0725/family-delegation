import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'townpass_account.dart';

/// 台北通 App 在 webview 裡注入的物件（flutter_inappwebview 的 WebMessageListener，jsObjectName = 'flutterObject'）。
@JS('flutterObject')
external JSObject? get _flutterObject;

bool get isInsideTownPass => _flutterObject != null;

/// 請台北通跳出手機通知（台北通的 NotifyMessageHandler，name = 'notify'）。
/// 不在台北通裡就什麼都不做。
void sendTownPassNotification({required String title, required String content}) {
  final bridge = _flutterObject;
  if (bridge == null) return;
  bridge.callMethod<JSAny?>(
    'postMessage'.toJS,
    jsonEncode({
      'name': 'notify',
      'data': {'title': title, 'content': content},
    }).toJS,
  );
}

/// 送出 {"name":"userinfo","data":null}，等台北通回傳 {"name":"userinfo","data":{...Account}}。
Future<TownPassAccount?> fetchTownPassAccount({Duration timeout = const Duration(seconds: 3)}) async {
  final bridge = _flutterObject;
  if (bridge == null) return null;

  final completer = Completer<TownPassAccount?>();

  final JSFunction listener = ((JSAny? event) {
    if (completer.isCompleted || event == null) return;
    try {
      final raw = (event as JSObject).getProperty<JSAny?>('data'.toJS).dartify();
      final Object? decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map || decoded['name'] != 'userinfo') return;
      final data = decoded['data'];
      if (data is Map && data['id'] != null) {
        completer.complete(TownPassAccount.fromJson(Map<String, dynamic>.from(data)));
      } else {
        completer.complete(null); // 台北通沒有登入帳號
      }
    } catch (_) {
      // 不是我們要的訊息，忽略
    }
  }).toJS;

  bridge.callMethod<JSAny?>('addEventListener'.toJS, 'message'.toJS, listener);
  bridge.callMethod<JSAny?>('postMessage'.toJS, jsonEncode({'name': 'userinfo', 'data': null}).toJS);

  try {
    return await completer.future.timeout(timeout, onTimeout: () => null);
  } finally {
    bridge.callMethod<JSAny?>('removeEventListener'.toJS, 'message'.toJS, listener);
  }
}

/// 請台北通用手機內建語音唸（台北通的 SpeakMessageHandler，name = 'speak'）。
/// 一打開頁面就能出聲，不受 iPhone「要先碰畫面」的限制。
void townPassSpeak(int id, String text) {
  _flutterObject?.callMethod<JSAny?>(
    'postMessage'.toJS,
    jsonEncode({
      'name': 'speak',
      'data': {'id': id, 'text': text},
    }).toJS,
  );
}

void townPassStopSpeaking() {
  _flutterObject?.callMethod<JSAny?>(
    'postMessage'.toJS,
    jsonEncode({
      'name': 'speak',
      'data': {'stop': true},
    }).toJS,
  );
}

bool _speechListening = false;

/// 台北通回報 {"name":"speak","data":{"id":1,"event":"start"|"end"}}。
void listenTownPassSpeech(void Function(int id, String event) onEvent) {
  final bridge = _flutterObject;
  if (bridge == null || _speechListening) return;
  _speechListening = true;
  final JSFunction listener = ((JSAny? event) {
    if (event == null) return;
    try {
      final raw = (event as JSObject).getProperty<JSAny?>('data'.toJS).dartify();
      final Object? decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map || decoded['name'] != 'speak') return;
      final data = decoded['data'];
      if (data is Map && data['id'] is num && data['event'] is String) {
        onEvent((data['id'] as num).toInt(), data['event'] as String);
      }
    } catch (_) {}
  }).toJS;
  bridge.callMethod<JSAny?>('addEventListener'.toJS, 'message'.toJS, listener);
}
