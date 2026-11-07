package tw.taipei.codefest.delegation.controller;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import tw.taipei.codefest.delegation.domain.*;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** 所有 request / response 的格式集中在這裡，Flutter 端照這個寫 model。 */
public final class Dtos {
    private Dtos() {}

    // ----- requests -----
    public record AcceptInvitationRequest(
            @NotNull @Pattern(regexp = "\\d{6}", message = "請輸入 6 位數字") String code) {}

    public record ApproveRequest(
            @NotEmpty(message = "請至少勾選一項") Set<Enums.Scope> scopes,
            @Min(1) @Max(365) int days) {}

    /** 報名：給 activityId（活動場次）；舊版只給 servicePointId 也可以。 */
    public record CreateBookingRequest(Long servicePointId, Long activityId, String note) {}

    /** 台北通 userinfo 帶過來的欄位（名稱跟台北通 Account JSON 一樣）。 */
    public record TownPassLoginRequest(
            @NotNull(message = "缺少台北通帳號") String id,
            String realName,
            String birthday,
            String phoneNo,
            String district) {}

    public record ChooseRoleRequest(@NotNull(message = "請選擇身分") Enums.Role role) {}

    // ----- responses -----
    public record UserView(Long id, String name, String role) {
        public static UserView of(AppUser u) {
            return new UserView(u.id, u.name, u.role == null ? null : u.role.name());
        }
    }

    /**
     * 登入後前端用這個決定要進哪個介面：
     * role = ELDER → 長者介面；FAMILY → 家屬介面；null → 選擇身分頁（suggestedRole 是依生日的建議）。
     */
    /**
     * birthday：來自台北通（每次登入更新），身分依年齡自動判定。
     * home：只有登入時才帶，首頁要用的資料一次給齊（少一趟網路來回，打開比較快）；/me 是 null。
     */
    public record MeView(Long id, String name, String role, boolean linked, String suggestedRole,
                         Integer age, String ageGroup, String ageGroupLabel, String district, String birthday,
                         HomeBundle home) {}

    /** 首頁資料包：長者用 pending + bookings + delegations；家屬用 delegations；sync 是版本戳記＋通知。 */
    public record HomeBundle(List<DelegationView> pending, List<DelegationView> delegations,
                             List<BookingView> bookings, Map<String, Object> sync) {}

    public record ScopeView(String code, String label) {
        public static ScopeView of(Enums.Scope s) { return new ScopeView(s.name(), s.label); }

        public static List<ScopeView> all() { return Arrays.stream(Enums.Scope.values()).map(ScopeView::of).toList(); }
    }

    public record InvitationView(String code, Instant expiresAt) {
        public static InvitationView of(Invitation i) { return new InvitationView(i.code, i.expiresAt); }
    }

    public record DelegationView(Long id,
                                 Long elderId, String elderName,
                                 Long familyId, String familyName,
                                 List<ScopeView> scopes,
                                 String status,
                                 Instant expiresAt, Instant createdAt) {}

    /** 長者資料（敬老卡點數為模擬資料）。 */
    public record ElderProfileView(Long id, String name, String phone, String district,
                                   Integer seniorCardPoints, String dataNote,
                                   Integer age, String ageGroupLabel, String birthday) {
        public static ElderProfileView of(AppUser u) {
            Integer age = tw.taipei.codefest.delegation.service.AccountService.age(u.birthday);
            Enums.AgeGroup g = Enums.AgeGroup.of(age);
            return new ElderProfileView(u.id, u.name, u.phone, u.district, u.seniorCardPoints,
                    "敬老卡點數為黑客松模擬資料", age, g == null ? null : g.fullLabel(), u.birthday);
        }
    }

    /** status：PENDING_ELDER（待長輩確認）/ CONFIRMED / CANCELLED；statusLabel 是中文。 */
    public record BookingView(Long id, Long servicePointId, String servicePointName, String address,
                              String bookedByName, boolean bookedByFamily, String note, Instant createdAt,
                              String status, String statusLabel, Instant respondedAt,
                              Long activityId, String activityTitle, String category, String categoryLabel,
                              String schedule,
                              /* 下一次上課的日期與時間（依「每週X」推算，臺北時間），沒有排程是 null */
                              String sessionDate, String startTime, String endTime) {}

    public record CategoryView(String code, String label) {}

    public record ActivityView(Long id, String title, String category, String categoryLabel,
                               String ageLabel, String schedule, String description,
                               Long servicePointId, String servicePointName, String address, String district,
                               String phone, boolean sameDistrict, String bookingStatus, String source) {}

    /** 給某位長者的活動清單：age / ageGroupLabel 是長者的年齡層，activities 已依年齡篩選。 */
    public record ActivityListView(Long elderId, String elderName, Integer age, String ageGroup,
                                   String ageGroupLabel, String district,
                                   List<CategoryView> categories, List<ActivityView> activities,
                                   String source,
                                   /* 和已報名活動時間衝突、所以沒列出的活動數 */
                                   int hiddenByConflict) {}

    public record NoticeView(Long id, Long elderId, Long bookingId, String type, String title, String message,
                             boolean read, Instant createdAt) {
        public static NoticeView of(Notice n) {
            return new NoticeView(n.id, n.elderId, n.bookingId, n.type, n.title, n.message,
                    n.readAt != null, n.createdAt);
        }
    }

    public record ActionLogView(Long id, String actorName, String action, String message, Instant createdAt) {}
}
