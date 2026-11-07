package tw.taipei.codefest.delegation.domain;

/** 集中放所有列舉，方便隊友一眼看完。 */
public final class Enums {
    private Enums() {}

    public enum Role { ELDER, FAMILY }

    /** 授權範圍。要加新的代辦項目，就在這裡加一個值，再在 controller 方法上標 @RequiresScope。 */
    public enum Scope {
        VIEW_INFO("查看我的資料"),
        BOOK_SERVICE("幫我報名據點活動");

        public final String label;
        Scope(String label) { this.label = label; }
    }

    public enum InvitationStatus { PENDING, USED, EXPIRED }

    public enum DelegationStatus { PENDING, ACTIVE, REJECTED, REVOKED, EXPIRED }

    /** 報名狀態：家屬代為報名後，要長輩自己再確認一次（雙重確認）。 */
    public enum BookingStatus {
        PENDING_ELDER("待長輩確認"),
        CONFIRMED("已確認"),
        CANCELLED("已取消");

        public final String label;
        BookingStatus(String label) { this.label = label; }
    }

    /** 活動類型。 */
    public enum ActivityCategory {
        HEALTH("健康促進"),
        LEARNING("樂齡學習"),
        LEISURE("休閒娛樂"),
        MEAL("共餐服務"),
        SOCIAL("社交聯誼");

        public final String label;
        ActivityCategory(String label) { this.label = label; }
    }

    /**
     * 年齡層：18 歲成年、65 歲（含）以上為長者，長者再分三層給不同的活動建議。
     */
    public enum AgeGroup {
        MINOR("未成年", 0, 17),
        ADULT("成年", 18, 64),
        YOUNG_OLD("活躍樂齡", 65, 74),
        MIDDLE_OLD("樂齡長青", 75, 84),
        OLDEST_OLD("長青關懷", 85, 200);

        public final String label;
        public final int min;
        public final int max;
        AgeGroup(String label, int min, int max) { this.label = label; this.min = min; this.max = max; }

        public static AgeGroup of(Integer age) {
            if (age == null) return null;
            for (AgeGroup g : values()) if (age >= g.min && age <= g.max) return g;
            return OLDEST_OLD;
        }

        public boolean isElder() { return this == YOUNG_OLD || this == MIDDLE_OLD || this == OLDEST_OLD; }

        /** 例如「活躍樂齡（65–74 歲）」 */
        public String fullLabel() {
            return label + (max >= 200 ? "（" + min + " 歲以上）" : "（" + min + "–" + max + " 歲）");
        }
    }
}
