import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:town_pass/util/web_message_handler/tp_web_message_handler.dart';

/// 讓網頁型服務（例如「家人代辦」）用手機內建語音朗讀。
///
/// 網頁裡的 speechSynthesis 在 iPhone 上常被「要先碰畫面才能出聲」擋住，
/// 改由台北通 App 用原生語音（iOS AVSpeechSynthesizer）來唸，一打開頁面就能出聲。
///
/// 網頁送出：
/// - {"name":"speak","data":{"id":1,"text":"要唸的話"}}
/// - {"name":"speak","data":{"stop":true}}
/// 台北通回覆：{"name":"speak","data":{"id":1,"event":"start" | "end"}}
class SpeakMessageHandler extends TPWebMessageHandler {
  @override
  String get name => 'speak';

  final FlutterTts _tts = FlutterTts();
  Future<void>? _init;
  Function(WebMessage replyWebMessage)? _reply;

  /// 目前在唸的那一句（網頁給的編號）；被新句子取代的舊句子不回報。
  int? _currentId;
  bool _currentStarted = false;

  Future<void> _ensureInit() => _init ??= _doInit();

  Future<void> _doInit() async {
    try {
      await _tts.setLanguage('zh-TW');
      await _tts.setSpeechRate(0.42); // 長輩聽的速度慢一點（手機的 0.5 是正常速度）
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iPhone 靜音開關打開時也要能出聲
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
        );
      }
      _tts.setStartHandler(() {
        final id = _currentId;
        if (id == null) return;
        _currentStarted = true;
        _send(id, 'start');
      });
      // 被打斷（cancel）的是舊句子，不回報，避免把新句子的圖示改回喇叭
      _tts.setCompletionHandler(_finishCurrent);
      _tts.setErrorHandler((_) => _finishCurrent());
    } catch (_) {
      // 語音失敗不能讓 App 壞掉
    }
  }

  void _finishCurrent() {
    final id = _currentId;
    if (id == null || !_currentStarted) return;
    _currentId = null;
    _currentStarted = false;
    _send(id, 'end');
  }

  void _send(int id, String event) {
    try {
      _reply?.call(replyWebMessage(data: {'id': id, 'event': event}));
    } catch (_) {}
  }

  @override
  Future<void> handle({
    required Object? message,
    required WebUri? sourceOrigin,
    required bool isMainFrame,
    required Function(WebMessage replyWebMessage)? onReply,
  }) async {
    if (message is! Map) return;
    _reply = onReply ?? _reply;
    await _ensureInit();

    if (message['stop'] == true) {
      _currentId = null;
      _currentStarted = false;
      try {
        await _tts.stop();
      } catch (_) {}
      return;
    }

    final text = message['text'];
    final id = message['id'];
    if (text is! String || text.trim().isEmpty || id is! num) return;
    _currentId = id.toInt();
    _currentStarted = false;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      _send(id.toInt(), 'end');
    }
  }
}
