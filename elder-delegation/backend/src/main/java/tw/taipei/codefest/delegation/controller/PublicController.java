package tw.taipei.codefest.delegation.controller;

import org.springframework.web.bind.annotation.*;
import tw.taipei.codefest.delegation.controller.Dtos.UserView;
import tw.taipei.codefest.delegation.domain.ServicePoint;
import tw.taipei.codefest.delegation.repo.AppUserRepository;
import tw.taipei.codefest.delegation.repo.ServicePointRepository;

import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;

/** 不需登入的 API：開放資料據點、示範帳號。 */
@RestController
@RequestMapping("/api")
public class PublicController {
    private final ServicePointRepository points;
    private final AppUserRepository users;

    public PublicController(ServicePointRepository points, AppUserRepository users) {
        this.points = points;
        this.users = users;
    }

    /** ?district=士林區 或 ?q=關鍵字；都不給就回全部。 */
    @GetMapping("/service-points")
    public List<ServicePoint> servicePoints(@RequestParam(required = false) String district,
                                            @RequestParam(required = false) String q) {
        if (district != null && !district.isBlank()) {
            return points.findByDistrictOrderByName(district.trim());
        }
        if (q != null && !q.isBlank()) {
            return points.findByNameContainingOrAddressContainingOrderByName(q.trim(), q.trim());
        }
        return points.findAll();
    }

    /** 行政區清單 + 各區據點數（給家屬端篩選用）。 */
    @GetMapping("/service-points/districts")
    public Map<String, Long> districts() {
        return points.findAll().stream()
                .filter(p -> p.district != null && !p.district.isBlank())
                .collect(Collectors.groupingBy(p -> p.district, TreeMap::new, Collectors.counting()));
    }

    /** 資料來源（Demo 時展示給評審看）。 */
    @GetMapping("/service-points/sources")
    public Map<String, Long> sources() {
        return points.findAll().stream()
                .collect(Collectors.groupingBy(p -> p.source, TreeMap::new, Collectors.counting()));
    }

    /** 示範帳號清單（登入頁選角色用；正式版改接台北通登入後刪除）。 */
    @GetMapping("/demo/users")
    public List<UserView> demoUsers() {
        return users.findAll().stream().map(UserView::of).toList();
    }
}
