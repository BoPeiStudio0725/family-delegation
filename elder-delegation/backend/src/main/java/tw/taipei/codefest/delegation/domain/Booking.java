package tw.taipei.codefest.delegation.domain;

import jakarta.persistence.*;
import java.time.Instant;

/** 代辦項目：報名據點活動（示範用的服務）。 */
@Entity
public class Booking {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(nullable = false)
    public Long elderId;

    @Column(nullable = false)
    public Long servicePointId;

    /** 報名的活動場次（舊資料可能是 null，代表只報名據點）。 */
    public Long activityId;

    /** 實際按下報名的人（長者本人或家屬）。 */
    @Column(nullable = false)
    public Long bookedBy;

    public String note;
    public Instant createdAt = Instant.now();

    /** 家屬代為報名 → PENDING_ELDER，等長輩確認；長輩自己報名 → CONFIRMED。 */
    @Enumerated(EnumType.STRING)
    public Enums.BookingStatus status = Enums.BookingStatus.CONFIRMED;

    /** 長輩確認或取消的時間。 */
    public Instant respondedAt;

    /** 舊資料沒有狀態欄位，一律視為已確認。 */
    public Enums.BookingStatus statusOrDefault() {
        return status == null ? Enums.BookingStatus.CONFIRMED : status;
    }
}
