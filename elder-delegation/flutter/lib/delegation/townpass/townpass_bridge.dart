/// 從台北通 App 取得目前登入的帳號。
///
/// - 在台北通 App 的 webview 裡（Flutter Web）：透過台北通注入的 `flutterObject`
///   送出 {"name":"userinfo"}，台北通回傳 Account JSON（見台北通原始碼
///   lib/util/web_message_handler/tp_web_message_handler.dart 的 UserinfoWebMessageHandler）。
/// - 不在台北通裡（直接用 Chrome 開、或手機原生執行）：回傳 null，入口頁會改顯示模擬帳號讓開發者選。
library;

export 'townpass_bridge_stub.dart' if (dart.library.js_interop) 'townpass_bridge_web.dart';
