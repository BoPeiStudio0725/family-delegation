import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'speech_bridge.dart';
import 'townpass/townpass_bridge.dart';

/// 語音朗讀（裝置內建的語音引擎，不呼叫雲端 API、不是 LLM）。
///
/// 設計：預設安靜，等長輩自己要聽才說。
/// 1. 一進長者介面馬上說一句「點擊右上角喇叭圖案可聆聽介面功能說明」
///    （在台北通裡由台北通用手機原生語音唸，不用等長輩碰畫面）
/// 2. 右上角按鈕：靜音時是喇叭圖示，按一下唸這頁的說明，說話時變成音波（錄音）圖示；
///    說話中再按一下就停止，變回喇叭（正在說進入提示時按，則直接改唸說明）
/// 3. 只有右上角喇叭會出聲（長按按鈕、點卡片都不唸）
///
/// 圖示規則：每一句話有自己的編號，只有「目前這一句」結束才變回喇叭，
/// 被新句子打斷的舊句子回報結束時不會影響圖示。
class Speaker {
  Speaker._();

  static final Speaker instance = Speaker._();

  final FlutterTts _tts = FlutterTts();

  /// 語音開關。
  final ValueNotifier<bool> enabled = ValueNotifier(true);

  /// 正在出聲（喇叭按鈕會變成音波圖示）。
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  /// 目前在說的是進入時的提示（這時按喇叭要唸說明，不是停止）。
  bool get hintPlaying => _hintSeq == _seq && speaking.value;

  bool get _useWeb => kIsWeb && webSpeechAvailable;

  /// 在台北通 App 裡：請台北通用手機原生語音唸（一打開頁面就能出聲，不用先碰畫面）。
  /// 舊版台北通沒有這個功能（_townPassOk 變成 false），就改回網頁語音。
  bool? _townPassOk;
  bool _listening = false;

  bool get _useTownPass => isInsideTownPass && _townPassOk != false;

  void _listenTownPass() {
    if (_listening) return;
    _listening = true;
    listenTownPassSpeech((id, event) {
      if (_townPassOk == false) webStop(); // 已經改用網頁語音了，避免兩邊一起唸
      _townPassOk = true;
      if (event == 'start') {
        _started(id);
        if (_hintSeq == id) _armGuard(id, _hintText);
      } else {
        _ended(id);
      }
    });
  }

  String _hintText = '';

  /// 送給台北通唸；2.5 秒內台北通都沒回應（舊版台北通），改用網頁語音再唸一次。
  void _townPassSay(int id, String text, void Function() fallback) {
    _listenTownPass();
    townPassSpeak(id, text);
    if (_townPassOk == true) return;
    Timer(const Duration(milliseconds: 2500), () {
      if (_townPassOk != null || _seq != id) return;
      _townPassOk = false;
      townPassStopSpeaking();
      fallback();
    });
  }

  Future<void>? _init;

  Future<void> _ensureInit() => _init ??= _doInit();

  Future<void> _doInit() async {
    try {
      await _tts.setLanguage('zh-TW');
      // 長輩聽的速度要慢一點。Web 的 1.0 是正常速度；手機的 0.5 是正常速度。
      await _tts.setSpeechRate(kIsWeb ? 0.8 : 0.42);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      // speak() 等到唸完才回來，用來把圖示變回喇叭
      await _tts.awaitSpeakCompletion(true);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // iPhone 靜音開關打開時也要能出聲
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
        );
      }
    } catch (_) {
      // 語音失敗不能讓 App 壞掉，畫面照常可以用
    }
  }

  int _seq = 0;
  int _hintSeq = -1;
  Timer? _guard;

  void _started(int id) {
    if (_seq == id) speaking.value = true;
  }

  void _ended(int id) {
    if (_seq != id) return; // 已經換成別句話了，不要動圖示
    _guard?.cancel();
    speaking.value = false;
  }

  /// 保險：有些手機不會回報「唸完了」，依字數估計時間（抓寬一點），時間到就變回喇叭
  void _armGuard(int id, String text) {
    _guard?.cancel();
    _guard = Timer(Duration(milliseconds: 4000 + text.length * 600), () => _ended(id));
  }

  /// 一進頁面就要說的話（進入長者介面的提示）。
  /// 等真的開始出聲才換成音波圖示；iPhone 若擋住「沒碰過畫面就出聲」，改成第一次碰畫面時唸。
  void sayOnEntry(String text) {
    if (!enabled.value || text.trim().isEmpty) return;
    final id = ++_seq;
    _hintSeq = id;
    _guard?.cancel();
    speaking.value = false;
    _hintText = text;
    void web() => webSayOnEntry(text, onStart: () {
          _started(id);
          _armGuard(id, text);
        }, onEnd: () => _ended(id));
    if (_useTownPass) {
      _townPassSay(id, text, web);
      return;
    }
    if (_useWeb) {
      web();
      return;
    }
    _nativeSay(id, text);
  }

  /// 唸一段話（會先打斷正在唸的）。說話時圖示是音波，唸完變回喇叭。
  void say(String text) {
    if (!enabled.value || text.trim().isEmpty) return;
    final id = ++_seq;
    speaking.value = true; // 立刻換成音波圖示
    _armGuard(id, text);
    if (_useTownPass) {
      _townPassSay(id, text, () => webSay(text, onStart: () => _started(id), onEnd: () => _ended(id)));
      return;
    }
    if (_useWeb) {
      // 同步呼叫，iPhone 才算是在長輩按下按鈕時出聲
      webSay(text, onStart: () => _started(id), onEnd: () => _ended(id));
      return;
    }
    _nativeSay(id, text);
  }

  Future<void> _nativeSay(int id, String text) async {
    await _ensureInit();
    if (_seq != id) return;
    try {
      await _tts.stop();
      if (_seq != id) return;
      _started(id);
      _armGuard(id, text);
      await _tts.speak(text); // awaitSpeakCompletion：唸完才回來
    } catch (_) {}
    _ended(id);
  }

  Future<void> stop() async {
    _seq++;
    _guard?.cancel();
    speaking.value = false;
    if (_useTownPass) townPassStopSpeaking();
    if (_useWeb) {
      webStop();
      return;
    }
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void toggle() {
    enabled.value = !enabled.value;
    if (enabled.value) {
      say('語音打開了');
    } else {
      stop();
    }
  }
}

final speaker = Speaker.instance;

/// "123456" → 「一，二，三，四，五，六」，避免被念成「十二萬三千…」。
String spellDigits(String digits) {
  const zh = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  return digits.split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : zh[d];
  }).join('，');
}

/// 11月7日，下午2點3分
String speakTime(DateTime? d) {
  if (d == null) return '';
  final period = d.hour < 12 ? '上午' : '下午';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute == 0 ? '' : '${d.minute}分';
  return '${d.month}月${d.day}日，$period$h12點$minute';
}

/// 每個授權範圍給長輩聽的白話說明（比畫面上的字更完整）。
String speakScope(String code, String fallbackLabel) {
  switch (code) {
    case 'VIEW_INFO':
      return '讓他看您的基本資料，和敬老卡點數';
    case 'BOOK_SERVICE':
      return '讓他幫您報名社區關懷據點的活動';
    default:
      return fallbackLabel;
  }
}
