package tw.taipei.codefest.delegation.controller;

import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;
import tw.taipei.codefest.delegation.controller.Dtos.ChooseRoleRequest;
import tw.taipei.codefest.delegation.controller.Dtos.HomeBundle;
import tw.taipei.codefest.delegation.controller.Dtos.MeView;
import tw.taipei.codefest.delegation.controller.Dtos.TownPassLoginRequest;
import tw.taipei.codefest.delegation.domain.AppUser;
import tw.taipei.codefest.delegation.service.AccountService;
import tw.taipei.codefest.delegation.web.AuthInterceptor;

/**
 * 台北通登入 → 判斷身分。
 *
 * 正式上線時，/auth/townpass 應改成驗證台北通發的 token，而不是直接相信前端傳來的帳號 id。
 * 黑客松版本直接使用台北通 userinfo 的 id（台北通 App 內 webview 透過 flutterObject 取得）。
 */
@RestController
@RequestMapping("/api")
public class AccountController {
    private final AccountService accounts;
    private final DelegationController delegations;
    private final ElderServiceController elderService;
    private final SyncController sync;

    public AccountController(AccountService accounts, DelegationController delegations,
                             ElderServiceController elderService, SyncController sync) {
        this.accounts = accounts;
        this.delegations = delegations;
        this.elderService = elderService;
        this.sync = sync;
    }

    /** 公開 API：用台北通帳號登入，回傳後端 user id 與身分。 */
    @PostMapping("/auth/townpass")
    public MeView login(@Valid @RequestBody TownPassLoginRequest body, jakarta.servlet.http.HttpServletRequest req) {
        AppUser u = accounts.loginWithTownPass(body.id(), body.realName(), body.birthday(),
                body.phoneNo(), body.district());
        // 依生日自動判定：65 歲（含）以上 → 長者，18–64 → 家屬
        u = accounts.autoAssignRole(u);
        // 首頁資料一起帶回去：手機透過 ngrok 時，每少一趟來回就快 0.5～2 秒
        HomeBundle home = null;
        if (u.role != null) {
            req.setAttribute(AuthInterceptor.CURRENT_USER, u); // 登入 API 是公開的，這裡補上「目前使用者」
            boolean elder = u.role == tw.taipei.codefest.delegation.domain.Enums.Role.ELDER;
            home = new HomeBundle(
                    elder ? delegations.pending(u) : java.util.List.of(),
                    delegations.mine(u),
                    elder ? elderService.listBookings(u.id, req) : java.util.List.of(),
                    sync.stamp(u));
        }
        return view(u, home);
    }

    @GetMapping("/me")
    public MeView me(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        return view(me);
    }

    /** 選擇身分頁按下「我是長輩 / 我是家屬」。 */
    @PostMapping("/me/role")
    public MeView chooseRole(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me,
                             @Valid @RequestBody ChooseRoleRequest body) {
        return view(accounts.chooseRole(me, body.role()));
    }

    /** 選錯身分時重選（沒有任何綁定才可以）。 */
    @PostMapping("/me/reset-role")
    public MeView resetRole(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        return view(accounts.resetRole(me));
    }

    private MeView view(AppUser u) {
        return view(u, null);
    }

    private MeView view(AppUser u, HomeBundle home) {
        var suggested = accounts.suggestedRole(u);
        Integer age = AccountService.age(u.birthday);
        var group = tw.taipei.codefest.delegation.domain.Enums.AgeGroup.of(age);
        return new MeView(u.id, u.name,
                u.role == null ? null : u.role.name(),
                accounts.isLinked(u),
                suggested == null ? null : suggested.name(),
                age,
                group == null ? null : group.name(),
                group == null ? null : group.fullLabel(),
                u.district,
                u.birthday,
                home);
    }
}
