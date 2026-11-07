import 'package:flutter/material.dart';

import 'api.dart';
import 'entry.dart';
import 'models.dart';
import 'notice_center.dart';
import 'tp_layout.dart';
import 'tp_theme.dart';
import 'widgets.dart';

// =====================================================================
// 家屬首頁：我照顧的長輩
// =====================================================================
class FamilyHomePage extends StatefulWidget {
  final DelegationApi api;
  final UserInfo me;

  const FamilyHomePage({super.key, required this.api, required this.me});

  @override
  State<FamilyHomePage> createState() => _FamilyHomePageState();
}

class _FamilyHomePageState extends State<FamilyHomePage> {
  // 登入時已經帶回來（或手機上的快取）就直接用，不用再等網路
  late Future<List<Delegation>> _future =
      widget.me.home != null ? Future.value(widget.me.home!.delegations) : widget.api.myDelegations();

  // ---- 通知：由 NoticeCenter 統一檢查、跳通知；這裡只負責顯示和更新 ----
  final _center = NoticeCenter.instance;
  int _lastCount = 0;

  List<NoticeInfo> get _notices => _center.notices.value;

  int get _unread => _center.unreadCount;

  @override
  void initState() {
    super.initState();
    _center.notices.addListener(_onNotices);
    _center.changes.addListener(_reload);
  }

  @override
  void dispose() {
    _center.notices.removeListener(_onNotices);
    _center.changes.removeListener(_reload);
    super.dispose();
  }

  void _onNotices() {
    if (!mounted) return;
    final count = _notices.length;
    final changed = count != _lastCount;
    _lastCount = count;
    setState(() {});
    if (changed) _reload(); // 有新通知 → 長輩清單上的狀態也更新
  }

