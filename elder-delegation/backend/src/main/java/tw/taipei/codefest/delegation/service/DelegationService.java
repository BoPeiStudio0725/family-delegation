package tw.taipei.codefest.delegation.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tw.taipei.codefest.delegation.domain.*;
import tw.taipei.codefest.delegation.repo.AppUserRepository;
import tw.taipei.codefest.delegation.repo.DelegationRepository;
import tw.taipei.codefest.delegation.repo.InvitationRepository;
import tw.taipei.codefest.delegation.web.ApiException;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/** 邀請碼與授權的完整生命週期：產生 → 綁定申請 → 同意/拒絕 → 撤回。 */
@Service
public class DelegationService {
    private static final SecureRandom RANDOM = new SecureRandom();

    private final InvitationRepository invitations;
    private final DelegationRepository delegations;
    private final AppUserRepository users;
    private final AuditService audit;
    private final Duration invitationTtl;

    public DelegationService(InvitationRepository invitations,
                             DelegationRepository delegations,
                             AppUserRepository users,
                             AuditService audit,
                             @Value("${app.invitation-ttl-minutes:10}") long ttlMinutes) {
        this.invitations = invitations;
        this.delegations = delegations;
        this.users = users;
        this.audit = audit;
        this.invitationTtl = Duration.ofMinutes(ttlMinutes);
    }

    // ---------- 1. 長者產生邀請碼 ----------
    @Transactional
    public Invitation createInvitation(AppUser me) {
        // 第一次產生邀請碼 → 記下這個人是長輩
        claimRole(me, Enums.Role.ELDER, "您目前是家屬身分，不能產生邀請碼");
        String code;
        do {
            code = String.format("%06d", RANDOM.nextInt(1_000_000));
        } while (invitations.existsByCodeAndStatus(code, Enums.InvitationStatus.PENDING));

        Invitation inv = new Invitation();
        inv.code = code;
        inv.elderId = me.id;
        inv.expiresAt = Instant.now().plus(invitationTtl);
        return invitations.save(inv);
    }

    // ---------- 2. 家屬輸入邀請碼 → 建立待同意的授權 ----------
    @Transactional
    public Delegation acceptInvitation(AppUser me, String code) {
        if (me.role == Enums.Role.ELDER) {
            throw ApiException.forbidden("WRONG_ROLE", "您目前是長輩身分，不能輸入邀請碼");
        }
        Invitation inv = invitations
                .findFirstByCodeAndStatusOrderByIdDesc(code, Enums.InvitationStatus.PENDING)
                .orElseThrow(() -> ApiException.notFound("邀請碼不存在或已使用"));
        if (inv.elderId.equals(me.id)) {
            throw ApiException.badRequest("SELF_BIND", "不能綁定自己");
        }
        // 未滿 18 歲不能擔任家屬
        Integer myAge = AccountService.age(me.birthday);
        if (myAge != null && myAge < AccountService.ADULT_AGE) {
            throw ApiException.forbidden("MINOR", "未滿 18 歲不能擔任家屬，請請成年家人協助");
        }
        // 第一次輸入邀請碼 → 記下這個人是家屬
        claimRole(me, Enums.Role.FAMILY, "您目前是長輩身分，不能輸入邀請碼");
        if (!inv.isUsable()) {
            inv.status = Enums.InvitationStatus.EXPIRED;
            invitations.save(inv);
            throw ApiException.badRequest("INVITATION_EXPIRED", "邀請碼已過期，請長輩重新產生");
        }
        if (delegations.existsByElderIdAndFamilyIdAndStatusIn(inv.elderId, me.id,
                List.of(Enums.DelegationStatus.PENDING, Enums.DelegationStatus.ACTIVE))) {
            throw ApiException.conflict("ALREADY_LINKED", "您已經綁定這位長輩，或正在等待同意");
        }

        inv.status = Enums.InvitationStatus.USED;
        invitations.save(inv);

        Delegation d = new Delegation();
        d.elderId = inv.elderId;
        d.familyId = me.id;
        d = delegations.save(d);
        audit.log(d.elderId, me.id, d.id, "DELEGATION_REQUESTED", me.name + " 申請成為您的代辦家屬");
        return d;
    }

