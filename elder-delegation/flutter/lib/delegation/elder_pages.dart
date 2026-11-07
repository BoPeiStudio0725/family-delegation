import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'entry.dart';
import 'models.dart';
import 'notice_center.dart';
import 'speech.dart';
import 'tp_layout.dart';
import 'tp_theme.dart';
import 'widgets.dart';

// 長者端設計原則（預設長輩不太識字）：
// - 每頁打開自動唸：這頁是什麼、要按「什麼顏色」的按鈕
// - 按鈕用顏色＋大圖示區分，語音也用顏色指路
// - 長按按鈕 / 點勾選項 / 點紀錄 → 唸出來
// - 右上角固定黃色大喇叭：再聽一次

// 顏色全部取自台北通色票（見 tp_theme.dart 的 ElderColors），語音用顏色名稱指路
const _green = ElderColors.teal; // 唸「藍綠色」
const _red = ElderColors.red; // 唸「紅色」
const _grey = ElderColors.grey; // 唸「灰色」

IconData _scopeIcon(String code) {
  switch (code) {
    case 'VIEW_INFO':
      return Icons.badge;
    case 'BOOK_SERVICE':
      return Icons.event_available;
    default:
      return Icons.help_outline;
  }
}

// =====================================================================
// 長者首頁：三個不同顏色的大按鈕
// =====================================================================
class ElderHomePage extends StatefulWidget {
  final DelegationApi api;
  final UserInfo me;

  const ElderHomePage({super.key, required this.api, required this.me});

  @override
  State<ElderHomePage> createState() => _ElderHomePageState();
}

class _ElderHomePageState extends State<ElderHomePage> {
  List<Delegation> _pending = [];
  List<BookingInfo> _waitingBookings = [];
  int _bookedCount = 0;
  int _helperCount = 0;
  late UserInfo _me = widget.me;

