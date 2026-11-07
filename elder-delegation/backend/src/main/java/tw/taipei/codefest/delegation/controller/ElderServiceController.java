package tw.taipei.codefest.delegation.controller;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import tw.taipei.codefest.delegation.controller.Dtos.*;
import tw.taipei.codefest.delegation.domain.*;
import tw.taipei.codefest.delegation.repo.*;
import tw.taipei.codefest.delegation.service.AccountService;
import tw.taipei.codefest.delegation.service.AuditService;
import tw.taipei.codefest.delegation.web.ApiException;
import tw.taipei.codefest.delegation.web.AuthInterceptor;
import tw.taipei.codefest.delegation.web.RequiresScope;
import tw.taipei.codefest.delegation.web.ScopeInterceptor;

import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 「代辦」的市政服務。長者本人和「有授權的家屬」共用同一組 API，
 * 權限全部交給 @RequiresScope 處理，這裡只寫業務邏輯。
 */
@RestController
@RequestMapping("/api/elders/{elderId}")
public class ElderServiceController {
    private final AppUserRepository users;
    private final BookingRepository bookings;
    private final ServicePointRepository points;
    private final ActionLogRepository logs;
    private final NoticeRepository notices;
    private final AuditService audit;
    private final ActivityRepository activities;

    /** 還「有效」的報名（重複報名檢查用）：取消掉的可以再報一次。 */
    private static final java.time.ZoneId TAIPEI = java.time.ZoneId.of("Asia/Taipei");

    private static final EnumSet<Enums.BookingStatus> LIVE =
            EnumSet.of(Enums.BookingStatus.PENDING_ELDER, Enums.BookingStatus.CONFIRMED);

    public ElderServiceController(AppUserRepository users, BookingRepository bookings,
                                  ServicePointRepository points, ActionLogRepository logs,
                                  NoticeRepository notices, AuditService audit, ActivityRepository activities) {
        this.users = users;
        this.bookings = bookings;
        this.points = points;
        this.logs = logs;
        this.notices = notices;
        this.audit = audit;
        this.activities = activities;
    }

    @GetMapping("/profile")
    @RequiresScope(Enums.Scope.VIEW_INFO)
    public ElderProfileView profile(@PathVariable Long elderId, HttpServletRequest req) {
        AppUser elder = loadElder(elderId);
        req.setAttribute(ScopeInterceptor.AUDIT_MESSAGE, actorName(req) + " 查看了您的基本資料");
        return ElderProfileView.of(elder);
    }

    @GetMapping("/bookings")
    @RequiresScope(Enums.Scope.VIEW_INFO)
    public List<BookingView> listBookings(@PathVariable Long elderId, HttpServletRequest req) {
        loadElder(elderId);
        req.setAttribute(ScopeInterceptor.AUDIT_MESSAGE, actorName(req) + " 查看了您的報名紀錄");
        List<Booking> list = bookings.findByElderIdOrderByIdDesc(elderId);
        Map<Long, ServicePoint> pointMap = points.findAllById(
                        list.stream().map(b -> b.servicePointId).collect(Collectors.toSet()))
                .stream().collect(Collectors.toMap(p -> p.id, Function.identity()));
        return list.stream().map(b -> toView(b, pointMap.get(b.servicePointId), elderId)).toList();
    }