    // ---------- 3. 長者同意（勾選範圍 + 期限） ----------
    @Transactional
    public Delegation approve(AppUser me, Long delegationId, Set<Enums.Scope> scopes, int days) {
        Delegation d = loadOwnedByElder(me, delegationId);
        if (d.status != Enums.DelegationStatus.PENDING) {
            throw ApiException.conflict("NOT_PENDING", "這筆申請已經處理過了");
        }
        if (scopes == null || scopes.isEmpty()) {
            throw ApiException.badRequest("NO_SCOPE", "請至少勾選一項要讓家人幫忙的事");
        }
        if (days < 1 || days > 365) {
            throw ApiException.badRequest("BAD_DAYS", "授權天數需介於 1 到 365 天");
        }
        d.scopes = EnumSet.copyOf(scopes);
        d.status = Enums.DelegationStatus.ACTIVE;
        d.approvedAt = Instant.now();
        d.expiresAt = d.approvedAt.plus(Duration.ofDays(days));
        d = delegations.save(d);

        String family = userName(d.familyId);
        String labels = d.scopes.stream().map(s -> s.label).collect(Collectors.joining("、"));
        audit.log(d.elderId, me.id, d.id, "DELEGATION_APPROVED",
                "您同意 " + family + " 幫您：" + labels + "（" + days + " 天）");
        return d;
    }

    @Transactional
    public Delegation reject(AppUser me, Long delegationId) {
        Delegation d = loadOwnedByElder(me, delegationId);
        if (d.status != Enums.DelegationStatus.PENDING) {
            throw ApiException.conflict("NOT_PENDING", "這筆申請已經處理過了");
        }
        d.status = Enums.DelegationStatus.REJECTED;
        d = delegations.save(d);
        audit.log(d.elderId, me.id, d.id, "DELEGATION_REJECTED", "您拒絕了 " + userName(d.familyId) + " 的申請");
        return d;
    }

    // ---------- 4. 撤回（長者收回，或家屬自己解除） ----------
    @Transactional
    public Delegation revoke(AppUser me, Long delegationId) {
        Delegation d = delegations.findById(delegationId)
                .orElseThrow(() -> ApiException.notFound("找不到這筆授權"));
        boolean isElder = me.id.equals(d.elderId);
        boolean isFamily = me.id.equals(d.familyId);
        if (!isElder && !isFamily) {
            throw ApiException.forbidden("NOT_OWNER", "這不是您的授權");
        }
        if (d.status != Enums.DelegationStatus.ACTIVE && d.status != Enums.DelegationStatus.PENDING) {
            throw ApiException.conflict("NOT_ACTIVE", "這筆授權已經失效了");
        }
        d.status = Enums.DelegationStatus.REVOKED;
        d.revokedAt = Instant.now();
        d = delegations.save(d);
        String msg = isElder
                ? "您收回了 " + userName(d.familyId) + " 的代辦權限"
                : me.name + " 解除了代辦關係";
        audit.log(d.elderId, me.id, d.id, "DELEGATION_REVOKED", msg);
        return d;
    }

    // ---------- 查詢 ----------
    public List<Delegation> listMine(AppUser me) {
        List<Delegation> list = me.role == Enums.Role.ELDER
                ? delegations.findByElderIdOrderByIdDesc(me.id)
                : delegations.findByFamilyIdOrderByIdDesc(me.id);
        list.forEach(this::expireIfNeeded);
        return list;
    }

    public List<Delegation> listPendingForElder(AppUser me) {
        requireRole(me, Enums.Role.ELDER, "只有長者可以查看待同意的申請");
        return delegations.findByElderIdAndStatusOrderByIdDesc(me.id, Enums.DelegationStatus.PENDING);
    }

    public String userName(Long id) {
        return users.findById(id).map(u -> u.name).orElse("（未知使用者）");
    }

    // ---------- helpers ----------
    private void expireIfNeeded(Delegation d) {
        if (d.status == Enums.DelegationStatus.ACTIVE && !d.isEffective()) {
            d.status = Enums.DelegationStatus.EXPIRED;
            delegations.save(d);
        }
    }

    private Delegation loadOwnedByElder(AppUser me, Long delegationId) {
        Delegation d = delegations.findById(delegationId)
                .orElseThrow(() -> ApiException.notFound("找不到這筆申請"));
        if (!me.id.equals(d.elderId)) {
            throw ApiException.forbidden("NOT_OWNER", "只有長者本人可以處理這筆申請");
        }
        return d;
    }

    /** 還沒有身分就設定成 role；已經是別的身分就擋下。 */
    private void claimRole(AppUser me, Enums.Role role, String conflictMsg) {
        if (me.role == null) {
            me.role = role;
            if (role == Enums.Role.ELDER && me.seniorCardPoints == null) {
                me.seniorCardPoints = 480; // 模擬資料
            }
            users.save(me);
        } else if (me.role != role) {
            throw ApiException.forbidden("WRONG_ROLE", conflictMsg);
        }
    }

    private static void requireRole(AppUser me, Enums.Role role, String msg) {
        if (me.role != role) {
            throw ApiException.forbidden("WRONG_ROLE", msg);
        }
    }
}
