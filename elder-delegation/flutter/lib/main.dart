import 'package:flutter/material.dart';

import 'delegation/entry.dart';

// 「家人代辦」微服務。建置成 Web 後由台北通 App 的 webview 開啟：
//   flutter build web
// 開發時直接用 Chrome 跑會出現「開發測試模式」，可選模擬的台北通帳號。
void main() => runApp(const FamilyHelpApp());
