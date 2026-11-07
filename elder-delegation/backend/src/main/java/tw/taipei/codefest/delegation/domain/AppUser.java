package tw.taipei.codefest.delegation.domain;

import jakarta.persistence.*;

/**
 * 使用者。身分來自台北通帳號（townpassId = 台北通 account.id）。
 *
 * role 一開始是 null（還沒決定）：
 * - 產生邀請碼 → 變成 ELDER
 * - 輸入邀請碼 → 變成 FAMILY
 * 綁定之後再次登入，就依 role 直接進入長者或家屬介面。
 *
 * seniorCardPoints（敬老卡點數）為模擬資料。
 */
@Entity
@Table(name = "app_user")
public class AppUser {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    /** 台北通帳號 id（例如 7f3562f4-bb3f-...）。 */
    @Column(unique = true)
    public String townpassId;

    @Column(nullable = false)
    public String name;

    /** null = 還沒決定身分。 */
    @Enumerated(EnumType.STRING)
    public Enums.Role role;

    public String phone;
    public String district;
    /**
     * 台北通的生日字串，例如 1950/03/02。每次登入都依台北通更新，
     * 用來依年齡自動判定身分（65 歲含以上 = 長者、18–64 = 家屬）與推薦活動。
     */
    public String birthday;
    public Integer seniorCardPoints;

    public AppUser() {}

    public AppUser(String townpassId, String name, Enums.Role role, String phone, String district,
                   String birthday, Integer points) {
        this.townpassId = townpassId;
        this.name = name;
        this.role = role;
        this.phone = phone;
        this.district = district;
        this.birthday = birthday;
        this.seniorCardPoints = points;
    }
}
