package tw.taipei.codefest.delegation.domain;

import jakarta.persistence.*;
import java.time.Instant;

/** 長者產生的 6 位數邀請碼，家屬輸入後建立一筆待同意的授權。 */
@Entity
public class Invitation {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(nullable = false, length = 6)
    public String code;

    @Column(nullable = false)
    public Long elderId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public Enums.InvitationStatus status = Enums.InvitationStatus.PENDING;

    @Column(nullable = false)
    public Instant expiresAt;

    public Instant createdAt = Instant.now();

    public boolean isUsable() {
        return status == Enums.InvitationStatus.PENDING && Instant.now().isBefore(expiresAt);
    }
}
