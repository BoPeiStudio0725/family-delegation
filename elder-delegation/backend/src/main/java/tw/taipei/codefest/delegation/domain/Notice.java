package tw.taipei.codefest.delegation.domain;

import jakarta.persistence.*;
import java.time.Instant;

/** 給家屬的通知：長輩確認或取消了家屬代為報名的活動。 */
@Entity
@Table(indexes = @Index(columnList = "recipientId"))
public class Notice {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    /** 收到通知的人（家屬）。 */
    @Column(nullable = false)
    public Long recipientId;

    @Column(nullable = false)
    public Long elderId;

    public Long bookingId;

    /** 機器可讀的類型，例如 BOOKING_CONFIRMED、BOOKING_CANCELLED。 */
    @Column(nullable = false)
    public String type;

    @Column(nullable = false)
    public String title;

    @Column(length = 500)
    public String message;

    /** 還沒讀是 null。 */
    public Instant readAt;

    public Instant createdAt = Instant.now();

    public Notice() {}

    public Notice(Long recipientId, Long elderId, Long bookingId, String type, String title, String message) {
        this.recipientId = recipientId;
        this.elderId = elderId;
        this.bookingId = bookingId;
        this.type = type;
        this.title = title;
        this.message = message;
    }
}
