package tw.taipei.codefest.delegation.controller;

import org.springframework.web.bind.annotation.*;
import tw.taipei.codefest.delegation.controller.Dtos.*;
import tw.taipei.codefest.delegation.domain.*;
import tw.taipei.codefest.delegation.repo.*;
import tw.taipei.codefest.delegation.service.AccountService;
import tw.taipei.codefest.delegation.service.ActivitySeeder;
import tw.taipei.codefest.delegation.web.ApiException;
import tw.taipei.codefest.delegation.web.AuthInterceptor;

import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 依長者年齡篩選的據點活動。
 * - 長者本人：「建議活動」，同一區的排前面
 * - 家屬（有生效中的授權）：幫長輩報名時，只看長輩年齡適合的活動
 * 可再用 category（活動類型）、district（行政區）篩選。
 */
@RestController
@RequestMapping("/api/elders/{elderId}/activities")
public class ActivityController {
    private static final int LIMIT = 200;
    private static final EnumSet<Enums.BookingStatus> LIVE =
            EnumSet.of(Enums.BookingStatus.PENDING_ELDER, Enums.BookingStatus.CONFIRMED);

    private final AppUserRepository users;
    private final ActivityRepository activities;
    private final ServicePointRepository points;
    private final BookingRepository bookings;
    private final DelegationRepository delegations;

    public ActivityController(AppUserRepository users, ActivityRepository activities, ServicePointRepository points,
                              BookingRepository bookings, DelegationRepository delegations) {
        this.users = users;
        this.activities = activities;
        this.points = points;
        this.bookings = bookings;
        this.delegations = delegations;
    }

    @GetMapping
    public ActivityListView list(@PathVariable Long elderId,
                                 @RequestParam(required = false) String category,
                                 @RequestParam(required = false) String district,
                                 @RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        AppUser elder = users.findById(elderId)
                .filter(u -> u.role == Enums.Role.ELDER)
                .orElseThrow(() -> ApiException.notFound("找不到這位長輩"));
        // 長輩本人，或有生效中授權的家屬
        if (!me.id.equals(elderId) && delegations
                .findFirstByElderIdAndFamilyIdAndStatusOrderByIdDesc(elderId, me.id, Enums.DelegationStatus.ACTIVE)
                .filter(Delegation::isEffective).isEmpty()) {
            throw ApiException.forbidden("NO_DELEGATION", "長輩目前沒有授權您代辦，或授權已被收回");
        }

        Integer age = AccountService.age(elder.birthday);
        Enums.AgeGroup group = Enums.AgeGroup.of(age);
        Enums.ActivityCategory cat = parseCategory(category);
        Map<Long, ServicePoint> pointMap = points.findAll().stream()
                .collect(Collectors.toMap(p -> p.id, Function.identity()));
        Map<Long, Enums.BookingStatus> booked = bookings.findByElderIdOrderByIdDesc(elderId).stream()
                .filter(b -> b.activityId != null && LIVE.contains(b.statusOrDefault()))
                .collect(Collectors.toMap(b -> b.activityId, Booking::statusOrDefault, (x, y) -> x));
        String home = elder.district;

        // 已報名（等長輩確認＋已確認）的活動：同一個時段的其他活動不再列出，取消後才會出現
        List<Activity> bookedActs = activities.findAllById(booked.keySet());
        int[] hidden = {0};

        List<ActivityView> list = activities.findAll().stream()
                .filter(a -> a.fitsAge(age))
                .filter(a -> cat == null || a.category == cat)
                .filter(a -> {
                    ServicePoint p = pointMap.get(a.servicePointId);
                    return p != null && (district == null || district.isBlank() || district.equals(p.district));
                })
                .filter(a -> {
                    if (booked.containsKey(a.id)) return true; // 自己報名的那個仍顯示「已報名」
                    boolean conflict = bookedActs.stream().anyMatch(b -> b.conflictsWith(a));
                    if (conflict) hidden[0]++;
                    return !conflict;
                })
                // 同區的排前面，再依類型、名稱
                .sorted(Comparator.<Activity, Boolean>comparing(a -> !Objects.equals(home, pointMap.get(a.servicePointId).district))
                        .thenComparing(a -> a.category.ordinal())
                        .thenComparing(a -> pointMap.get(a.servicePointId).name))
                .limit(LIMIT)
                .map(a -> {
                    ServicePoint p = pointMap.get(a.servicePointId);
                    Enums.BookingStatus st = booked.get(a.id);
                    return new ActivityView(a.id, a.title, a.category.name(), a.category.label, a.ageLabel(),
                            a.schedule, a.description, p.id, p.name, p.address, p.district, p.phone,
                            Objects.equals(home, p.district), st == null ? null : st.name(), a.source);
                })
                .toList();

        List<CategoryView> cats = Arrays.stream(Enums.ActivityCategory.values())
                .map(c -> new CategoryView(c.name(), c.label)).toList();
        return new ActivityListView(elder.id, elder.name, age,
                group == null ? null : group.name(), group == null ? null : group.fullLabel(),
                home, cats, list, ActivitySeeder.SOURCE + "；據點：臺北市社區照顧關懷據點（data.taipei 開放資料）",
                hidden[0]);
    }

    private static Enums.ActivityCategory parseCategory(String s) {
        if (s == null || s.isBlank()) return null;
        try {
            return Enums.ActivityCategory.valueOf(s.trim());
        } catch (IllegalArgumentException e) {
            throw ApiException.badRequest("BAD_CATEGORY", "沒有這種活動類型");
        }
    }
}
