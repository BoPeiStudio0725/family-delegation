import 'package:flutter/material.dart';

import 'api.dart';
import 'elder_pages.dart';
import 'family_pages.dart';
import 'dart:convert';

import 'local_cache.dart';
import 'models.dart';
import 'notice_center.dart';
import 'speech.dart';
import 'tp_theme.dart';
import 'townpass/townpass_account.dart';
import 'townpass/townpass_bridge.dart';
import 'widgets.dart';

/// 台北通主色（TPColors.primary500）
const tpPrimary = TPColors.primary500;

/// 「親屬幫助」微服務入口。
///
/// 流程：
/// 1. 從台北通取得登入帳號（webview 的 flutterObject → userinfo）
/// 2. 用台北通帳號登入後端
/// 3. 後端依綁定關係回傳身分：
///    - ELDER  → 直接進長者介面
///    - FAMILY → 直接進家屬介面
///    - 還沒有 → 選擇身分頁（第一次使用）
class FamilyHelpApp extends StatelessWidget {
  const FamilyHelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家人代辦',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: buildTownPassTheme(),
      home: const HelpEntryPage(),
    );
  }
}

/// 依身分開啟對應首頁（取代目前頁面，返回鍵不會回到入口）。
void openHomeFor(BuildContext context, DelegationApi api, UserInfo me) {
  final nav = context.mounted ? Navigator.of(context) : appNavigatorKey.currentState;
  if (nav != null) _openHome(nav, api, me);
}

void _openHome(NavigatorState nav, DelegationApi api, UserInfo me) {
  // 長輩、家屬都開始檢查通知（新通知會從上方跳出來）
  if (me.isElder || me.isFamily) {
    NoticeCenter.instance.start(api, isElder: me.isElder, home: me.home);
  } else {
    NoticeCenter.instance.stop();
  }
  final Widget page;
  if (me.isElder) {
    page = ElderScale(child: ElderHomePage(api: api, me: me));
  } else if (me.isFamily) {
    page = FamilyHomePage(api: api, me: me);
  } else {
    page = RoleChoicePage(api: api, me: me);
  }
  nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);
}

// =====================================================================
// 入口：讀台北通帳號 → 登入 → 依身分分流
// =====================================================================
class HelpEntryPage extends StatefulWidget {
  const HelpEntryPage({super.key});

  @override
  State<HelpEntryPage> createState() => _HelpEntryPageState();
}

class _HelpEntryPageState extends State<HelpEntryPage> {
  String _status = '正在確認您的台北通身分…';
  Object? _error;
  bool _showDemoPicker = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _showDemoPicker = false;
      _status = '正在確認您的台北通身分…';
    });
    final account = await fetchTownPassAccount();
    if (!mounted) return;
    if (account != null) {
      // 加速：手機上有上次的首頁資料就先顯示，背景再登入更新
      final cached = _readCache(account.id);
      if (cached != null) {
        openHomeFor(context, DelegationApi(cached.id), cached);
        _refreshInBackground(account, cached);
        return;
      }
      await _login(account);
      return;
    }
    if (isInsideTownPass) {
      setState(() => _error = '沒有取得台北通帳號，請先登入台北通再打開「家人代辦」');
    } else {
      // 不在台北通 App 裡（開發測試用）：讓開發者選模擬帳號
      setState(() => _showDemoPicker = true);
    }
  }

  Future<void> _login(TownPassAccount account) async {
    setState(() {
      _error = null;
      _showDemoPicker = false;
      _status = '${account.realName} 您好，正在登入…';
    });
    // 網路不穩時：每次登入本身已重試 3 次；還是不行就再自動重連幾輪，最後才顯示錯誤
    const rounds = 3;
    for (var round = 1; ; round++) {
      try {
        final me = await DelegationApi.loginWithTownPass(account);
        _writeCache(account.id);
        if (!mounted) return;
        openHomeFor(context, DelegationApi(me.id), me);
        return;
      } on ApiError catch (e) {
        if (!mounted) return;
        if (e.code != 'NETWORK' || round >= rounds) {
          setState(() => _error = '$e\n（後端位址：${DelegationApi.baseUrl}）');
          return;
        }
        setState(() => _status = '網路不穩定，正在重新連線…（第 $round 次）');
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;
      } catch (e) {
        if (mounted) setState(() => _error = '$e\n（後端位址：${DelegationApi.baseUrl}）');
        return;
      }
    }
  }

  static String _cacheKey(String townpassId) => 'family-help:login:$townpassId';

  UserInfo? _readCache(String townpassId) {
    final raw = cacheRead(_cacheKey(townpassId));
    if (raw == null) return null;
    try {
      final me = UserInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return me.hasRole ? me : null; // 還沒有身分的不用快取
    } catch (_) {
      return null;
    }
  }

  void _writeCache(String townpassId) {
    final json = DelegationApi.lastLoginJson;
    if (json != null) cacheWrite(_cacheKey(townpassId), jsonEncode(json));
  }

  /// 背景重新登入：身分變了（例如在台北通改了生日）就換介面；沒變就讓頁面依最新資料更新。
  Future<void> _refreshInBackground(TownPassAccount account, UserInfo cached) async {
    try {
      final me = await DelegationApi.loginWithTownPass(account);
      _writeCache(account.id);
      final nav = appNavigatorKey.currentState;
      if (me.id != cached.id || me.role != cached.role) {
        if (nav != null) _openHome(nav, DelegationApi(me.id), me);
      } else {
        NoticeCenter.instance.refresh(); // 版本戳記和快取不同 → 開著的頁面自動重新整理
      }
    } catch (_) {
      // 網路暫時不通：先用快取的畫面，NoticeCenter 每 5 秒會再試
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('家人代辦')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _showDemoPicker ? _demoPicker() : _statusView(),
        ),
      ),
    );
  }

  Widget _statusView() {
    if (_error != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: TPColors.red500),
        const SizedBox(height: 12),
        Text('$_error', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: _start, child: const Text('重試')),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text(_status),
    ]);
  }

  Widget _demoPicker() {
    return ListView(
      shrinkWrap: true,
      children: [
        const Text('開發測試模式', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('目前不在台北通 App 裡，請選一個模擬的台北通帳號登入。\n'
            '在台北通裡打開時會自動使用登入中的帳號，不會出現這一頁。'),
        const SizedBox(height: 12),
        for (final a in demoTownPassAccounts)
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle, size: 36),
              title: Text(a.realName),
              subtitle: Text('生日 ${a.birthday}｜${a.district}'),
              onTap: () => _login(a),
            ),
          ),
      ],
    );
  }
}

