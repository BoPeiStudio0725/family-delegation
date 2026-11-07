/// 網頁版的語音：直接呼叫 index.html 裡的 window.__elderSpeech（每句話各自回報開始/結束）。
/// 手機 App 版沒有這個橋，改用 flutter_tts。
library;

export 'speech_bridge_stub.dart' if (dart.library.js_interop) 'speech_bridge_web.dart';
