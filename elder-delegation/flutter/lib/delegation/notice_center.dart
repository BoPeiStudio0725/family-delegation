import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'elder_pages.dart';
import 'family_pages.dart';
import 'models.dart';
import 'townpass/townpass_bridge.dart';
import 'tp_theme.dart';
import 'widgets.dart';

/// 整個 App 共用的 Navigator，讓通知橫幅在任何一頁都能跳出來。
final appNavigatorKey = GlobalKey<NavigatorState>();

/// 通知中心：登入後每 8 秒檢查一次新通知（長輩、家屬都一樣）。
///
/// 有新通知時：
/// 1. 請台北通跳出手機通知（和 IG 訊息一樣，從螢幕上方滑下來）
/// 2. App 裡也從上方滑下一條通知橫幅，點一下直接打開對應的頁面
/// 3. 長輩端會把通知唸出來
///
/// 另外也會檢查「版本戳記」：任何一方對活動或授權有新動作，開著的頁面都會自動更新。
///
/// 限制：要「家人代辦」頁面開著才會檢查（沒有伺服器推播）。
class NoticeCenter {
  NoticeCenter._();

  static final instance = NoticeCenter._();

  /// 目前的通知清單（頁面可以聽這個來更新畫面）。
  final ValueNotifier<List<NoticeInfo>> notices = ValueNotifier(const []);

  /// 家屬或長輩對活動 / 授權有新動作時 +1。頁面聽這個，自動重新整理。
  final ValueNotifier<int> changes = ValueNotifier(0);
  String? _stamp;

  DelegationApi? _api;
  bool _isElder = false;
  int? _lastSeenId;
  Timer? _timer;
  OverlayEntry? _banner;
  Timer? _bannerTimer;

  int get unreadCount => notices.value.where((n) => !n.read).length;

  /// [home]：登入時已經拿到的版本戳記和通知，有的話就不用馬上再問一次伺服器。
  void start(DelegationApi api, {required bool isElder, HomeBundle? home}) {
    stop();
    _api = api;
    _isElder = isElder;
    if (home != null && home.stamp.isNotEmpty) {
      _stamp = home.stamp;
      _lastSeenId = home.notices.isEmpty ? 0 : home.notices.first.id;
      notices.value = home.notices;
    } else {
      _lastSeenId = null;
      _stamp = null;
      notices.value = const [];
      refresh();
    }
    // 每 5 秒檢查一次：新通知、資料有沒有變
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _hideBanner();
  }

  Future<void> refresh() async {
    final api = _api;
    if (api == null) return;
    try {
      // 一個請求同時拿「版本戳記」和「通知」
      final (stamp, list) = await api.sync();
      // 資料有變 → 通知所有開著的頁面重新整理（第一次只記下戳記）
      if (_stamp != null && stamp != _stamp) changes.value++;
      _stamp = stamp;
      final firstLoad = _lastSeenId == null;
      final fresh = firstLoad ? <NoticeInfo>[] : list.where((n) => n.id > _lastSeenId! && !n.read).toList();
      _lastSeenId = list.isEmpty ? 0 : list.first.id;
      _setNotices(list);
      if (fresh.isNotEmpty) _announce(fresh);
    } catch (_) {}
  }

  /// 只有內容真的變了（新通知、已讀狀態）才更新，避免每 5 秒讓所有頁面重新整理。
  void _setNotices(List<NoticeInfo> list) {
    String sig(List<NoticeInfo> l) => l.map((n) => '${n.id}:${n.read}').join(',');
    if (sig(list) != sig(notices.value)) notices.value = list;
  }

  /// 全部標成已讀（打開清單時呼叫）。
  Future<void> markAllRead() async {
    final api = _api;
    if (api == null || unreadCount == 0) return;
    try {
      await api.markNoticesRead();
      notices.value = [for (final n in notices.value) n.asRead()];
    } catch (_) {}
  }

