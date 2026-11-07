// 對應後端 Dtos.java 的資料格式。

DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

String _two(int n) => n.toString().padLeft(2, '0');

/// 11/07 14:03
String fmtTime(DateTime? d) => d == null ? '' : '${d.month}/${d.day} ${_two(d.hour)}:${_two(d.minute)}';

/// 2026/12/07
String fmtDate(DateTime? d) => d == null ? '' : '${d.year}/${d.month}/${d.day}';

/// 登入後的自己。後端依「綁定關係」決定 role：
/// ELDER → 長者介面；FAMILY → 家屬介面；null → 還沒決定，顯示選擇身分頁。
class UserInfo {
  final int id;
  final String name;
  final String? role;

  /// 是否已經有綁定（等待同意或生效中）。已綁定就不能換身分。
  final bool linked;

  /// 依台北通生日給的建議（65 歲以上建議長輩），只是建議。
  final String? suggestedRole;

  /// 依台北通生日算的年齡與年齡層（65 歲含以上 = 長者、未滿 18 = 未成年）。
  final int? age;
  final String? ageGroup; // MINOR / ADULT / YOUNG_OLD / MIDDLE_OLD / OLDEST_OLD
  final String? ageGroupLabel; // 例如「樂齡長青（75–84 歲）」
  final String? district;

  /// 生日：來自台北通（設定 › 基本資料可以改），身分依年齡自動判定。
  final String? birthday;

  /// 登入時一起帶回來的首頁資料（/me 沒有）。
  final HomeBundle? home;

  UserInfo(this.id, this.name, this.role,
      {this.linked = false,
      this.suggestedRole,
      this.age,
      this.ageGroup,
      this.ageGroupLabel,
      this.district,
      this.birthday,
      this.home});

  bool get isElder => role == 'ELDER';
  bool get isFamily => role == 'FAMILY';
  bool get hasRole => role != null;
  bool get isMinor => ageGroup == 'MINOR';

  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
        j['id'] as int,
        j['name'] as String,
        j['role'] as String?,
        linked: j['linked'] as bool? ?? false,
        suggestedRole: j['suggestedRole'] as String?,
        age: j['age'] as int?,
        ageGroup: j['ageGroup'] as String?,
        ageGroupLabel: j['ageGroupLabel'] as String?,
        district: j['district'] as String?,
        birthday: j['birthday'] as String?,
        home: j['home'] == null ? null : HomeBundle.fromJson(j['home'] as Map<String, dynamic>),
      );
}

/// 首頁資料包：登入時一次拿齊，打開就能顯示（少一趟網路來回）。
class HomeBundle {
  final List<Delegation> pending;
  final List<Delegation> delegations;
  final List<BookingInfo> bookings;
  final String stamp;
  final List<NoticeInfo> notices;

  HomeBundle(this.pending, this.delegations, this.bookings, this.stamp, this.notices);

  factory HomeBundle.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
        [for (final e in (v as List? ?? const [])) f(e as Map<String, dynamic>)];
    final sync = j['sync'] as Map<String, dynamic>? ?? const {};
    return HomeBundle(
      list(j['pending'], Delegation.fromJson),
      list(j['delegations'], Delegation.fromJson),
      list(j['bookings'], BookingInfo.fromJson),
      '${sync['stamp'] ?? ''}',
      list(sync['notices'], NoticeInfo.fromJson),
    );
  }
}

class ScopeInfo {
  final String code;
  final String label;

  ScopeInfo(this.code, this.label);

  factory ScopeInfo.fromJson(Map<String, dynamic> j) => ScopeInfo(j['code'] as String, j['label'] as String);
}

class Invitation {
  final String code;
  final DateTime expiresAt;

  Invitation(this.code, this.expiresAt);

  factory Invitation.fromJson(Map<String, dynamic> j) => Invitation(j['code'] as String, _date(j['expiresAt'])!);
}

class Delegation {
  final int id;
  final int elderId;
  final String elderName;
  final int familyId;
  final String familyName;
  final List<ScopeInfo> scopes;
  final String status; // PENDING / ACTIVE / REJECTED / REVOKED / EXPIRED
  final DateTime? expiresAt;

