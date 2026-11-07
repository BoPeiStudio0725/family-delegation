import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _bridge {
  try {
    return globalContext.getProperty<JSObject?>('__elderSpeech'.toJS);
  } catch (_) {
    return null;
  }
}

bool get webSpeechAvailable => _bridge != null;

void _call(String method, String text, void Function() onStart, void Function() onEnd) {
  try {
    _bridge?.callMethodVarArgs(method.toJS, [text.toJS, onStart.toJS, onEnd.toJS]);
  } catch (_) {
    onEnd();
  }
}

/// 同步呼叫（不能先 await），iPhone 才會把它算在「長輩按下按鈕」裡而允許出聲。
void webSay(String text, {required void Function() onStart, required void Function() onEnd}) =>
    _call('say', text, onStart, onEnd);

void webSayOnEntry(String text, {required void Function() onStart, required void Function() onEnd}) =>
    _call('sayOnEntry', text, onStart, onEnd);

void webStop() {
  try {
    _bridge?.callMethod('stop'.toJS);
  } catch (_) {}
}
