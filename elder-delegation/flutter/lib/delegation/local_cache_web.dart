import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _storage {
  try {
    return globalContext.getProperty<JSObject?>('localStorage'.toJS);
  } catch (_) {
    return null; // 無痕模式等情況可能拿不到
  }
}

String? cacheRead(String key) {
  try {
    return _storage?.callMethod<JSString?>('getItem'.toJS, key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

void cacheWrite(String key, String value) {
  try {
    _storage?.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
  } catch (_) {}
}
