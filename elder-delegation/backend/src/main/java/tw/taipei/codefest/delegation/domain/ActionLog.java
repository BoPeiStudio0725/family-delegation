package tw.taipei.codefest.delegation.domain;

import jakarta.persistence.*;
import java.time.Instant;

/** 操作紀錄：長者可以看到「誰、什麼時候、幫我做了什麼」。 */
@Entity
@Table(indexes = @Index(columnList = "elderId"))
public class ActionLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(nullable = false)
    public Long elderId;

    @Column(nullable = false)
    public Long actorId;

    public Long delegationId;

    /** 機器可讀的動作代碼，例如 DELEGATION_APPROVED、BOOKING_CREATED。 */
    @Column(nullable = false)
    public String action;

    /** 給長者看的白話描述。 */
    @Column(length = 500)
    public String message;

    public Instant createdAt = Instant.now();

    public ActionLog() {}

    public ActionLog(Long elderId, Long actorId, Long delegationId, String action, String message) {
        this.elderId = elderId;
        this.actorId = actorId;
        this.delegationId = delegationId;
        this.action = action;
        this.message = message;
    }
}