    @PostMapping("/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    @RequiresScope(Enums.Scope.BOOK_SERVICE)
    public BookingView createBooking(@PathVariable Long elderId,
                                     @Valid @RequestBody CreateBookingRequest body,
                                     @RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me,
                                     HttpServletRequest req) {
        AppUser elder = loadElder(elderId);
        Activity act = null;
        if (body.activityId() != null) {
            act = activities.findById(body.activityId())
                    .orElseThrow(() -> ApiException.notFound("找不到這個活動"));
            // 依長輩年齡檢查：只能報名適合的活動
            Integer age = AccountService.age(elder.birthday);
            if (!act.fitsAge(age)) {
                throw ApiException.conflict("AGE_MISMATCH",
                        "「" + act.title + "」適合 " + act.ageLabel() + "，" + elder.name + " 目前 " + age + " 歲");
            }
        } else if (body.servicePointId() == null) {
            throw ApiException.badRequest("NO_TARGET", "請選擇要報名的活動");
        }
        Long pointId = act != null ? act.servicePointId : body.servicePointId();
        ServicePoint p = points.findById(pointId)
                .orElseThrow(() -> ApiException.notFound("找不到這個據點"));
        String label = act != null ? act.title + "（" + p.name + "）" : p.name;
        // 時間衝突：同一個時段已經報名（等長輩確認或已確認）別的活動，就不能再報名
        if (act != null) {
            for (Booking live : bookings.findByElderIdOrderByIdDesc(elderId)) {
                if (live.activityId == null || live.activityId.equals(act.id) || !LIVE.contains(live.statusOrDefault())) {
                    continue;
                }
                Activity other = activities.findById(live.activityId).orElse(null);
                if (other != null && other.conflictsWith(act)) {
                    throw ApiException.conflict("TIME_CONFLICT",
                            "這個時段（" + other.schedule + "）已經報名「" + other.title + "」，要先取消那個活動才能報名");
                }
            }
        }
        boolean dup = act != null
                ? bookings.existsByElderIdAndActivityIdAndStatusIn(elderId, act.id, LIVE)
                : bookings.existsByElderIdAndServicePointIdAndStatusIn(elderId, p.id, LIVE);
        if (dup) {
            throw ApiException.conflict("ALREADY_BOOKED", "已經報名過「" + label + "」了");
        }
        Booking b = new Booking();
        b.elderId = elderId;
        b.servicePointId = p.id;
        b.activityId = act != null ? act.id : null;
        b.bookedBy = me.id;
        b.note = body.note();
        // 雙重確認：家屬代為報名，要等長輩自己在「已報名活動清單」確認
        boolean byFamily = !me.id.equals(elderId);
        b.status = byFamily ? Enums.BookingStatus.PENDING_ELDER : Enums.BookingStatus.CONFIRMED;
        if (!byFamily) b.respondedAt = Instant.now();
        b = bookings.save(b);
        req.setAttribute(ScopeInterceptor.AUDIT_MESSAGE, me.name + " 幫您報名了「" + label + "」，等您確認");
        if (byFamily) {
            // 通知長輩：手機會跳出通知，請長輩到「已報名活動清單」確認
            notices.save(new Notice(elderId, elderId, b.id, "BOOKING_REQUESTED",
                    me.name + " 幫您報名了活動",
                    me.name + " 幫您報名了「" + label + "」，請到「已報名活動清單」確認要不要參加"));
        }
        return toView(b, p, elderId);
    }

    @DeleteMapping("/bookings/{bookingId}")
    @RequiresScope(Enums.Scope.BOOK_SERVICE)
    public Map<String, Object> cancelBooking(@PathVariable Long elderId, @PathVariable Long bookingId,
                                             HttpServletRequest req) {
        Booking b = bookings.findById(bookingId)
                .filter(x -> x.elderId.equals(elderId))
                .orElseThrow(() -> ApiException.notFound("找不到這筆報名"));
        String pointName = label(b);
        if (b.statusOrDefault() == Enums.BookingStatus.CANCELLED) {
            throw ApiException.conflict("ALREADY_CANCELLED", "「" + pointName + "」已經取消了");
        }
        // 保留紀錄，長輩在清單上看得到「已取消」
        b.status = Enums.BookingStatus.CANCELLED;
        b.respondedAt = Instant.now();
        bookings.save(b);
        req.setAttribute(ScopeInterceptor.AUDIT_MESSAGE, actorName(req) + " 幫您取消了「" + pointName + "」");
        AppUser actor = (AppUser) req.getAttribute(AuthInterceptor.CURRENT_USER);
        if (!actor.id.equals(elderId)) {
            notices.save(new Notice(elderId, elderId, b.id, "BOOKING_CANCELLED_BY_FAMILY",
                    actor.name + " 幫您取消了報名",
                    actor.name + " 幫您取消了「" + pointName + "」的報名"));
        }
        return Map.of("ok", true);
    }

    /** 長輩確認家屬代為報名的活動（雙重確認的第二步）。只有長輩本人可以按。 */
    @PostMapping("/bookings/{bookingId}/confirm")
    public BookingView confirmBooking(@PathVariable Long elderId, @PathVariable Long bookingId,
                                      @RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        Booking b = loadOwnBooking(elderId, bookingId, me);
        if (b.statusOrDefault() != Enums.BookingStatus.PENDING_ELDER) {
            throw ApiException.conflict("NOT_PENDING", "這個活動已經「" + b.statusOrDefault().label + "」了");
        }
        return respond(b, me, Enums.BookingStatus.CONFIRMED);
    }

    /** 長輩自己取消報名（不管是誰報的）。報名的家屬會收到通知。 */
    @PostMapping("/bookings/{bookingId}/cancel")
    public BookingView cancelByElder(@PathVariable Long elderId, @PathVariable Long bookingId,
                                     @RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        Booking b = loadOwnBooking(elderId, bookingId, me);
        if (b.statusOrDefault() == Enums.BookingStatus.CANCELLED) {
            throw ApiException.conflict("ALREADY_CANCELLED", "這個活動已經取消了");
        }
        return respond(b, me, Enums.BookingStatus.CANCELLED);
    }

    private Booking loadOwnBooking(Long elderId, Long bookingId, AppUser me) {
        if (!me.id.equals(elderId)) {
            throw ApiException.forbidden("ELDER_ONLY", "只有長輩本人可以確認或取消");
        }
        return bookings.findById(bookingId)
                .filter(x -> x.elderId.equals(elderId))
                .orElseThrow(() -> ApiException.notFound("找不到這筆報名"));
    }

    /** 改狀態、留紀錄，並通知當初報名的家屬。 */
    private BookingView respond(Booking b, AppUser elder, Enums.BookingStatus to) {
        ServicePoint p = points.findById(b.servicePointId).orElse(null);
        String pointName = label(b);
        b.status = to;
        b.respondedAt = Instant.now();
        bookings.save(b);

        boolean confirmed = to == Enums.BookingStatus.CONFIRMED;
        audit.log(elder.id, elder.id, null, confirmed ? "BOOKING_CONFIRMED" : "BOOKING_CANCELLED",
                confirmed ? "您確認參加「" + pointName + "」" : "您取消了「" + pointName + "」的報名");

        if (!b.bookedBy.equals(elder.id)) {
            notices.save(new Notice(b.bookedBy, elder.id, b.id,
                    confirmed ? "BOOKING_CONFIRMED" : "BOOKING_CANCELLED",
                    confirmed ? elder.name + " 確認參加活動" : elder.name + " 取消了報名",
                    confirmed
                            ? elder.name + " 確認參加您幫忙報名的「" + pointName + "」"
                            : elder.name + " 取消了您幫忙報名的「" + pointName + "」"));
        }
        return toView(b, p, elder.id);
    }

    /** 操作紀錄：只有長者本人能看（透明、可監督）。 */
    @GetMapping("/logs")
    public List<ActionLogView> logs(@PathVariable Long elderId,
                                    @RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        if (!me.id.equals(elderId)) {
            throw ApiException.forbidden("ELDER_ONLY", "只有長輩本人可以查看操作紀錄");
        }
        List<ActionLog> list = logs.findTop100ByElderIdOrderByIdDesc(elderId);
        Map<Long, String> names = users.findAllById(
                        list.stream().map(l -> l.actorId).collect(Collectors.toSet()))
                .stream().collect(Collectors.toMap(u -> u.id, u -> u.name));
        return list.stream()
                .map(l -> new ActionLogView(l.id, names.getOrDefault(l.actorId, "?"), l.action, l.message, l.createdAt))
                .toList();
    }

    // ---------- helpers ----------
    private AppUser loadElder(Long elderId) {
        AppUser u = users.findById(elderId).orElseThrow(() -> ApiException.notFound("找不到這位長輩"));
        if (u.role != Enums.Role.ELDER) {
            throw ApiException.notFound("找不到這位長輩");
        }
        return u;
    }

    private static String actorName(HttpServletRequest req) {
        return ((AppUser) req.getAttribute(AuthInterceptor.CURRENT_USER)).name;
    }

    /** 給人看的名稱：「肌力強化運動班（某某據點）」；沒有活動就只寫據點。 */
    private String label(Booking b) {
        String pointName = points.findById(b.servicePointId).map(p -> p.name).orElse("據點活動");
        if (b.activityId == null) return pointName;
        return activities.findById(b.activityId).map(a -> a.title + "（" + pointName + "）").orElse(pointName);
    }

    private BookingView toView(Booking b, ServicePoint p, Long elderId) {
        String byName = users.findById(b.bookedBy).map(u -> u.name).orElse("?");
        Activity a = b.activityId == null ? null : activities.findById(b.activityId).orElse(null);
        Activity.Session s = a == null ? null : a.nextSession(java.time.LocalDateTime.now(TAIPEI));
        return new BookingView(b.id, b.servicePointId,
                p != null ? p.name : "（據點已移除）",
                p != null ? p.address : null,
                byName, !b.bookedBy.equals(elderId), b.note, b.createdAt,
                b.statusOrDefault().name(), b.statusOrDefault().label, b.respondedAt,
                a == null ? null : a.id, a == null ? null : a.title,
                a == null ? null : a.category.name(), a == null ? null : a.category.label,
                a == null ? null : a.schedule,
                s == null ? null : s.date().toString(),
                s == null ? null : s.start().toString(),
                s == null ? null : s.end().toString());
    }
}
