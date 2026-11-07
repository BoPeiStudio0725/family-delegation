package tw.taipei.codefest.delegation.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;
import tw.taipei.codefest.delegation.domain.AppUser;
import tw.taipei.codefest.delegation.domain.Delegation;
import tw.taipei.codefest.delegation.domain.Enums;
import tw.taipei.codefest.delegation.repo.DelegationRepository;
import tw.taipei.codefest.delegation.service.AuditService;

import java.util.Map;

/**
 * ★ 整個作品最重要的一段：統一的授權檢查 + 自動留紀錄。
 * 任何標了 @RequiresScope 的 API 都會經過這裡，不用在每個 controller 各寫一次。
 */
@Component
public class ScopeInterceptor implements HandlerInterceptor {
    /** controller 可以設定這個 request attribute，覆寫預設的紀錄文字。 */
    public static final String AUDIT_MESSAGE = "audit.message";
    private static final String DELEGATION = "audit.delegation";
    private static final String SCOPE = "audit.scope";

    private final DelegationRepository delegations;
    private final AuditService audit;

    public ScopeInterceptor(DelegationRepository delegations, AuditService audit) {
        this.delegations = delegations;
        this.audit = audit;
    }

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        if (!(handler instanceof HandlerMethod hm)) {
            return true;
        }
        RequiresScope rs = hm.getMethodAnnotation(RequiresScope.class);
        if (rs == null) {
            return true;
        }
        AppUser me = (AppUser) req.getAttribute(AuthInterceptor.CURRENT_USER);
        Long elderId = elderIdFromPath(req);

        // 長者本人：直接通過，不需授權、不留代辦紀錄
        if (me.id.equals(elderId)) {
            return true;
        }
        if (me.role != Enums.Role.FAMILY) {
            throw ApiException.forbidden("NOT_FAMILY", "只有家屬可以代辦");
        }

        Delegation d = delegations
                .findFirstByElderIdAndFamilyIdAndStatusOrderByIdDesc(elderId, me.id, Enums.DelegationStatus.ACTIVE)
                .orElseThrow(() -> ApiException.forbidden("NO_DELEGATION", "長輩目前沒有授權您代辦，或授權已被收回"));

        if (!d.isEffective()) {
            d.status = Enums.DelegationStatus.EXPIRED;
            delegations.save(d);
            throw ApiException.forbidden("DELEGATION_EXPIRED", "授權已過期，請長輩重新授權");
        }
        if (!d.scopes.contains(rs.value())) {
            throw ApiException.forbidden("SCOPE_DENIED", "長輩沒有授權您「" + rs.value().label + "」");
        }

        req.setAttribute(DELEGATION, d);
        req.setAttribute(SCOPE, rs.value());
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest req, HttpServletResponse res, Object handler, Exception ex) {
        Delegation d = (Delegation) req.getAttribute(DELEGATION);
        if (d == null || ex != null || res.getStatus() >= 400) {
            return;
        }
        AppUser me = (AppUser) req.getAttribute(AuthInterceptor.CURRENT_USER);
        Enums.Scope scope = (Enums.Scope) req.getAttribute(SCOPE);
        Object custom = req.getAttribute(AUDIT_MESSAGE);
        String message = custom != null
                ? custom.toString()
                : me.name + " 使用了「" + scope.label + "」";
        audit.log(d.elderId, me.id, d.id, "DELEGATED_" + scope.name(), message);
    }

    @SuppressWarnings("unchecked")
    private Long elderIdFromPath(HttpServletRequest req) {
        Map<String, String> vars =
                (Map<String, String>) req.getAttribute(HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE);
        if (vars == null || !vars.containsKey("elderId")) {
            throw new IllegalStateException("@RequiresScope 的路徑必須包含 {elderId}");
        }
        try {
            return Long.parseLong(vars.get("elderId"));
        } catch (NumberFormatException e) {
            throw ApiException.badRequest("BAD_ELDER_ID", "長者編號不正確");
        }
    }
}