  void _announce(List<NoticeInfo> fresh) {
    // 1. 手機通知（在台北通裡才有）；舊的先送，最新的最後跳出來
    for (final n in fresh.reversed) {
      sendTownPassNotification(title: n.title, content: n.message);
    }
    // 2. App 內橫幅：只顯示最新一則，多則就寫「還有 N 則」
    final latest = fresh.first;
    _showBanner(latest, more: fresh.length - 1);
    HapticFeedback.mediumImpact();
  }

  void _open() {
    _hideBanner();
    final nav = appNavigatorKey.currentState;
    final api = _api;
    if (nav == null || api == null) return;
    if (_isElder) {
      nav.push(MaterialPageRoute(builder: (_) => ElderScale(child: BookingListPage(api: api, elderId: api.userId))));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => NoticesPage(api: api)));
    }
  }

  void _showBanner(NoticeInfo n, {int more = 0}) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _hideBanner();
    final entry = OverlayEntry(
      builder: (_) => _NoticeBanner(
        notice: n,
        more: more,
        large: _isElder,
        onTap: _open,
        onDismiss: _hideBanner,
      ),
    );
    _banner = entry;
    overlay.insert(entry);
    // 長輩停留久一點
    _bannerTimer = Timer(Duration(seconds: _isElder ? 10 : 6), _hideBanner);
  }

  void _hideBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _banner?.remove();
    _banner = null;
  }
}

/// 從螢幕上方滑下來的通知橫幅（仿手機 App 通知：圓角卡片、App 圖示、標題、內容、時間）。
/// 往上滑可以關掉，點一下打開對應頁面。
class _NoticeBanner extends StatefulWidget {
  final NoticeInfo notice;
  final int more;
  final bool large;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NoticeBanner({
    required this.notice,
    required this.more,
    required this.large,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<_NoticeBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();
  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0, -1.3), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  (IconData, Color) get _style {
    switch (widget.notice.type) {
      case 'BOOKING_REQUESTED':
        return (Icons.event_note, TPColors.secondary700);
      case 'BOOKING_CONFIRMED':
        return (Icons.event_available, TPColors.primary700);
      default:
        return (Icons.event_busy, TPColors.red600);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final (icon, color) = _style;
    final big = widget.large;
    // 長輩：放在標題列下面，不擋住右上角的「再聽一次」喇叭（長者 AppBar 高 88）
    final top = MediaQuery.of(context).padding.top + (big ? 92 : 8);
    return Positioned(
      top: top,
      left: 10,
      right: 10,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < 0) widget.onDismiss();
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap,
              child: Container(
                padding: EdgeInsets.all(big ? 14 : 12),
                decoration: BoxDecoration(
                  color: TPColors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(18),
                  border: big ? Border.all(color: TPColors.secondary500, width: 3) : null,
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
                  ],
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // App 圖示（台北通主色＋通知類型圖示）
                  Container(
                    width: big ? 52 : 42,
                    height: big ? 52 : 42,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(big ? 14 : 11)),
                    child: Icon(icon, color: TPColors.white, size: big ? 30 : 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('家人代辦',
                            style: TextStyle(
                                fontSize: big ? 14 : 12,
                                fontWeight: FontWeight.w600,
                                color: TPColors.grayscale500,
                                letterSpacing: 0.5)),
                        const Spacer(),
                        Text('現在', style: TextStyle(fontSize: big ? 14 : 12, color: TPColors.grayscale500)),
                      ]),
                      const SizedBox(height: 2),
                      Text(n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: big ? 20 : 15, fontWeight: FontWeight.w700, color: TPColors.grayscale900)),
                      const SizedBox(height: 2),
                      Text(n.message,
                          maxLines: big ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: big ? 17 : 14, color: TPColors.grayscale700, height: 1.3)),
                      if (widget.more > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('還有 ${widget.more} 則通知',
                              style: TextStyle(fontSize: big ? 15 : 12, color: TPColors.grayscale500)),
                        ),
                      if (big)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('點這裡去確認 ›',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: TPColors.primary700)),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
