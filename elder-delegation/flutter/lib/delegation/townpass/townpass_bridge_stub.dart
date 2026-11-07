import 'townpass_account.dart';

/// 非 Web 平台：沒有台北通 JS bridge。
Future<TownPassAccount?> fetchTownPassAccount({Duration timeout = const Duration(seconds: 3)}) async => null;

bool get isInsideTownPass => false;

void sendTownPassNotification({required String title, required String content}) {}

void townPassSpeak(int id, String text) {}

void townPassStopSpeaking() {}

void listenTownPassSpeech(void Function(int id, String event) onEvent) {}
