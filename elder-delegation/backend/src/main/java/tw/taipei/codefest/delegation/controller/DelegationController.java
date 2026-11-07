package tw.taipei.codefest.delegation.controller;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import tw.taipei.codefest.delegation.controller.Dtos.*;
import tw.taipei.codefest.delegation.domain.AppUser;
import tw.taipei.codefest.delegation.domain.Delegation;
import tw.taipei.codefest.delegation.service.DelegationService;
import tw.taipei.codefest.delegation.web.AuthInterceptor;

import java.util.List;

@RestController
@RequestMapping("/api")
public class DelegationController {
    private final DelegationService service;

    public DelegationController(DelegationService service) {
        this.service = service;
    }

    /** 可勾選的授權範圍（給長者同意畫面用）。 */
    @GetMapping("/scopes")
    public List<ScopeView> scopes() {
        return ScopeView.all();
    }

    /** 長者：產生邀請碼。 */
    @PostMapping("/invitations")
    @ResponseStatus(HttpStatus.CREATED)
    public InvitationView createInvitation(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        return InvitationView.of(service.createInvitation(me));
    }

    /** 家屬：輸入邀請碼。 */
    @PostMapping("/invitations/accept")
    @ResponseStatus(HttpStatus.CREATED)
    public DelegationView accept(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me,
                                 @Valid @RequestBody AcceptInvitationRequest body) {
        return view(service.acceptInvitation(me, body.code()));
    }

    /** 我的授權（長者看到「誰在幫我」，家屬看到「我照顧的長輩」）。 */
    @GetMapping("/delegations")
    public List<DelegationView> mine(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        return service.listMine(me).stream().map(this::view).toList();
    }

    /** 長者：待同意的申請（邀請碼頁面每 3 秒查一次）。 */
    @GetMapping("/delegations/pending")
    public List<DelegationView> pending(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        return service.listPendingForElder(me).stream().map(this::view).toList();
    }

    @PostMapping("/delegations/{id}/approve")
    public DelegationView approve(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me,
                                  @PathVariable Long id,
                                  @Valid @RequestBody ApproveRequest body) {
        return view(service.approve(me, id, body.scopes(), body.days()));
    }

    @PostMapping("/delegations/{id}/reject")
    public DelegationView reject(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me,
                                 @PathVariable Long id) {
        return view(service.reject(me, id));
    }

    @PostMapping("/delegations/{id}/revoke")
    public DelegationView revoke(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me,
                                 @PathVariable Long id) {
        return view(service.revoke(me, id));
    }

    private DelegationView view(Delegation d) {
        return new DelegationView(
                d.id,
                d.elderId, service.userName(d.elderId),
                d.familyId, service.userName(d.familyId),
                d.scopes.stream().map(ScopeView::of).toList(),
                d.status.name(),
                d.expiresAt, d.createdAt);
    }
}
