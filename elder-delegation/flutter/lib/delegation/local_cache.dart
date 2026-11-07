/// 手機上的小快取（網頁 localStorage）：記住上次登入時的首頁資料，
/// 下次打開「家人代辦」先顯示，背景再更新，不用等網路。
library;

export 'local_cache_stub.dart' if (dart.library.js_interop) 'local_cache_web.dart';