  Future<void> _openNotices() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NoticesPage(api: widget.api)));
    _center.refresh();
  }

  /// 重新整理：資料回來才換畫面，不會閃成轉圈圈。
  Future<void> _reload() async {
    final f = widget.api.myDelegations();
    try {
      await f;
      if (mounted) setState(() => _future = f);
    } catch (_) {}
  }

  Future<void> _resetRole() async {
    final ok = await confirmDialog(context, '要重新選擇身分嗎？', '重新選擇');
    if (!ok || !mounted) return;
    try {
      final me = await widget.api.resetRole();
      if (!mounted) return;
      openHomeFor(context, widget.api, me);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _reload();
  }

  Widget _elderCard(Delegation d, {bool dark = false}) {
    final active = d.isActive;
    final fg = dark ? TPColors.white : (active ? TPColors.grayscale900 : TPColors.grayscale500);
    final sub = dark ? TPColors.grayscale200 : TPColors.grayscale600;
    return FolderCard(
      dark: dark,
      tab: TabChip(active ? '授權中' : d.statusLabel, active ? Icons.verified_user_outlined : Icons.hourglass_empty,
          dark: dark),
      trailing: active
          ? RoundIconButton(
              icon: Icons.chevron_right,
              tooltip: '查看${d.elderName}',
              size: 40,
              onPressed: () => _open(ElderDetailPage(api: widget.api, delegation: d)),
            )
          : null,
      onTap: active ? () => _open(ElderDetailPage(api: widget.api, delegation: d)) : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(d.elderName,
            size: 52,
            color: dark ? TPColors.grayscale900 : TPColors.primary700,
            background: dark ? TPColors.white : (active ? TPColors.primary100 : TPColors.grayscale100)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.elderName, style: TPText.title.copyWith(color: fg)),
            if (active) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in d.scopes)
                  StatusTag(
                    text: s.label,
                    color: dark ? TPColors.grayscale900 : TPColors.primary700,
                    background: dark ? TPColors.primary200 : TPColors.primary50,
                  ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.event, size: 16, color: sub),
                const SizedBox(width: 4),
                Text('授權到 ${fmtDate(d.expiresAt)}', style: TPText.body.copyWith(color: sub)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 參考設計稿：浮動膠囊導覽列
      extendBody: true,
      bottomNavigationBar: FloatingPillNav(
        current: 0,
        items: [
          (Icons.home_rounded, '我照顧的長輩', 0),
          (Icons.notifications_outlined, '通知', _unread),
          (Icons.pin_outlined, '輸入長輩的邀請碼', 0),
        ],
        onTap: (i) {
          if (i == 1) _openNotices();
          if (i == 2) _open(EnterCodePage(api: widget.api));
        },
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: AsyncView<List<Delegation>>(
            future: _future,
            builder: (list) {
              final linked = list.any((d) => d.isActive || d.isPending);
              final active = list.where((d) => d.isActive).toList();
              final unread = _notices.where((n) => !n.read).toList();
              final header = <Widget>[
                PageHeader(
                  large: true,
                  leading: Avatar(widget.me.name, size: 52),
                  actions: [
                    RoundIconButton(icon: Icons.notifications_outlined, tooltip: '通知', badge: _unread, onPressed: _openNotices),
                  ],
                  title: '我照顧的長輩',
                  subtitle: '${widget.me.name}，您好${widget.me.birthday == null ? '' : '・生日 ${widget.me.birthday}'}',
                ),
                const SizedBox(height: 6),
                // 三格數字都可以點進去看詳細清單
                StatPills(
                  [
                    ('照顧的長輩', '${active.length}'),
                    ('新通知', '${unread.length}'),
                    ('可代辦項目', '${active.fold<int>(0, (n, d) => n + d.scopes.length)}'),
                  ],
                  onTaps: [
                    () => _open(CaredEldersPage(api: widget.api, delegations: list)),
                    _openNotices,
                    () => _open(DelegatedScopesPage(api: widget.api, delegations: active)),
                  ],
                ),
                const SizedBox(height: 16),
              ];
              if (list.isEmpty) {
                return ListView(children: [
                  ...header,
                  EmptyState(
                    icon: Icons.link,
                    title: '還沒有綁定長輩',
                    message: '請長輩在台北通「家人代辦」產生邀請碼，\n再按下方的「輸入邀請碼」',
                    action: TextButton.icon(
                      onPressed: _resetRole,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('我不是家屬，重新選擇身分'),
                    ),
                  ),
                ]);
              }
              final firstActiveId = active.isEmpty ? null : active.first.id; // 第一位用深色卡片強調
              return ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  ...header,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      if (unread.isNotEmpty)
                        Card(
                          color: TPColors.secondary100,
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                            leading: Icon(unread.first.isConfirmed ? Icons.event_available : Icons.event_busy,
                                color: unread.first.isConfirmed ? TPColors.primary700 : TPColors.red600),
                            title: Text(unread.length == 1 ? unread.first.title : '有 ${unread.length} 則新通知',
                                style: TPText.h3),
                            subtitle: Text(unread.first.message, style: TPText.body),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _openNotices,
                          ),
                        ),
                      const SizedBox(height: 8),
                      for (final d in list)
                        _elderCard(d, dark: d.id == firstActiveId),
                      // 所有綁定都已失效時，才能改身分
                      if (!linked)
                        TextButton.icon(
                          onPressed: _resetRole,
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('我不是家屬，重新選擇身分'),
                        ),
                    ]),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// 輸入邀請碼
// =====================================================================
class EnterCodePage extends StatefulWidget {
  final DelegationApi api;

  const EnterCodePage({super.key, required this.api});

  @override
  State<EnterCodePage> createState() => _EnterCodePageState();
}

class _EnterCodePageState extends State<EnterCodePage> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _ctrl.text.trim();
    if (code.length != 6) {
      showMessage(context, '請輸入 6 位數字');
      return;
    }
    setState(() => _busy = true);
    try {
      final d = await widget.api.acceptInvitation(code);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('已送出申請'),
          content: Text('請 ${d.elderName} 在手機上按「同意」'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('好'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('輸入長輩的邀請碼')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, letterSpacing: 8),
              decoration: const InputDecoration(hintText: '000000', counterText: ''),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            BigButton(icon: Icons.send, label: '送出', onPressed: _busy ? null : _submit),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 長輩詳情：在授權範圍內代辦
// =====================================================================
class ElderDetailPage extends StatefulWidget {
  final DelegationApi api;
  final Delegation delegation;

  const ElderDetailPage({super.key, required this.api, required this.delegation});

  @override
  State<ElderDetailPage> createState() => _ElderDetailPageState();
}

class _ElderDetailPageState extends State<ElderDetailPage> {
  late Future<ElderProfile> _profile;
  late Future<List<BookingInfo>> _bookings;

  int get _elderId => widget.delegation.elderId;

  // ---- 搜尋報名過的活動 ----
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  static const _allCategories = ['健康促進', '樂齡學習', '休閒娛樂', '共餐服務', '社交聯誼'];

  bool _matches(BookingInfo b) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    return [b.title, b.servicePointName, b.categoryLabel, b.address, b.schedule, b.statusLabel, b.bookedByName]
        .whereType<String>()
        .any((t) => t.contains(q));
  }

  /// 關鍵字提醒：用活動類型（長輩報名過的類型排前面）
  List<String> _keywords(List<BookingInfo> list) {
    final used = list.map((b) => b.categoryLabel).whereType<String>().toSet();
    return [...used.where(_allCategories.contains), ..._allCategories.where((c) => !used.contains(c))];
  }

  @override
  void initState() {
    super.initState();
    _load();
    // 長輩確認 / 取消、其他家屬報名…有新動作時自動更新
    NoticeCenter.instance.changes.addListener(_refresh);
    _searchFocus.addListener(() => setState(() {})); // 聚焦時才顯示關鍵字
  }

  @override
  void dispose() {
    NoticeCenter.instance.changes.removeListener(_refresh);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Widget _searchBox(List<BookingInfo> list) {
    final showHints = _searchFocus.hasFocus;
    // TextFieldTapRegion：點關鍵字不算「點到外面」，點其他地方才收起
    return TextFieldTapRegion(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          onTapOutside: (_) => _searchFocus.unfocus(),
          decoration: InputDecoration(
            hintText: '搜尋幫長輩報名過的活動',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: '清除',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _searchCtrl.clear();
                      _query = '';
                    }),
                  ),
            filled: true,
            fillColor: TPColors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: TPColors.grayscale200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: TPColors.grayscale200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: TPColors.primary500, width: 2),
            ),
          ),
        ),
        if (showHints)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 0, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('關鍵字（活動類型）', style: TPText.caption.copyWith(fontWeight: FontWeight.w400)),
              const SizedBox(height: 6),
              // 一整排，可以左右滑動
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final k in _keywords(list))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                    avatar: Icon(categoryIcon(_categoryCode(k)), size: 16, color: TPColors.grayscale700),
                    label: Text(k),
                    backgroundColor: _query == k ? TPColors.primary100 : TPColors.white,
                    side: BorderSide(color: _query == k ? TPColors.primary500 : TPColors.grayscale200),
                    onPressed: () => setState(() {
                      _searchCtrl.text = k;
                      _query = k;
                    }),
                  ),
                  ),
              ]),
              ),
            ]),
          ),
      ]),
    );
  }

  static String _categoryCode(String label) => switch (label) {
        '健康促進' => 'HEALTH',
        '樂齡學習' => 'LEARNING',
        '休閒娛樂' => 'LEISURE',
        '共餐服務' => 'MEAL',
        '社交聯誼' => 'SOCIAL',
        _ => '',
      };

  void _load() {
    _profile = widget.api.elderProfile(_elderId);
    _bookings = widget.api.bookings(_elderId);
  }

  /// 背景重新整理：資料回來才換，不會閃。授權被收回時，交給 _onForbidden 處理。
  Future<void> _refresh() async {
    final p = widget.api.elderProfile(_elderId);
    final b = widget.api.bookings(_elderId);
    try {
      await Future.wait([p, b]);
      if (mounted) setState(() {
        _profile = p;
        _bookings = b;
      });
    } on ApiError catch (e) {
      if (mounted && e.isForbidden) await _onForbidden(e);
    } catch (_) {}
  }

  /// 被後端擋下（長輩收回、過期、範圍不足）時的統一處理。
  Future<void> _onForbidden(ApiError e) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock, size: 40),
        title: const Text('無法代辦'),
        content: Text(e.message),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))],
      ),
    );
    // 整個授權失效 → 回首頁；只是範圍不足 → 留在本頁
    if (mounted && e.code != 'SCOPE_DENIED') Navigator.pop(context);
  }

  Future<void> _book() async {
    // 只列出符合長輩年齡的活動，可依類型篩選
    final act = await Navigator.push<ActivityInfo>(
      context,
      MaterialPageRoute(
          builder: (_) => ActivityPickerPage(api: widget.api, elderId: _elderId, elderName: widget.delegation.elderName)),
    );
    if (act == null || !mounted) return;
    final ok = await confirmDialog(
        context, '幫 ${widget.delegation.elderName} 報名「${act.title}」？\n${act.servicePointName}・${act.schedule ?? ''}', '報名');
    if (!ok) return;
    try {
      await widget.api.bookActivity(_elderId, act.id);
      if (!mounted) return;
      showMessage(context, '已報名，等長輩在「已報名活動清單」確認，確認或取消時會通知您');
      _refresh();
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.isForbidden) {
        await _onForbidden(e);
      } else {
        showMessage(context, e);
      }
    }
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 18, color: TPColors.grayscale500),
          const SizedBox(width: 6),
          SizedBox(width: 84, child: Text(label, style: const TextStyle(color: TPColors.grayscale600))),
          Expanded(child: Text(value, style: const TextStyle(color: TPColors.grayscale900))),
        ]),
      );

  Widget _lockedCard(Object e) => Card(
        color: TPColors.grayscale100,
        child: ListTile(leading: const Icon(Icons.lock), title: Text('$e')),
      );

  /// 一張報名卡片（資料夾分頁樣式）。
  Widget _bookingCard(BookingInfo b) => FolderCard(
        tab: TabChip(b.categoryLabel ?? '據點活動', categoryIcon(b.category)),
        trailing: bookingStatusTag(b.status, b.statusLabel),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            b.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TPText.title.copyWith(
              color: b.isCancelled ? TPColors.grayscale500 : TPColors.grayscale900,
              decoration: b.isCancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 4),
          if (b.activityTitle != null)
            Text(b.servicePointName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TPText.body),
          if (b.sessionDate != null)
            Text('下次：${fmtDay(b.sessionDate!)} ${b.timeRange}', style: TPText.body)
          else if (b.schedule != null)
            Text(b.schedule!, style: TPText.body),
          if (b.address != null)
            Text(b.address!,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TPText.body.copyWith(color: TPColors.grayscale500)),
          Text(
            b.bookedByFamily ? '由 ${b.bookedByName} 代為報名' : '長輩自己報名',
            style: TPText.body.copyWith(color: TPColors.grayscale500),
          ),
        ]),
      );

  /// 下拉式選單：已報名 / 已取消
  Widget _bookingGroup(String title, IconData icon, Color color, List<BookingInfo> list, String empty,
      {required bool expanded}) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          expansionAnimationStyle: kExpandAnimation,
          // 搜尋時換 key，讓兩個選單自動展開顯示結果
          key: ValueKey('$title-${_query.trim().isNotEmpty}'),
          initiallyExpanded: expanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          leading: Icon(icon, color: color),
          title: Row(children: [
            Text(title, style: TPText.h3.copyWith(color: color)),
            const SizedBox(width: 8),
            StatusTag(text: '${list.length}', color: color, background: TPColors.grayscale50),
          ]),
          children: list.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(empty, style: TPText.body.copyWith(color: TPColors.grayscale500)),
                  ),
                ]
              : [for (final b in list) _bookingCard(b)],
        ),
      ),
    );
  }

  /// 固定在上方的區塊高度：標題＋搜尋列（＋聚焦時的關鍵字、搜尋結果數）
  double _pinnedHeight() {
    var h = 56.0 + 60.0; // 標題 + 搜尋列
    if (_searchFocus.hasFocus) h += 76; // 關鍵字（一排）
    if (_query.trim().isNotEmpty) h += 28; // 「找到 N 筆」
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delegation;
    return Scaffold(
      appBar: AppBar(title: Text(d.elderName)),
      // 「幫長輩報名活動」固定在畫面底部，不跟著內容捲動
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(
            color: TPColors.grayscale50,
            border: Border(top: BorderSide(color: TPColors.grayscale100)),
          ),
          child: d.has('BOOK_SERVICE')
              ? BigButton(icon: Icons.add_circle, label: '幫長輩報名活動', color: TPColors.primary500, onPressed: _book)
              : const Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(leading: Icon(Icons.lock), title: Text('長輩沒有授權您代為報名')),
                ),
        ),
      ),
      body: FutureBuilder<List<BookingInfo>>(
        future: _bookings,
        builder: (context, snap) {
          final list = snap.data ?? const <BookingInfo>[];
          final shown = list.where(_matches).toList();
          final searching = _query.trim().isNotEmpty;
          return CustomScrollView(slivers: [
            // ---- 基本資料（會捲走）----
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('基本資料'),
                  AsyncView<ElderProfile>(
                    future: _profile,
                    errorBuilder: _lockedCard,
                    builder: (p) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Avatar(p.name, size: 52),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.name, style: TPText.title),
                                if (p.ageGroupLabel != null)
                                  Text('${p.age} 歲・${p.ageGroupLabel}',
                                      style: TPText.body.copyWith(color: TPColors.grayscale500)),
                              ]),
                            ),
                          ]),
                          const Divider(height: 24),
                          _infoRow(Icons.cake_outlined, '生日', p.birthday ?? '-'),
                          _infoRow(Icons.place_outlined, '行政區', p.district ?? '-'),
                          _infoRow(Icons.phone_outlined, '電話', p.phone ?? '-'),
                          _infoRow(Icons.credit_card, '敬老卡點數', '${p.seniorCardPoints ?? '-'} 點'),
                          if (p.dataNote != null)
                            Text(p.dataNote!, style: const TextStyle(fontSize: 12, color: TPColors.grayscale500)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            // ---- 據點活動報名＋搜尋列：往下滑到這裡就固定在最上方，往上滑會跟著回去 ----
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeader(
                height: _pinnedHeight(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SectionTitle('據點活動報名'),
                    _searchBox(list),
                    if (searching)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                        child: Text('「${_query.trim()}」找到 ${shown.length} 筆', style: TPText.body),
                      ),
                  ]),
                ),
              ),
            ),
            // ---- 已報名 / 已取消（下拉式選單）----
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverToBoxAdapter(
                child: snap.hasError
                    ? _lockedCard(snap.error!)
                    : snap.connectionState != ConnectionState.done && snap.data == null
                        ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                        : Column(children: [
                            _bookingGroup('已報名', Icons.event_available, TPColors.primary700,
                                shown.where((b) => !b.isCancelled).toList(),
                                searching ? '沒有符合的活動' : '目前沒有報名的活動',
                                expanded: true),
                            _bookingGroup('已取消', Icons.event_busy, TPColors.grayscale600,
                                shown.where((b) => b.isCancelled).toList(),
                                searching ? '沒有符合的活動' : '沒有取消的活動',
                                expanded: searching),
                          ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// 固定在捲動區上方的區塊（SliverPersistentHeader 用）。
class _PinnedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedHeader({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: TPColors.grayscale50,
        // 固定住的時候底下加一條線，和下面捲動的內容分開
        border: overlapsContent || shrinkOffset > 0
            ? const Border(bottom: BorderSide(color: TPColors.grayscale100))
            : null,
      ),
      child: ClipRect(child: OverflowBox(alignment: Alignment.topLeft, maxHeight: double.infinity, child: child)),
    );
  }

  @override
  bool shouldRebuild(_PinnedHeader old) => true;
}

// =====================================================================
// 幫長輩找活動：只列出符合長輩年齡層的活動，依類型、行政區篩選
// =====================================================================
class ActivityPickerPage extends StatefulWidget {
  final DelegationApi api;
  final int elderId;
  final String elderName;

  const ActivityPickerPage({super.key, required this.api, required this.elderId, required this.elderName});

  @override
  State<ActivityPickerPage> createState() => _ActivityPickerPageState();
}

class _ActivityPickerPageState extends State<ActivityPickerPage> {
  String? _category;
  bool _elderDistrict = true;
  late Future<ActivityList> _future = _load()
    ..then((_) {
      if (mounted) setState(() {}); // 標題、行政區要等資料回來才知道
    }, onError: (_) {});
  ActivityList? _data;

  static const _categories = [
    (null, '全部', Icons.apps),
    ('HEALTH', '健康促進', Icons.directions_run),
    ('LEARNING', '樂齡學習', Icons.menu_book),
    ('LEISURE', '休閒娛樂', Icons.palette),
    ('MEAL', '共餐服務', Icons.restaurant),
    ('SOCIAL', '社交聯誼', Icons.diversity_3),
  ];

  Future<ActivityList> _load() async {
    // 第一次先拿長輩的行政區，之後依「長輩住的區 / 全臺北市」篩選
    final district = _elderDistrict ? _data?.district : null;
    var d = await widget.api.activities(widget.elderId, category: _category, district: district);
    if (_elderDistrict && _data == null && d.district != null) {
      d = await widget.api.activities(widget.elderId, category: _category, district: d.district);
    }
    _data = d;
    return d;
  }

  void _reload() {
    final f = _load();
    f.then((_) {
      if (mounted) setState(() => _future = f);
    }, onError: (_) {});
  }

  Widget _card(ActivityInfo a) {
    return FolderCard(
      tab: TabChip(a.categoryLabel, categoryIcon(a.category)),
      trailing: StatusTag(text: a.ageLabel, color: TPColors.primary700, background: TPColors.primary100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a.title, style: TPText.title),
        if (a.description != null)
          Padding(padding: const EdgeInsets.only(top: 2), child: Text(a.description!, style: TPText.body)),
        const SizedBox(height: 8),
        _info(Icons.home_work_outlined, a.servicePointName),
        if (a.schedule != null) _info(Icons.schedule, a.schedule!),
        if (a.address != null) _info(Icons.place_outlined, a.address!),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: a.isBooked
              ? OutlinedButton(
                  onPressed: null,
                  child: Text(a.bookingStatus == 'PENDING_ELDER' ? '已報名・等長輩確認' : '長輩已報名'),
                )
              : FilledButton.icon(
                  onPressed: () => Navigator.pop(context, a),
                  icon: const Icon(Icons.add),
                  label: Text('幫${widget.elderName}報名'),
                ),
        ),
      ]),
    );
  }

  Widget _info(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: TPColors.grayscale500),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TPText.body)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('幫長輩找活動')),
      body: Column(children: [
        PageHeader(
          title: '適合${widget.elderName}的活動',
          subtitle: d?.age == null ? '依長輩年齡篩選' : '依長輩 ${d!.age} 歲・${d.ageGroupLabel} 篩選，只顯示適合的活動',
        ),
        PillSelector<String?>(
          options: [for (final c in _categories) (c.$1, c.$2, c.$3)],
          selected: _category,
          onSelected: (v) {
            setState(() => _category = v);
            _reload();
          },
        ),
        const SizedBox(height: 8),
        PillSelector<bool>(
          options: [
            (true, '長輩住的${d?.district ?? '區'}', Icons.home_outlined),
            (false, '全臺北市', Icons.location_city),
          ],
          selected: _elderDistrict,
          onSelected: (v) {
            setState(() => _elderDistrict = v);
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
                    title: '沒有符合的活動',
                    message: d.hiddenByConflict > 0
                        ? '有 ${d.hiddenByConflict} 個和已報名活動時間衝突，取消報名後會出現'
                        : '換別的類型或看全臺北市',
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: d.activities.length + 2,
                itemBuilder: (_, i) => i == 0
                    ? ConflictNote(d.hiddenByConflict)
                    : i - 1 == d.activities.length
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('資料來源：${d.source}', style: TPText.caption.copyWith(fontWeight: FontWeight.w400)),
                          )
                        : _card(d.activities[i - 1]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// 通知：長輩確認 / 取消了家屬代為報名的活動
// =====================================================================
class NoticesPage extends StatefulWidget {
  final DelegationApi api;

  const NoticesPage({super.key, required this.api});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  late final Future<List<NoticeInfo>> _future = widget.api.notices().then((list) {
    // 打開就算讀過；畫面上還是用剛剛的未讀狀態標出「新」
    if (list.any((n) => !n.read)) NoticeCenter.instance.markAllRead();
    return list;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: AsyncView<List<NoticeInfo>>(
        future: _future,
        builder: (list) => list.isEmpty
            ? const Center(child: Text('目前沒有通知', style: TextStyle(color: TPColors.grayscale600)))
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final n in list)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: n.isConfirmed ? TPColors.primary50 : TPColors.red50,
                          child: Icon(n.isConfirmed ? Icons.event_available : Icons.event_busy,
                              color: n.isConfirmed ? TPColors.primary700 : TPColors.red600),
                        ),
                        title: Row(children: [
                          Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                          if (!n.read) const StatusTag(text: '新', color: TPColors.white, background: TPColors.red500),
                        ]),
                        subtitle: Text('${n.message}\n${fmtTime(n.createdAt)}'),
                        isThreeLine: true,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// =====================================================================
// 我照顧的長輩（從首頁「照顧的長輩」數字點進來）
// =====================================================================
class CaredEldersPage extends StatelessWidget {
  final DelegationApi api;
  final List<Delegation> delegations;

  const CaredEldersPage({super.key, required this.api, required this.delegations});

  @override
  Widget build(BuildContext context) {
    final active = delegations.where((d) => d.isActive).toList();
    final others = delegations.where((d) => !d.isActive).toList();
    Widget tile(Delegation d) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            leading: Avatar(d.elderName,
                size: 44, background: d.isActive ? TPColors.primary100 : TPColors.grayscale100,
                color: d.isActive ? TPColors.primary700 : TPColors.grayscale500),
            title: Text(d.elderName, style: TPText.title),
            subtitle: Text(
              d.isActive ? '授權到 ${fmtDate(d.expiresAt)}・可代辦 ${d.scopes.length} 項' : d.statusLabel,
              style: TPText.body,
            ),
            trailing: d.isActive ? const Icon(Icons.chevron_right) : null,
            onTap: d.isActive
                ? () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ElderDetailPage(api: api, delegation: d)))
                : null,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('照顧的長輩')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        SectionTitle('授權中（${active.length}）'),
        if (active.isEmpty) Text('目前沒有授權中的長輩', style: TPText.body),
        for (final d in active) tile(d),
        if (others.isNotEmpty) ...[
          SectionTitle('已結束（${others.length}）'),
          for (final d in others) tile(d),
        ],
      ]),
    );
  }
}

// =====================================================================
// 可代辦項目（從首頁「可代辦項目」數字點進來）：每位長輩授權了哪些事、到什麼時候
// =====================================================================
class DelegatedScopesPage extends StatelessWidget {
  final DelegationApi api;
  final List<Delegation> delegations;

  const DelegatedScopesPage({super.key, required this.api, required this.delegations});

  static IconData _icon(String code) => switch (code) {
        'VIEW_INFO' => Icons.badge_outlined,
        'BOOK_SERVICE' => Icons.event_available,
        _ => Icons.check_circle_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('可代辦項目')),
      body: delegations.isEmpty
          ? const Center(child: EmptyState(icon: Icons.lock_outline, title: '目前沒有可代辦的項目'))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              for (final d in delegations)
                FolderCard(
                  tab: TabChip(d.elderName, Icons.person_outline),
                  trailing: StatusTag(
                      text: '到 ${fmtDate(d.expiresAt)}', color: TPColors.primary700, background: TPColors.primary50),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ElderDetailPage(api: api, delegation: d))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final s in d.scopes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(color: TPColors.primary50, shape: BoxShape.circle),
                            child: Icon(_icon(s.code), size: 20, color: TPColors.primary700),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.label, style: TPText.h3)),
                        ]),
                      ),
                    const SizedBox(height: 4),
                    Text('點一下查看${d.elderName}的資料與報名', style: TPText.caption.copyWith(fontWeight: FontWeight.w400)),
                  ]),
                ),
            ]),
    );
  }
}
