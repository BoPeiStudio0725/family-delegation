package tw.taipei.codefest.delegation.domain;

import jakarta.persistence.*;

/** 開放資料匯入的服務據點（例如臺北市社區照顧關懷據點）。source 必填，Demo 時顯示資料出處。 */
@Entity
public class ServicePoint {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(nullable = false)
    public String name;

    public String type;
    public String district;
    public String address;
    public String phone;
    public Double lat;
    public Double lng;

    @Column(nullable = false)
    public String source;
}
