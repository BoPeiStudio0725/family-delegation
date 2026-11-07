package tw.taipei.codefest.delegation.domain;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.EnumSet;
import java.util.Set;

/** 一筆「長者 → 家屬」的授權。核心資料表。 */
@Entity
public class Delegation {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(nullable = false)
    public Long elderId;

    @Column(nullable = false)
    public Long familyId;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "delegation_scope", joinColumns = @JoinColumn(name = "delegation_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "scope")
    public Set<Enums.Scope> scopes = EnumSet.noneOf(Enums.Scope.class);

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public Enums.DelegationStatus status = Enums.DelegationStatus.PENDING;

    public Instant expiresAt;
    public Instant createdAt = Instant.now();
    public Instant approvedAt;
    public Instant revokedAt;

    /** 目前是否有效（ACTIVE 且未過期）。 */
    public boolean isEffective() {
        return status == Enums.DelegationStatus.ACTIVE
                && (expiresAt == null || Instant.now().isBefore(expiresAt));
    }
}