  Delegation({
    required this.id,
    required this.elderId,
    required this.elderName,
    required this.familyId,
    required this.familyName,
    required this.scopes,
    required this.status,
    this.expiresAt,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isPending => status == 'PENDING';
  bool has(String scope) => scopes.any((s) => s.code == scope);

  String get statusLabel => const {
        'PENDING': '等待長輩同意',
        'ACTIVE': '授權中',
        'REJECTED': '長輩未同意',
        'REVOKED': '已收回',
        'EXPIRED': '已過期',
      }[status] ??
      status;

  factory Delegation.fromJson(Map<String, dynamic> j) => Delegation(
        id: j['id'] as int,
        elderId: j['elderId'] as int,
        elderName: j['elderName'] as String,
        familyId: j['familyId'] as int,
        familyName: j['familyName'] as String,
        scopes: (j['scopes'] as List).map((e) => ScopeInfo.fromJson(e as Map<String, dynamic>)).toList(),
        status: j['status'] as String,
        expiresAt: _date(j['expiresAt']),
      );
}

class ElderProfile {
  final int id;
  final String name;
  final String? phone;
  final String? district;
  final int? seniorCardPoints;
  final String? dataNote;
  final int? age;
  final String? ageGroupLabel;
  final String? birthday; // 來自台北通

  ElderProfile(this.id, this.name, this.phone, this.district, this.seniorCardPoints, this.dataNote,
      {this.age, this.ageGroupLabel, this.birthday});

  factory ElderProfile.fromJson(Map<String, dynamic> j) => ElderProfile(
        j['id'] as int,
        j['name'] as String,
        j['phone'] as String?,
        j['district'] as String?,
        j['seniorCardPoints'] as int?,
        j['dataNote'] as String?,
        age: j['age'] as int?,
        ageGroupLabel: j['ageGroupLabel'] as String?,
        birthday: j['birthday'] as String?,
      );
}

class ServicePoint {
  final int id;
  final String name;
  final String? type;
  final String? district;
  final String? address;
  final String? phone;
  final String source;

  ServicePoint(this.id, this.name, this.type, this.district, this.address, this.phone, this.source);

  factory ServicePoint.fromJson(Map<String, dynamic> j) => ServicePoint(
        j['id'] as int,
        j['name'] as String,
        j['type'] as String?,
        j['district'] as String?,
        j['address'] as String?,
        j['phone'] as String?,
        j['source'] as String,
      );
}

class BookingInfo {
  final int id;
  final String servicePointName;
  final String? address;
  final String bookedByName;
  final bool bookedByFamily;
  final DateTime? createdAt;

  /// PENDING_ELDER（待長輩確認）/ CONFIRMED / CANCELLED
  final String status;
  final String statusLabel;
  final DateTime? respondedAt;

  /// 報名的活動（舊資料可能沒有，只有據點）。
  final int? activityId;
  final String? activityTitle;
  final String? category;
  final String? categoryLabel;
  final String? schedule;

  /// 下一次上課的日期與時間（依「每週X」推算），沒有排程是 null。
  final DateTime? sessionDate;
  final String? startTime;
  final String? endTime;

  BookingInfo(this.id, this.servicePointName, this.address, this.bookedByName, this.bookedByFamily, this.createdAt,
      {this.status = 'CONFIRMED',
      this.statusLabel = '已確認',
      this.respondedAt,
      this.activityId,
      this.activityTitle,
      this.category,
      this.categoryLabel,
      this.schedule,
      this.sessionDate,
      this.startTime,
      this.endTime});

  /// 排序用：日期＋開始時間；沒有日期的排最後。
  DateTime get sortKey {
    final d = sessionDate;
    if (d == null) return DateTime(9999);
    final p = (startTime ?? '00:00').split(':');
    return DateTime(d.year, d.month, d.day, int.tryParse(p[0]) ?? 0, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  String get timeRange => startTime == null ? '' : '$startTime–${endTime ?? ''}';

  /// 主標題：有活動用活動名稱，沒有就用據點名稱。
  String get title => activityTitle ?? servicePointName;

  /// 唸 / 顯示用的完整名稱
  String get fullName => activityTitle == null ? servicePointName : '$activityTitle（$servicePointName）';

  bool get isPending => status == 'PENDING_ELDER';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isCancelled => status == 'CANCELLED';

  factory BookingInfo.fromJson(Map<String, dynamic> j) => BookingInfo(
        j['id'] as int,
        j['servicePointName'] as String,
        j['address'] as String?,
        j['bookedByName'] as String,
        j['bookedByFamily'] as bool,
        _date(j['createdAt']),
        status: j['status'] as String? ?? 'CONFIRMED',
        statusLabel: j['statusLabel'] as String? ?? '已確認',
        respondedAt: _date(j['respondedAt']),
        activityId: j['activityId'] as int?,
        activityTitle: j['activityTitle'] as String?,
        category: j['category'] as String?,
        categoryLabel: j['categoryLabel'] as String?,
        schedule: j['schedule'] as String?,
        sessionDate: j['sessionDate'] == null ? null : DateTime.parse(j['sessionDate'] as String),
        startTime: j['startTime'] as String?,
        endTime: j['endTime'] as String?,
      );
}

/// 給家屬的通知（長輩確認 / 取消了家屬代為報名的活動）。
class NoticeInfo {
  final int id;
  final int elderId;
  final String type; // BOOKING_CONFIRMED / BOOKING_CANCELLED
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;

  NoticeInfo(this.id, this.elderId, this.type, this.title, this.message, this.read, this.createdAt);

  bool get isConfirmed => type == 'BOOKING_CONFIRMED';

  NoticeInfo asRead() => NoticeInfo(id, elderId, type, title, message, true, createdAt);

  factory NoticeInfo.fromJson(Map<String, dynamic> j) => NoticeInfo(
        j['id'] as int,
        j['elderId'] as int,
        j['type'] as String,
        j['title'] as String,
        j['message'] as String? ?? '',
        j['read'] as bool,
        _date(j['createdAt']),
      );
}

class ActionLogEntry {
  final int id;
  final String actorName;
  final String action;
  final String message;
  final DateTime? createdAt;

  ActionLogEntry(this.id, this.actorName, this.action, this.message, this.createdAt);

  factory ActionLogEntry.fromJson(Map<String, dynamic> j) => ActionLogEntry(
        j['id'] as int,
        j['actorName'] as String,
        j['action'] as String,
        j['message'] as String,
        _date(j['createdAt']),
      );
}

/// 據點活動（依長者年齡篩選過）。
class ActivityInfo {
  final int id;
  final String title;
  final String category;
  final String categoryLabel;
  final String ageLabel;
  final String? schedule;
  final String? description;
  final int servicePointId;
  final String servicePointName;
  final String? address;
  final String? district;
  final String? phone;
  final bool sameDistrict;

  /// 已經報名的狀態（PENDING_ELDER / CONFIRMED），沒報名是 null。
  final String? bookingStatus;

  ActivityInfo({
    required this.id,
    required this.title,
    required this.category,
    required this.categoryLabel,
    required this.ageLabel,
    this.schedule,
    this.description,
    required this.servicePointId,
    required this.servicePointName,
    this.address,
    this.district,
    this.phone,
    this.sameDistrict = false,
    this.bookingStatus,
  });

  bool get isBooked => bookingStatus != null;

  factory ActivityInfo.fromJson(Map<String, dynamic> j) => ActivityInfo(
        id: j['id'] as int,
        title: j['title'] as String,
        category: j['category'] as String,
        categoryLabel: j['categoryLabel'] as String,
        ageLabel: j['ageLabel'] as String? ?? '',
        schedule: j['schedule'] as String?,
        description: j['description'] as String?,
        servicePointId: j['servicePointId'] as int,
        servicePointName: j['servicePointName'] as String,
        address: j['address'] as String?,
        district: j['district'] as String?,
        phone: j['phone'] as String?,
        sameDistrict: j['sameDistrict'] as bool? ?? false,
        bookingStatus: j['bookingStatus'] as String?,
      );
}

/// 某位長者的活動清單：年齡層＋活動類型＋活動。
class ActivityList {
  final int elderId;
  final String elderName;
  final int? age;
  final String? ageGroupLabel;
  final String? district;
  final List<ScopeInfo> categories; // code / label
  final List<ActivityInfo> activities;
  final String source;

  /// 和已報名活動時間衝突、所以沒列出的活動數（取消報名後會再出現）。
  final int hiddenByConflict;

  ActivityList(this.elderId, this.elderName, this.age, this.ageGroupLabel, this.district, this.categories,
      this.activities, this.source,
      {this.hiddenByConflict = 0});

  factory ActivityList.fromJson(Map<String, dynamic> j) => ActivityList(
        j['elderId'] as int,
        j['elderName'] as String,
        j['age'] as int?,
        j['ageGroupLabel'] as String?,
        j['district'] as String?,
        [for (final c in j['categories'] as List) ScopeInfo(c['code'] as String, c['label'] as String)],
        [for (final a in j['activities'] as List) ActivityInfo.fromJson(a as Map<String, dynamic>)],
        j['source'] as String? ?? '',
        hiddenByConflict: j['hiddenByConflict'] as int? ?? 0,
      );
}

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// 11/8（日）
String fmtDay(DateTime d) => '${d.month}/${d.day}（${_weekdays[d.weekday - 1]}）';

/// 11月8日星期日（給語音唸）
String speakDay(DateTime d) => '${d.month}月${d.day}日星期${_weekdays[d.weekday - 1]}';
