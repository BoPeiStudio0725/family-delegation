package tw.taipei.codefest.delegation.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tw.taipei.codefest.delegation.domain.AppUser;
import tw.taipei.codefest.delegation.domain.Enums;
import tw.taipei.codefest.delegation.repo.AppUserRepository;
import tw.taipei.codefest.delegation.repo.DelegationRepository;
import tw.taipei.codefest.delegation.web.ApiException;

import java.time.LocalDate;
import java.time.Period;
import java.util.List;

/**
 * 台北通登入與身分判斷。
 *
 * 判斷規則：
 * 1. 第一次進來 role = null → 前端顯示「選擇身分」頁（依生日給建議，65 歲以上建議長輩）
 * 2. 長輩產生邀請碼、家屬輸入邀請碼時，身分就會被記下來
 * 3. 之後再從台北通進來 → 直接依 role 進入長者或家屬介面
 * 4. 已經有綁定（等待中或生效中）就不能換身分，避免關係錯亂
 */
@Service
public class AccountService {
    public static final int ELDER_AGE = 65;
    private static final List<Enums.DelegationStatus> LIVE =
            List.of(Enums.DelegationStatus.PENDING, Enums.DelegationStatus.ACTIVE);

    private final AppUserRepository users;
    private final DelegationRepository delegations;

    public AccountService(AppUserRepository users, DelegationRepository delegations) {
        this.users = users;
        this.delegations = delegations;
    }

    /** 用台北通帳號登入：沒有就建立，有就更新姓名等基本資料。 */
    @Transactional
    public AppUser loginWithTownPass(String townpassId, String realName, String birthday,
                                     String phone, String district) {
        if (townpassId == null || townpassId.isBlank()) {
            throw ApiException.badRequest("NO_TOWNPASS_ID", "沒有拿到台北通帳號，請從台北通重新進入");
        }
        AppUser u = users.findByTownpassId(townpassId.trim()).orElseGet(AppUser::new);
        u.townpassId = townpassId.trim();
        if (realName != null && !realName.isBlank()) u.name = realName.trim();
        if (u.name == null) u.name = "台北通使用者";
        // 生日以台北通為準：在台北通「設定 › 基本資料」改了生日，下次打開家人代辦就跟著變，
        // 介面也會依年齡自動切換（65 歲含以上 → 長者、18–64 → 家屬）
        if (birthday != null && !birthday.isBlank()) u.birthday = birthday.trim();
        if (phone != null && !phone.isBlank()) u.phone = phone.trim();
        if (district != null && !district.isBlank()) u.district = district.trim();
        return users.save(u);
    }

    /** 是否已經有綁定（等待同意或生效中）。 */
    public boolean isLinked(AppUser u) {
        return delegations.existsByElderIdAndStatusIn(u.id, LIVE)
                || delegations.existsByFamilyIdAndStatusIn(u.id, LIVE);
    }

    public static final int ADULT_AGE = 18;

    /**
     * 依生日自動判定身分（每次登入都檢查，生日改了介面就跟著換）：
     * 65 歲（含）以上 → 長者；18–64 歲 → 家屬；未滿 18 歲 → 不指定（不能當家屬）。
     * 生日讀不到就維持原本的身分（沒有身分時，前端顯示選擇身分頁）。
     *
     * 已經綁定的人也會跟著年齡切換。切換後原本的綁定仍保留：
     * 例如長輩改成 63 歲變成家屬，他原本的家人暫時看不到他的資料；生日改回 65 歲以上就恢復。
     */
    @Transactional
    public AppUser autoAssignRole(AppUser u) {
        Enums.AgeGroup g = Enums.AgeGroup.of(age(u.birthday));
        if (g == null) return u;
        Enums.Role target = g == Enums.AgeGroup.MINOR ? null : (g.isElder() ? Enums.Role.ELDER : Enums.Role.FAMILY);
        if (u.role == target) return u;
        u.role = target;
        if (u.role == Enums.Role.ELDER && u.seniorCardPoints == null) {
            u.seniorCardPoints = 480; // 模擬資料
        }
        return users.save(u);
    }

    /** 未滿 18 歲不能擔任家屬。 */
    public void requireAdultForFamily(AppUser u) {
        Integer a = age(u.birthday);
        if (a != null && a < ADULT_AGE) {
            throw ApiException.forbidden("MINOR", "未滿 18 歲不能擔任家屬，請請成年家人協助");
        }
    }

    /** 依生日建議身分（只是建議，使用者自己選）。 */
    public Enums.Role suggestedRole(AppUser u) {
        Integer age = age(u.birthday);
        if (age == null) return null;
        return age >= ELDER_AGE ? Enums.Role.ELDER : Enums.Role.FAMILY;
    }

    /** 使用者在「選擇身分」頁自己選；已經綁定就不能換。 */
    @Transactional
    public AppUser chooseRole(AppUser me, Enums.Role role) {
        if (role == null) {
            throw ApiException.badRequest("NO_ROLE", "請選擇身分");
        }
        if (role == Enums.Role.FAMILY) requireAdultForFamily(me);
        if (me.role != null && me.role != role && isLinked(me)) {
            throw ApiException.conflict("ALREADY_LINKED",
                    "您已經和家人綁定，不能更換身分。請先在「誰在幫我」或首頁解除綁定");
        }
        me.role = role;
        if (role == Enums.Role.ELDER && me.seniorCardPoints == null) {
            me.seniorCardPoints = 480; // 模擬資料
        }
        return users.save(me);
    }

    /** 回到「還沒決定身分」，只有沒有任何綁定時可以。 */
    @Transactional
    public AppUser resetRole(AppUser me) {
        if (isLinked(me)) {
            throw ApiException.conflict("ALREADY_LINKED", "您已經和家人綁定，不能更換身分");
        }
        me.role = null;
        return users.save(me);
    }

    /** 1950/03/02、1950-03-02 都接受；格式不對就回 null。 */
    public static Integer age(String birthday) {
        if (birthday == null) return null;
        String[] p = birthday.trim().split("[/\\-.]");
        if (p.length < 3) return null;
        try {
            LocalDate d = LocalDate.of(Integer.parseInt(p[0]), Integer.parseInt(p[1]), Integer.parseInt(p[2]));
            return Period.between(d, LocalDate.now()).getYears();
        } catch (RuntimeException e) {
            return null;
        }
    }
}
