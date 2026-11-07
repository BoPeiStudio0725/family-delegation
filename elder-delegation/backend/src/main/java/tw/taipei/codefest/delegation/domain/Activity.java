package tw.taipei.codefest.delegation.domain;

import jakarta.persistence.*;

/**
 * 據點活動場次。
 * 據點（名稱、地址、電話、據點類型、時段數）來自開放資料；
 * 活動名稱、時間、適合年齡為黑客松模擬資料，依據點類型與時段數產生（見 ActivitySeeder）。
 */
@Entity
@Table(indexes = @Index(columnList = "servicePointId"))
public class Activity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(nullable = false)
    public Long servicePointId;

    @Column(nullable = false)
    public String title;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public Enums.ActivityCategory category;

    /** 適合年齡（含），maxAge = null 表示沒有上限。 */
    public Integer minAge;
    public Integer maxAge;

    /** 例如「每週二 09:30–11:30」 */
    public String schedule;

    @Column(length = 300)
    public String description;

    @Column(nullable = false)
    public String source;

    public boolean fitsAge(Integer age) {
        if (age == null) return true;
        return (minAge == null || age >= minAge) && (maxAge == null || age <= maxAge);
    }

    /** 每週的固定時段：例如「每週二 10:00–12:00」→ (星期二, 10:00, 12:00)；讀不到是 null。 */
    public Slot slot() {
        if (schedule == null) return null;
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("每週([一二三四五六日])\\s*(\\d{1,2}:\\d{2})\\s*[–\\-~]\\s*(\\d{1,2}:\\d{2})")
                .matcher(schedule);
        if (!m.find()) return null;
        return new Slot(java.time.DayOfWeek.of("一二三四五六日".indexOf(m.group(1)) + 1),
                java.time.LocalTime.parse(pad(m.group(2))), java.time.LocalTime.parse(pad(m.group(3))));
    }

    /** 時間衝突：同一天、時段重疊（10:00–12:00 和 12:00–14:00 剛好接上，不算衝突）。 */
    public boolean conflictsWith(Activity other) {
        Slot a = slot(), b = other == null ? null : other.slot();
        return a != null && b != null && a.overlaps(b);
    }

    public record Slot(java.time.DayOfWeek day, java.time.LocalTime start, java.time.LocalTime end) {
        public boolean overlaps(Slot o) {
            return day == o.day && start.isBefore(o.end) && o.start.isBefore(end);
        }
    }

    /** 下一次上課：例如今天週六、活動是「每週二 09:30–11:30」→ 下週二。今天還沒結束就算今天。 */
    public Session nextSession(java.time.LocalDateTime now) {
        Slot s = slot();
        if (s == null) return null;
        java.time.LocalDate d = now.toLocalDate().with(java.time.temporal.TemporalAdjusters.nextOrSame(s.day()));
        if (d.equals(now.toLocalDate()) && !now.toLocalTime().isBefore(s.end())) d = d.plusWeeks(1);
        return new Session(d, s.start(), s.end());
    }

    private static String pad(String t) { return t.length() == 4 ? "0" + t : t; }

    public record Session(java.time.LocalDate date, java.time.LocalTime start, java.time.LocalTime end) {}

    public String ageLabel() {
        if (minAge != null && maxAge != null) return minAge + "–" + maxAge + " 歲";
        if (minAge != null) return minAge + " 歲以上";
        return "不限年齡";
    }
}