  @override
  void initState() {
    super.initState();
    final home = widget.me.home;
    if (home != null) {
      // 登入時已經帶回首頁資料（或手機上的快取）：直接顯示，不用再等網路
      _pending = home.pending;
      _waitingBookings = home.bookings.where((b) => b.isPending).toList();
      _bookedCount = home.bookings.where((b) => b.isConfirmed).length;
      _helperCount = home.delegations.where((d) => d.isActive).length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _entryHint());
    } else {
      _refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) => _entryHint());
    }
    // 家人幫忙報名、確認或取消時（資料版本戳記改變）才重新整理首頁
    NoticeCenter.instance.changes.addListener(_refresh);
  }

  @override
  void dispose() {
    NoticeCenter.instance.changes.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        widget.api.pendingDelegations(),
        widget.api.me(),
        widget.api.bookings(widget.me.id),
        widget.api.myDelegations(),
      ]);
      if (!mounted) return;
      final bookings = results[2] as List<BookingInfo>;
      setState(() {
        _pending = results[0] as List<Delegation>;
        _me = results[1] as UserInfo;
        _waitingBookings = bookings.where((b) => b.isPending).toList();
        _bookedCount = bookings.where((b) => b.isConfirmed).length;
        _helperCount = (results[3] as List<Delegation>).where((d) => d.isActive).length;
      });
    } catch (_) {}
  }

  /// 一進長者介面只說這一句（每次打開家人代辦說一次），其他都等長輩自己按喇叭才說。
  static bool _hintSpoken = false;

  void _entryHint() {
    if (_hintSpoken) return;
    _hintSpoken = true;
    speaker.sayOnEntry('點擊右上角喇叭圖案可聆聽介面功能說明');
  }

  void _announce() {
    final b = StringBuffer('${_me.name}您好。');
    if (_pending.isNotEmpty) {
      b.write('${_pending.first.familyName}想幫您辦事，請按最上面黃色的框框。');
    }
    if (_waitingBookings.isNotEmpty) {
      b.write('家人幫您報名了${_waitingBookings.length}個活動，等您確認，請按黃色的框框。');
    }
    b.write('藍色的大按鈕，第一個是讓家人幫您辦事，第二個是看誰在幫您，第三個是聽家人幫您做過的事。');
    b.write('黃色的大按鈕，是看您報名了哪些活動。');
    b.write('最下面藍色的大按鈕，是適合您的活動推薦。');
    b.write('按住任何一個按鈕不放，可以聽它是做什麼的。');
    b.write('右上角黃色的喇叭，可以再聽一次。');
    speaker.say(b.toString());
  }

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ElderScale(child: page)));
    // 回來時不唸，避免打斷上一頁最後的提示（例如「您同意了…」）
    _refresh();
  }

  Future<void> _resetRole() async {
    final ok = await elderConfirm(context,
        title: '您不是長輩嗎？', message: '要重新選擇身分嗎？', okLabel: '重新選擇', okColor: _grey, icon: Icons.swap_horiz);
    if (!ok || !mounted) return;
    try {
      final me = await widget.api.resetRole();
      if (!mounted) return;
      openHomeFor(context, widget.api, me);
    } catch (e) {
      if (mounted) elderMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    return Scaffold(
      appBar: elderAppBar(context, title: '家人代辦', onListen: _announce),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          children: [
            // 參考設計稿：頭像＋大標題＋副標（年齡層、行政區）
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(children: [
                Avatar(_me.name, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_me.name} 您好', style: TPText.h2.copyWith(fontSize: 26)),
                    // 生日來自台北通（設定 › 基本資料），改了生日介面會依年齡自動切換
                    if (_me.birthday != null)
                      Text('生日 ${_me.birthday}',
                          style: TPText.body.copyWith(fontSize: 15, color: TPColors.grayscale500)),
                    if (_me.ageGroupLabel != null)
                      Text(
                        [
                          if (_me.age != null) '${_me.age} 歲',
                          _me.ageGroupLabel!.split('（').first,
                          if (_me.district != null) _me.district!
                        ].join('・'),
                        style: TPText.body.copyWith(fontSize: 15, color: TPColors.grayscale500),
                      ),
                  ]),
                ),
              ]),
            ),
            // 三格數字可以點進去看清單；長按會唸出來
            StatPills(
              [
                ('等您確認', '${_waitingBookings.length}'),
                ('已確認活動', '$_bookedCount'),
                ('幫我的家人', '$_helperCount'),
              ],
              onTaps: [
                () => _go(BookingListPage(api: api, elderId: _me.id)),
                () => _go(BookingListPage(api: api, elderId: _me.id)),
                () => _go(MyHelpersPage(api: api)),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                if (_pending.isNotEmpty)
                  ElderNoticeCard(
                    icon: Icons.notifications_active,
                    title: '${_pending.first.familyName} 想幫您辦事',
                    subtitle: '點這裡決定要不要同意',
                    onTap: () => _go(ApprovePage(api: api, delegation: _pending.first)),
                    speakText: '${_pending.first.familyName}想幫您辦事，按一下這個黃色框框，決定要不要同意',
                  ),
                if (_waitingBookings.isNotEmpty)
                  ElderNoticeCard(
                    icon: Icons.event_note,
                    title: '有 ${_waitingBookings.length} 個活動等您確認',
                    subtitle: '${_waitingBookings.first.bookedByName} 幫您報名了「${_waitingBookings.first.title}」',
                    onTap: () => _go(BookingListPage(api: api, elderId: _me.id)),
                    speakText: '家人幫您報名了${_waitingBookings.length}個活動，按一下這個黃色框框，確認要不要參加',
                  ),
                const SizedBox(height: 4),
                BigButton(
                  icon: Icons.family_restroom,
                  label: '讓家人幫我辦事',
                  caption: '給家人一組號碼',
                  gradient: ElderGradients.invite,
                  textColor: ElderGradients.ink,
                  speakLabel: '藍色按鈕：讓家人幫您辦事。按一下，會出現一組號碼給家人。',
                  onPressed: () => _go(InviteCodePage(api: api)),
                ),
                BigButton(
                  icon: Icons.groups,
                  label: '誰在幫我',
                  caption: '看家人能幫什麼、收回',
                  gradient: ElderGradients.helpers,
                  textColor: ElderGradients.ink,
                  speakLabel: '藍色按鈕：看誰在幫您，也可以不讓他幫。',
                  onPressed: () => _go(MyHelpersPage(api: api)),
                ),
                BigButton(
                  icon: Icons.history,
                  label: '家人幫我做過的事',
                  caption: '每一件事都有紀錄',
                  gradient: ElderGradients.history,
                  textColor: ElderGradients.ink,
                  speakLabel: '藍色按鈕：聽家人幫您做過哪些事。',
                  onPressed: () => _go(ActivityLogPage(api: api, elderId: _me.id)),
                ),
                BigButton(
                  icon: Icons.event_note,
                  label: '已報名活動清單',
                  caption: '確認參加或取消活動',
                  color: ElderGradients.yellow,
                  textColor: ElderGradients.ink,
                  speakLabel: '黃色按鈕：看您報名了哪些活動，可以確認參加或取消。',
                  onPressed: () => _go(BookingListPage(api: api, elderId: _me.id)),
                ),
                BigButton(
                  icon: Icons.auto_awesome,
                  label: '推薦活動',
                  caption: '適合${_me.age != null ? '${_me.age}歲' : '您'}的據點活動',
                  gradient: ElderGradients.recommend,
                  textColor: ElderGradients.ink,
                  speakLabel: '藍色按鈕：看適合您年紀的活動，喜歡就可以報名。',
                  onPressed: () => _go(RecommendedActivitiesPage(api: api, me: _me)),
                ),
                // 還沒綁定任何家人時，才能改身分
                if (!_me.linked) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: _resetRole,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('我不是長輩，重新選擇身分'),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 邀請碼：6 格大數字（手機上不會換行）＋逐字唸出，每 3 秒檢查家屬是否已輸入
// =====================================================================
class InviteCodePage extends StatefulWidget {
  final DelegationApi api;

  const InviteCodePage({super.key, required this.api});

  @override
  State<InviteCodePage> createState() => _InviteCodePageState();
}

class _InviteCodePageState extends State<InviteCodePage> {
  Invitation? _inv;
  Object? _error;
  Timer? _poll;
  Timer? _tick;
  Duration _left = Duration.zero;
  bool _expiredSpoken = false;

  @override
  void initState() {
    super.initState();
    _create();
  }

  bool get _isExpired {
    final inv = _inv;
    return inv != null && DateTime.now().isAfter(inv.expiresAt);
  }

  void _announce() {
    final inv = _inv;
    if (inv == null) return;
    if (_isExpired) {
      speaker.say('這組號碼過期了。請按下面灰色的按鈕，換一組新的號碼。');
      return;
    }
    final digits = spellDigits(inv.code);
    speaker.say('請把這組號碼，念給您的家人聽。$digits。'
        '再說一次：$digits。'
        '只能給您認識的家人。如果有陌生人打電話來要號碼，不要給他。'
        '家人輸入以後，手機會自動跳到下一步。');
  }

  Future<void> _create() async {
    setState(() {
      _inv = null;
      _error = null;
      _expiredSpoken = false;
    });
    try {
      final inv = await widget.api.createInvitation();
      if (!mounted) return;
      setState(() {
        _inv = inv;
        _left = inv.expiresAt.difference(DateTime.now());
      });
      _startTimers();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _startTimers() {
    _poll?.cancel();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final inv = _inv;
      if (inv == null || !mounted) return;
      final left = inv.expiresAt.difference(DateTime.now());
      setState(() => _left = left.isNegative ? Duration.zero : left);
      if (_isExpired && !_expiredSpoken) {
        _expiredSpoken = true;
        _poll?.cancel();
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkPending());
  }

  Future<void> _checkPending() async {
    try {
      final pending = await widget.api.pendingDelegations();
      if (!mounted || pending.isEmpty) return;
      _poll?.cancel();
      _tick?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ElderScale(child: ApprovePage(api: widget.api, delegation: pending.first))),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv = _inv;
    final expired = _isExpired;
    return Scaffold(
      appBar: elderAppBar(context, title: '讓家人幫我', onListen: _announce),
      // 按鈕固定在底部，內容可捲動：字放大也不會擠爆畫面
      bottomNavigationBar: inv == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: BigButton(
                  icon: Icons.refresh,
                  label: '換一組號碼',
                  color: _grey,
                  speakLabel: '灰色按鈕：換一組新的號碼。',
                  onPressed: _create,
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          if (_error != null) Text('$_error', style: const TextStyle(color: TPColors.red600)),
          if (inv == null && _error == null) const Center(child: CircularProgressIndicator()),
          if (inv != null) ...[
            const Icon(Icons.record_voice_over, size: 56),
            const SizedBox(height: 8),
            const Text('把號碼念給家人聽', textAlign: TextAlign.center, style: TextStyle(fontSize: 22)),
            const SizedBox(height: 20),
            CodeDigits(code: inv.code, dim: expired),
            const SizedBox(height: 16),
            Text(
              expired ? '號碼已過期' : '${_left.inMinutes} 分 ${_left.inSeconds % 60} 秒內有效',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: expired ? _red : null),
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_disabled, color: _red, size: 32),
                SizedBox(width: 8),
                Flexible(child: Text('陌生人打電話來要號碼，不要給', style: TextStyle(color: _red, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 12),
            if (!expired) const Text('家人輸入後，這裡會自動跳到下一步', textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// 6 位數放在 6 個等寬格子裡，每格用 FittedBox 自動縮放：
/// 不管手機多窄、字放多大，都固定一行、不會換行。
class CodeDigits extends StatelessWidget {
  final String code;
  final bool dim;

  const CodeDigits({super.key, required this.code, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final color = dim ? TPColors.grayscale400 : TPColors.grayscale950;
    return Row(
      children: [
        for (final c in code.split(''))
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AspectRatio(
                aspectRatio: 0.78,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TPColors.white,
                    border: Border.all(color: color, width: 2.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        c,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(fontSize: 52, height: 1.0, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =====================================================================
// 同意畫面：一項一項唸給長輩聽，點一下就打勾
// =====================================================================
class ApprovePage extends StatefulWidget {
  final DelegationApi api;
  final Delegation delegation;

  const ApprovePage({super.key, required this.api, required this.delegation});

  @override
  State<ApprovePage> createState() => _ApprovePageState();
}

class _ApprovePageState extends State<ApprovePage> {
  late final Future<List<ScopeInfo>> _scopes = widget.api.scopes().then((s) {
    _loaded = s;
    return s;
  });
  List<ScopeInfo> _loaded = [];
  final Set<String> _selected = {};
  int _days = 30;
  bool _busy = false;

  String get _family => widget.delegation.familyName;

  void _announce() {
    final b = StringBuffer('$_family想幫您辦事。');
    b.write('下面有${_loaded.length}件事。願意讓他幫忙的，就按一下，會出現打勾。');
    for (var i = 0; i < _loaded.length; i++) {
      final s = _loaded[i];
      b.write('第${i + 1}件，${speakScope(s.code, s.label)}。');
    }
    b.write('讓他幫忙的時間，現在是$_days天。');
    b.write('選好以後，按藍綠色的同意。不要的話，按灰色的不同意。');
    speaker.say(b.toString());
  }

  void _toggle(ScopeInfo s) {
    setState(() {
      if (_selected.contains(s.code)) {
        _selected.remove(s.code);
      } else {
        _selected.add(s.code);
      }
    });
  }

  Future<void> _approve() async {
    if (_selected.isEmpty) {
      elderMessage(context, '請先選至少一件事，按一下出現打勾，再按「同意」');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.approve(widget.delegation.id, _selected, _days);
      if (!mounted) return;
      showMessage(context, '已同意，$_family 現在可以幫您了');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) elderMessage(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await widget.api.reject(widget.delegation.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) elderMessage(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: elderAppBar(context, title: '家人想幫您', onListen: _announce),
      body: AsyncView<List<ScopeInfo>>(
        future: _scopes,
        builder: (scopes) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              const Icon(Icons.person, size: 48),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$_family 想幫您：', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 12),
            for (final s in scopes)
              Card(
                color: _selected.contains(s.code) ? TPColors.primary50 : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: _selected.contains(s.code) ? _green : TPColors.grayscale200, width: 3),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _toggle(s),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(_scopeIcon(s.code), size: 48),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s.label, style: const TextStyle(fontSize: 22))),
                      Icon(
                        _selected.contains(s.code) ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 48,
                        color: _selected.contains(s.code) ? _green : TPColors.grayscale400,
                      ),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Row(children: [
              Icon(Icons.calendar_month, size: 36),
              SizedBox(width: 8),
              Text('幫忙多久', style: TextStyle(fontSize: 20)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final days in [7, 30, 90])
                  ChoiceChip(
                    label: Text('$days 天', style: const TextStyle(fontSize: 20)),
                    selected: _days == days,
                    onSelected: (_) {
                      setState(() => _days = days);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 28),
            BigButton(
              icon: Icons.check_circle,
              label: '同意',
              color: _green,
              speakLabel: '藍綠色按鈕：同意，讓$_family幫您打勾的事。',
              onPressed: _busy ? null : _approve,
            ),
            BigButton(
              icon: Icons.cancel,
              label: '不同意',
              color: _grey,
              speakLabel: '灰色按鈕：不同意，不讓$_family幫忙。',
              onPressed: _busy ? null : _reject,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 誰在幫我：唸出每位家人能做什麼，紅色按鈕收回
// =====================================================================
class MyHelpersPage extends StatefulWidget {
  final DelegationApi api;

  const MyHelpersPage({super.key, required this.api});

  @override
  State<MyHelpersPage> createState() => _MyHelpersPageState();
}

class _MyHelpersPageState extends State<MyHelpersPage> {
  late Future<List<Delegation>> _future = _load();
  List<Delegation> _list = [];

  @override
  void initState() {
    super.initState();
    NoticeCenter.instance.changes.addListener(_reload);
  }

  @override
  void dispose() {
    NoticeCenter.instance.changes.removeListener(_reload);
    super.dispose();
  }

  Future<List<Delegation>> _load({bool announce = false}) async {
    final all = await widget.api.myDelegations();
    _list = all.where((d) => d.isActive || d.isPending).toList();
    if (announce) _announce();
    return _list;
  }

  /// 重新載入時先保留舊畫面，資料回來再換，不會整頁閃成轉圈圈。
  void _reload() {
    final f = _load();
    f.then((_) {
      if (mounted) setState(() => _future = f);
    }, onError: (_) {});
  }

  String _describe(Delegation d) {
    if (d.isPending) return '${d.familyName}，在等您同意。';
    final things = d.scopes.map((s) => speakScope(s.code, s.label)).join('，還有');
    final until = d.expiresAt == null ? '' : '到${d.expiresAt!.month}月${d.expiresAt!.day}日';
    return '${d.familyName}，可以$things，$until。';
  }

  void _announce() {
    if (_list.isEmpty) {
      speaker.say('目前沒有家人在幫您。');
      return;
    }
    final b = StringBuffer('目前有${_list.length}位家人。');
    for (final d in _list) {
      b.write(_describe(d));
    }
    b.write('如果不想讓他幫忙，按他下面紅色的收回。按名字，可以再聽一次。');
    speaker.say(b.toString());
  }

  Future<void> _revoke(Delegation d) async {
    final ok = await elderConfirm(context,
        title: '確定不讓 ${d.familyName} 幫您了嗎？',
        message: '收回以後，${d.familyName} 就不能再幫您辦事',
        okLabel: '收回',
        okColor: _red,
        icon: Icons.block);
    if (!ok) {
      speaker.stop();
      return;
    }
    try {
      await widget.api.revoke(d.id);
      if (!mounted) return;
      elderMessage(context, '好，已經收回了。${d.familyName}不能再幫您辦事。');
      _reload();
    } catch (e) {
      if (mounted) elderMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: elderAppBar(context, title: '誰在幫我', onListen: _announce),
      body: AsyncView<List<Delegation>>(
        future: _future,
        builder: (list) {
          if (list.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.groups,
                title: '目前沒有家人在幫您',
                message: '回到首頁按「讓家人幫我辦事」，把號碼給家人',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final d in list)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: TPColors.primary100,
                            child: Text(d.familyName.characters.first,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w700, color: TPColors.primary700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child:
                                Text(d.familyName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(d.isPending ? Icons.hourglass_top : Icons.event, size: 20, color: TPColors.grayscale500),
                          const SizedBox(width: 4),
                          Text(d.isPending ? '等待您同意' : '可以幫您到 ${fmtDate(d.expiresAt)}',
                              style: const TextStyle(color: TPColors.grayscale700)),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          for (final s in d.scopes)
                            Chip(
                              avatar: Icon(_scopeIcon(s.code), color: TPColors.primary700),
                              label: Text(s.label),
                              backgroundColor: TPColors.primary50,
                              side: BorderSide.none,
                            ),
                        ]),
                        const SizedBox(height: 8),
                        if (d.isPending)
                          BigButton(
                            icon: Icons.how_to_reg,
                            label: '決定要不要同意',
                            color: _green,
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ElderScale(child: ApprovePage(api: widget.api, delegation: d))),
                              );
                              _reload();
                            },
                          )
                        else
                          BigButton(
                            icon: Icons.block,
                            label: '收回',
                            color: _red,
                            speakLabel: '紅色按鈕：收回，不讓${d.familyName}再幫您。',
                            onPressed: () => _revoke(d),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================================
// 操作紀錄：自動唸最近 5 筆，點任一筆再聽
// =====================================================================
class ActivityLogPage extends StatefulWidget {
  final DelegationApi api;
  final int elderId;

  const ActivityLogPage({super.key, required this.api, required this.elderId});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  late Future<List<ActionLogEntry>> _future = widget.api.logs(widget.elderId).then((l) {
    _logs = l;
    return l;
  });
  List<ActionLogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    NoticeCenter.instance.changes.addListener(_reload);
  }

  @override
  void dispose() {
    NoticeCenter.instance.changes.removeListener(_reload);
    super.dispose();
  }

  /// 有新動作時自動更新（不重唸，資料回來才換畫面）。
  void _reload() {
    final f = widget.api.logs(widget.elderId);
    f.then((l) {
      if (!mounted) return;
      _logs = l;
      setState(() => _future = f);
    }, onError: (_) {});
  }

  String _line(ActionLogEntry l) => '${speakTime(l.createdAt)}，${l.message}。';

  void _announce() {
    if (_logs.isEmpty) {
      speaker.say('還沒有任何紀錄。');
      return;
    }
    final recent = _logs.take(5).toList();
    final b = StringBuffer('最近的${recent.length}件事。');
    for (final l in recent) {
      b.write(_line(l));
    }
    b.write('按任何一行，可以再聽一次。');
    speaker.say(b.toString());
  }

  /// 圖示顏色：收回/取消是紅、同意/確認是藍綠、報名是金、其他灰。
  (Color, Color) _tone(String action) {
    if (action.contains('REVOKED') || action.contains('REJECTED') || action.contains('CANCELLED')) {
      return (TPColors.red600, TPColors.red50);
    }
    if (action.contains('APPROVED') || action.contains('CONFIRMED')) return (TPColors.primary700, TPColors.primary50);
    if (action.contains('BOOK')) return (TPColors.secondary700, TPColors.secondary100);
    return (TPColors.grayscale600, TPColors.grayscale100);
  }

  IconData _icon(String action) {
    if (action.contains('CANCELLED')) return Icons.event_busy;
    if (action.contains('CONFIRMED')) return Icons.event_available;
    if (action.contains('REVOKED')) return Icons.block;
    if (action.contains('APPROVED')) return Icons.check_circle;
    if (action.contains('REJECTED')) return Icons.cancel;
    if (action.contains('REQUESTED')) return Icons.person_add;
    if (action.contains('BOOK')) return Icons.event_available;
    return Icons.visibility;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: elderAppBar(context, title: '做過的事', onListen: _announce),
      body: AsyncView<List<ActionLogEntry>>(
        future: _future,
        builder: (logs) => logs.isEmpty
            ? const Center(child: EmptyState(icon: Icons.history, title: '還沒有紀錄', message: '家人幫您做的每一件事，都會記在這裡'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final (fg, bg) = _tone(logs[i].action);
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: bg,
                        child: Icon(_icon(logs[i].action), size: 28, color: fg),
                      ),
                      title: Text(logs[i].message, style: const TextStyle(fontSize: 18, color: TPColors.grayscale900)),
                      subtitle: Text(fmtTime(logs[i].createdAt), style: const TextStyle(color: TPColors.grayscale500)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// =====================================================================
// 已報名活動清單：家屬代為報名的活動，要長輩自己再確認一次（雙重確認）
// - 待確認：藍綠色「確認參加」、紅色「取消報名」，按下去還會再問一次
// - 已確認：可以取消
// - 不管確認或取消，幫忙報名的家人都會收到通知
// =====================================================================
class BookingListPage extends StatefulWidget {
  final DelegationApi api;
  final int elderId;

  const BookingListPage({super.key, required this.api, required this.elderId});

  @override
  State<BookingListPage> createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  late Future<List<BookingInfo>> _future = _load();
  List<BookingInfo> _list = [];
  int? _busyId;

  @override
  void initState() {
    super.initState();
    // 打開清單就算看過通知；在這頁時有新的報名，清單自動更新
    NoticeCenter.instance.markAllRead();
    NoticeCenter.instance.notices.addListener(_onNotice);
    NoticeCenter.instance.changes.addListener(_reload);
  }

  @override
  void dispose() {
    NoticeCenter.instance.notices.removeListener(_onNotice);
    NoticeCenter.instance.changes.removeListener(_reload);
    super.dispose();
  }

  void _onNotice() {
    if (NoticeCenter.instance.unreadCount > 0) {
      NoticeCenter.instance.markAllRead();
      _reload();
    }
  }

  Future<List<BookingInfo>> _load({bool announce = false}) async {
    _list = await widget.api.bookings(widget.elderId);
    if (announce) _announce();
    return _list;
  }

  /// 重新載入時先保留舊畫面，資料回來再換，不會整頁閃成轉圈圈。
  void _reload() {
    final f = _load();
    f.then((_) {
      if (mounted) setState(() => _future = f);
    }, onError: (_) {});
  }

  /// 依「下一次上課的日期＋時間」排序，最近的在最前面。
  List<BookingInfo> _sorted(bool Function(BookingInfo) test) =>
      _list.where(test).toList()..sort((x, y) => x.sortKey.compareTo(y.sortKey));

  List<BookingInfo> get _waiting => _sorted((b) => b.isPending);

  List<BookingInfo> get _confirmed => _sorted((b) => b.isConfirmed);

  List<BookingInfo> get _cancelled => _sorted((b) => b.isCancelled);

  /// 有活動的日期（等您確認＋已確認），沒有活動的日期不出現。
  Map<DateTime, List<BookingInfo>> get _byDate {
    final map = <DateTime, List<BookingInfo>>{};
    for (final b in _sorted((b) => !b.isCancelled && b.sessionDate != null)) {
      map.putIfAbsent(b.sessionDate!, () => []).add(b);
    }
    return map;
  }

  String _who(BookingInfo b) => b.bookedByFamily ? '${b.bookedByName}幫您報名' : '您自己報名';

  String _when(BookingInfo b) =>
      b.sessionDate == null ? '' : '${speakDay(b.sessionDate!)}${b.startTime == null ? '' : '，${b.startTime}開始'}，';

  String _describe(BookingInfo b) {
    if (b.isPending) return '${_when(b)}${b.bookedByName}幫您報名了${b.fullName}，等您確認。';
    if (b.isConfirmed) return '${_when(b)}${b.fullName}，${_who(b)}，您已經確認參加。';
    return '${b.fullName}，已經取消了。';
  }

  void _announce() {
    if (_list.isEmpty) {
      speaker.say('您還沒有報名任何活動。');
      return;
    }
    final b = StringBuffer();
    final waiting = _waiting;
    if (waiting.isNotEmpty) {
      b.write('有${waiting.length}個活動等您確認。');
      for (final w in waiting) {
        b.write(_describe(w));
      }
      b.write('要參加，按藍綠色的確認參加。不想去，按紅色的取消報名。');
    }
    final days = _byDate;
    if (days.isNotEmpty) {
      b.write('您接下來有${days.length}天要參加活動。');
      for (final e in days.entries.take(3)) {
        b.write('${speakDay(e.key)}，${e.value.length}場。');
      }
      b.write('上面的方塊是每一天的活動，按一下可以看那天要參加哪些。');
    }
    b.write('按活動的名字，可以再聽一次。');
    speaker.say(b.toString());
  }

  Future<void> _confirm(BookingInfo b) async {
    // 雙重確認：先按按鈕，再跳出視窗問一次
    final ok = await elderConfirm(context,
        title: '確定要參加嗎？',
        message: '「${b.fullName}」\n${_who(b)}',
        okLabel: '確認參加',
        okColor: _green,
        icon: Icons.check_circle);
    if (!ok) {
      speaker.stop();
      return;
    }
    await _send(b, confirm: true);
  }

  Future<void> _cancel(BookingInfo b) async {
    final ok = await elderConfirm(context,
        title: '確定要取消報名嗎？',
        message: '「${b.fullName}」${b.bookedByFamily ? '\n取消後會通知${b.bookedByName}' : ''}',
        okLabel: '取消報名',
        okColor: _red,
        icon: Icons.event_busy);
    if (!ok) {
      speaker.stop();
      return;
    }
    await _send(b, confirm: false);
  }

  Future<void> _send(BookingInfo b, {required bool confirm}) async {
    setState(() => _busyId = b.id);
    try {
      if (confirm) {
        await widget.api.confirmBooking(widget.elderId, b.id);
      } else {
        await widget.api.cancelBookingByElder(widget.elderId, b.id);
      }
      if (!mounted) return;
      final tell = b.bookedByFamily ? '已經通知${b.bookedByName}。' : '';
      elderMessage(
        context,
        confirm ? '好，您確認參加${b.fullName}了。$tell' : '好，${b.fullName}已經取消了。$tell',
      );
      _reload();
    } catch (e) {
      if (mounted) elderMessage(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _card(BookingInfo b) {
    final busy = _busyId == b.id;
    final muted = b.isCancelled;
    return FolderCard(
      // 分頁：活動類型（參考設計稿左上角的膠囊）
      tab: TabChip(b.categoryLabel ?? '據點活動', categoryIcon(b.category), fontSize: 15),
      trailing: bookingStatusTag(b.status, b.statusLabel),
      color: b.isPending ? TPColors.secondary100 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(
                b.title,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: muted ? TPColors.grayscale500 : TPColors.grayscale900,
                  decoration: muted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          if (b.activityTitle != null) _line(Icons.home_work_outlined, b.servicePointName),
          if (b.sessionDate != null)
            _line(Icons.event, '下次：${fmtDay(b.sessionDate!)} ${b.timeRange}')
          else if (b.schedule != null)
            _line(Icons.schedule, b.schedule!),
          if (b.address != null) _line(Icons.place_outlined, b.address!),
          _line(b.bookedByFamily ? Icons.family_restroom : Icons.person_outline, '${_who(b)}｜${fmtTime(b.createdAt)}'),
          if (b.isPending) ...[
            const SizedBox(height: 8),
            BigButton(
              icon: Icons.check_circle,
              label: '確認參加',
              color: _green,
              speakLabel: '藍綠色按鈕：確認參加${b.fullName}。',
              onPressed: busy ? null : () => _confirm(b),
            ),
          ],
          if (!b.isCancelled)
            BigButton(
              icon: Icons.event_busy,
              label: '取消報名',
              color: _red,
              speakLabel: '紅色按鈕：取消${b.fullName}的報名。',
              onPressed: busy ? null : () => _cancel(b),
            ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: TPColors.grayscale500),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: TPColors.grayscale700))),
        ]),
      );

  // ---------- 上方固定：每天幾場（只列有活動的日期） ----------
  /// 方塊大小（正方形）。整塊內容會自動縮放，字放大 1.3 倍也不會超出。
  static const double _tile = 96;

  Widget _dayTiles(Map<DateTime, List<BookingInfo>> days) {
    final today = DateTime.now();
    return Container(
      height: _tile + 20,
      decoration: const BoxDecoration(
        color: TPColors.grayscale50,
        border: Border(bottom: BorderSide(color: TPColors.grayscale100)), // 和下方清單分開
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final e = days.entries.elementAt(i);
          final d = e.key;
          final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
          final waiting = e.value.where((b) => b.isPending).length;
          final shape = RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isToday ? TPColors.primary500 : TPColors.grayscale200, width: 2),
          );
          return SizedBox.square(
            dimension: _tile,
            child: Material(
              color: isToday ? TPColors.primary100 : TPColors.white,
              shape: shape,
              child: InkWell(
                customBorder: shape,
                onTap: () => _showDay(d, e.value),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(isToday ? '今天' : fmtDay(d),
                          maxLines: 1,
                          style:
                              const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TPColors.grayscale800)),
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: '${e.value.length}',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800, color: TPColors.grayscale900, height: 1.15)),
                        const TextSpan(text: ' 場', style: TextStyle(fontSize: 14, color: TPColors.grayscale600)),
                      ])),
                      if (waiting > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration:
                              BoxDecoration(color: TPColors.secondary200, borderRadius: BorderRadius.circular(8)),
                          child: Text('$waiting 待確認',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700, color: TPColors.secondary800)),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 點方塊：跳出那天要參加的活動（依時間排序）。
  Future<void> _showDay(DateTime d, List<BookingInfo> list) async {
    final sorted = [...list]..sort((x, y) => x.sortKey.compareTo(y.sortKey));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TPColors.grayscale50,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => ElderScale(
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(color: TPColors.grayscale300, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Text('${fmtDay(d)}・${sorted.length} 場活動', style: TPText.h2.copyWith(fontSize: 22)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [
                    for (final b in sorted)
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(TPRadius.card),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                width: 74,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration:
                                    BoxDecoration(color: TPColors.primary50, borderRadius: BorderRadius.circular(14)),
                                child: Column(children: [
                                  Text(b.startTime ?? '--',
                                      style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w800, color: TPColors.primary700)),
                                  Text(b.endTime ?? '',
                                      style: const TextStyle(fontSize: 12, color: TPColors.grayscale500)),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(b.title, style: TPText.title),
                                  Text(b.servicePointName, style: TPText.body),
                                  const SizedBox(height: 4),
                                  bookingStatusTag(b.status, b.statusLabel),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: BigButton(
                  icon: Icons.close,
                  label: '關閉',
                  color: TPColors.grayscale500,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- 下方：依日期的下拉式清單 ----------
  Widget _sectionTitle(String title, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _dayGroup(String title, List<BookingInfo> list, {bool expanded = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          expansionAnimationStyle: kExpandAnimation,
          initiallyExpanded: expanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          iconColor: TPColors.grayscale800,
          collapsedIconColor: TPColors.grayscale800,
          title: Text(title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: TPColors.grayscale900)),
          subtitle: Text('${list.length} 場', style: TPText.body),
          children: [for (final b in list) _card(b)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: elderAppBar(context, title: '已報名活動清單', onListen: _announce),
      body: AsyncView<List<BookingInfo>>(
        future: _future,
        builder: (list) {
          if (list.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.event_note,
                title: '您還沒有報名任何活動',
                message: '家人幫您報名後，會出現在這裡',
              ),
            );
          }
          final days = _byDate;
          final waiting = _waiting, confirmed = _confirmed, cancelled = _cancelled;
          // 已確認：依日期分組（最近的在最上面）；沒有日期的放「未排定日期」
          final groups = <DateTime?, List<BookingInfo>>{};
          for (final b in confirmed) {
            groups.putIfAbsent(b.sessionDate, () => []).add(b);
          }
          final dated = groups.keys.whereType<DateTime>().toList()..sort();
          return Column(children: [
            // 固定在上方，不跟著捲動
            if (days.isNotEmpty) _dayTiles(days),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (waiting.isNotEmpty) ...[
                      _sectionTitle('等您確認（${waiting.length}）', Icons.notifications_active, TPColors.secondary700),
                      for (final b in waiting) _card(b),
                    ],
                    if (confirmed.isNotEmpty) ...[
                      _sectionTitle('已確認（${confirmed.length}）', Icons.check_circle, TPColors.primary700),
                      for (var i = 0; i < dated.length; i++)
                        _dayGroup(fmtDay(dated[i]), groups[dated[i]]!, expanded: i == 0),
                      if (groups[null] != null) _dayGroup('未排定日期', groups[null]!),
                    ],
                    if (cancelled.isNotEmpty) ...[
                      _sectionTitle('已取消（${cancelled.length}）', Icons.event_busy, TPColors.grayscale600),
                      _dayGroup('已取消的活動', cancelled),
                    ],
                  ],
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// =====================================================================
// 推薦活動：依長輩年齡（65–74 / 75–84 / 85 以上）篩選的據點活動
// - 上面選活動類型（健康促進、樂齡學習、休閒娛樂、共餐服務、社交聯誼）
// - 預設只看自己住的區，也可以看全臺北市
// - 喜歡就按「我要報名」，一樣會再問一次（雙重確認）
// =====================================================================
class RecommendedActivitiesPage extends StatefulWidget {
  final DelegationApi api;
  final UserInfo me;

  const RecommendedActivitiesPage({super.key, required this.api, required this.me});

  @override
  State<RecommendedActivitiesPage> createState() => _RecommendedActivitiesPageState();
}

class _RecommendedActivitiesPageState extends State<RecommendedActivitiesPage> {
  String? _category; // null = 全部
  late bool _myDistrict = widget.me.district != null;
  late Future<ActivityList> _future = _load();
  ActivityList? _data;
  int? _busyId;

  static const _categories = [
    (null, '全部', Icons.apps),
    ('HEALTH', '健康促進', Icons.directions_run),
    ('LEARNING', '樂齡學習', Icons.menu_book),
    ('LEISURE', '休閒娛樂', Icons.palette),
    ('MEAL', '共餐服務', Icons.restaurant),
    ('SOCIAL', '社交聯誼', Icons.diversity_3),
  ];

  Future<ActivityList> _load({bool announce = false}) async {
    final d = await widget.api
        .activities(widget.me.id, category: _category, district: _myDistrict ? widget.me.district : null);
    _data = d;
    if (announce) _announce();
    return d;
  }

  void _reload({bool announce = false}) {
    final f = _load(announce: announce);
    f.then((_) {
      if (mounted) setState(() => _future = f);
    }, onError: (_) {});
  }

  void _announce() {
    final d = _data;
    if (d == null) return;
    final b = StringBuffer('依照您的年紀${d.age ?? ''}歲，推薦適合您的活動。');
    if (d.activities.isEmpty) {
      b.write('這個種類目前沒有活動，可以換別的種類看看。');
    } else {
      b.write('有${d.activities.length}個活動。');
      for (final a in d.activities.take(3)) {
        b.write('${a.title}，在${a.servicePointName}，${a.schedule ?? ''}。');
      }
      b.write('上面可以選活動的種類。喜歡的活動，按藍綠色的我要報名。按活動的名字，可以再聽一次。');
    }
    if (d.hiddenByConflict > 0) {
      b.write('和您已經報名的活動同一個時間的，有${d.hiddenByConflict}個沒有列出來。');
    }
    speaker.say(b.toString());
  }

  Future<void> _book(ActivityInfo a) async {
    final ok = await elderConfirm(context,
        title: '確定要報名嗎？',
        message: '「${a.title}」\n${a.servicePointName}\n${a.schedule ?? ''}',
        okLabel: '我要報名',
        okColor: _green,
        icon: Icons.event_available);
    if (!ok) {
      speaker.stop();
      return;
    }
    setState(() => _busyId = a.id);
    try {
      await widget.api.bookActivity(widget.me.id, a.id);
      if (!mounted) return;
      elderMessage(context, '好，您報名了${a.title}。可以在「已報名活動清單」看到。');
      _reload();
    } catch (e) {
      if (mounted) elderMessage(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _card(ActivityInfo a, {bool dark = false}) {
    final sub = dark ? TPColors.grayscale200 : TPColors.grayscale600;
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: sub),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: sub))),
          ]),
        );
    return FolderCard(
      dark: dark,
      tab: TabChip(a.categoryLabel, categoryIcon(a.category), dark: dark, fontSize: 15),
      trailing: StatusTag(text: a.ageLabel, color: TPColors.primary700, background: TPColors.primary100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(a.title,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: dark ? TPColors.white : TPColors.grayscale900)),
          ),
        ]),
        if (a.description != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(a.description!,
                style: TextStyle(fontSize: 16, color: dark ? TPColors.grayscale100 : TPColors.grayscale700)),
          ),
        line(Icons.home_work_outlined, a.servicePointName),
        if (a.schedule != null) line(Icons.schedule, a.schedule!),
        if (a.address != null) line(Icons.place_outlined, a.address!),
        const SizedBox(height: 8),
        if (a.isBooked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark ? TPColors.grayscale700 : TPColors.primary50,
              borderRadius: BorderRadius.circular(TPRadius.button),
            ),
            child: Text(a.bookingStatus == 'PENDING_ELDER' ? '家人幫您報名了，等您確認' : '已報名',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, color: dark ? TPColors.white : TPColors.primary700)),
          )
        else
          BigButton(
            icon: Icons.event_available,
            label: '我要報名',
            color: dark ? TPColors.primary500 : _green,
            textColor: dark ? TPColors.grayscale950 : null,
            speakLabel: '藍綠色按鈕：報名${a.title}。',
            onPressed: _busyId == a.id ? null : () => _book(a),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      appBar: elderAppBar(context, title: '推薦活動', onListen: _announce),
      body: Column(children: [
        PageHeader(
          title: '適合您的活動',
          subtitle: [
            if (me.age != null) '${me.age} 歲',
            if (me.ageGroupLabel != null) me.ageGroupLabel!,
          ].join('・'),
        ),
        PillSelector<String?>(
          large: true,
          options: [for (final c in _categories) (c.$1, c.$2, c.$3)],
          selected: _category,
          onSelected: (v) {
            setState(() => _category = v);
            _reload();
          },
        ),
        const SizedBox(height: 8),
        if (me.district != null)
          PillSelector<bool>(
            large: true,
            options: [
              (true, '我住的${me.district}', Icons.home_outlined),
              (false, '全臺北市', Icons.location_city),
            ],
            selected: _myDistrict,
            onSelected: (v) {
              setState(() => _myDistrict = v);
              _reload();
            },
          ),
        const SizedBox(height: 6),
        Expanded(
          child: AsyncView<ActivityList>(
            future: _future,
            builder: (d) {
              if (d.activities.isEmpty) {
                return Center(
                  child: EmptyState(
                    icon: Icons.event_busy,
                    title: '這個種類目前沒有活動',
                    message: d.hiddenByConflict > 0 ? '有 ${d.hiddenByConflict} 個和已報名活動時間衝突，取消報名後會出現' : '換別的種類或看全臺北市',
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: d.activities.length + 2,
                itemBuilder: (_, i) {
                  if (i == 0) return ConflictNote(d.hiddenByConflict, large: true);
                  i -= 1;
                  if (i == d.activities.length) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('資料來源：${d.source}', style: TPText.caption.copyWith(fontWeight: FontWeight.w400)),
                    );
                  }
                  // 第一個用深色卡片強調（參考設計稿）
                  return _card(d.activities[i], dark: i == 0);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
