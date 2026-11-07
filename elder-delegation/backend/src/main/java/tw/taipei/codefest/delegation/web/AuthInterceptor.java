package tw.taipei.codefest.delegation.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import tw.taipei.codefest.delegation.domain.AppUser;
import tw.taipei.codefest.delegation.repo.AppUserRepository;

/**
 * 黑客松版身分識別：讀 X-User-Id header。
 * 正式上線時換成台北通登入後的 token 驗證，其餘程式碼都不用改。
 */
@Component
public class AuthInterceptor implements HandlerInterceptor {
    public static final String CURRENT_USER = "currentUser";

    private final AppUserRepository users;

    public AuthInterceptor(AppUserRepository users) {
        this.users = users;
    }

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        if (!(handler instanceof HandlerMethod)) {
            return true; // CORS preflight 等
        }
        String raw = req.getHeader("X-User-Id");
        if (raw == null || raw.isBlank()) {
            throw ApiException.unauthorized("請先登入");
        }
        long id;
        try {
            id = Long.parseLong(raw.trim());
        } catch (NumberFormatException e) {
            throw ApiException.unauthorized("登入資訊不正確");
        }
        AppUser me = users.findById(id).orElseThrow(() -> ApiException.unauthorized("找不到此使用者"));
        req.setAttribute(CURRENT_USER, me);
        return true;
    }
}