// =====================================================================
// 第一次使用：選擇身分（依台北通生日給建議，但由使用者自己決定）
// =====================================================================
class RoleChoicePage extends StatefulWidget {
  final DelegationApi api;
  final UserInfo me;

  const RoleChoicePage({super.key, required this.api, required this.me});

  @override
  State<RoleChoicePage> createState() => _RoleChoicePageState();
}

class _RoleChoicePageState extends State<RoleChoicePage> {
  bool _busy = false;

  bool get _suggestElder => widget.me.suggestedRole == 'ELDER';

  @override
  void initState() {
    super.initState();
  }

  void _announce() {
    if (widget.me.isMinor) return;
    speaker.say('${widget.me.name}您好，第一次使用家人代辦。'
        '如果您是長輩，想讓家人幫您辦事，請按藍綠色的按鈕。'
        '如果您要幫家裡的長輩辦事，請按黑色的按鈕。');
  }

  Future<void> _choose(String role) async {
    setState(() => _busy = true);
    try {
      final me = await widget.api.chooseRole(role);
      if (!mounted) return;
      openHomeFor(context, widget.api, me);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String speakText,
  }) {
    final suggested = widget.me.suggestedRole == role;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _busy ? null : () => _choose(role),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Icon(icon, size: 56, color: TPColors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (suggested)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(8)),
                      child: Text('依台北通資料建議', style: TextStyle(color: color, fontSize: 13)),
                    ),
                  Text(title,
                      style: const TextStyle(color: TPColors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: TPColors.white, fontSize: 16)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elder = _card(
      role: 'ELDER',
      icon: Icons.elderly,
      title: '我是長輩',
      subtitle: '讓家人幫我辦事\n決定誰可以幫忙',
      color: ElderColors.teal,
      speakText: '藍綠色按鈕：我是長輩，想讓家人幫我辦事。',
    );
    final family = _card(
      role: 'FAMILY',
      icon: Icons.volunteer_activism,
      title: '我是家屬',
      subtitle: '幫長輩報名活動\n查看長輩的資料',
      color: ElderColors.dark,
      speakText: '黑色按鈕：我是家屬，要幫家裡的長輩辦事。',
    );
    // 未滿 18 歲：不能擔任家屬，也不是長者
    if (widget.me.isMinor) {
      return Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: const Text('家人代辦')),
        body: Center(
          child: EmptyState(
            icon: Icons.family_restroom,
            title: '${widget.me.name} 您好',
            message: '「家人代辦」需要年滿 18 歲才能擔任家屬，\n請由家中成年的家人使用台北通協助長輩。',
          ),
        ),
      );
    }
    return ElderScale(
      child: Scaffold(
        appBar: elderAppBar(context, title: '家人代辦', onListen: _announce),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('${widget.me.name} 您好', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('第一次使用，請選擇您的身分'),
            const SizedBox(height: 12),
            // 建議的身分排在前面
            ...(_suggestElder ? [elder, family] : [family, elder]),
            const SizedBox(height: 16),
            const Text(
              '和家人綁定之後，下次從台北通打開，會自動進入您的畫面。',
              style: TextStyle(color: TPColors.grayscale600),
            ),
          ],
        ),
      ),
    );
  }
}
