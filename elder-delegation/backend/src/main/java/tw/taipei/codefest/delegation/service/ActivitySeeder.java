package tw.taipei.codefest.delegation.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tw.taipei.codefest.delegation.domain.Activity;
import tw.taipei.codefest.delegation.domain.Enums.ActivityCategory;
import tw.taipei.codefest.delegation.domain.ServicePoint;
import tw.taipei.codefest.delegation.repo.ActivityRepository;
import tw.taipei.codefest.delegation.repo.ServicePointRepository;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 依開放資料的「據點類型」產生活動場次（模擬資料）。
 *
 * - 樂齡學堂據點 → 以樂齡學習為主
 * - 功能型（老服中心）→ 各類型都有
 * - 一般關懷據點 → 依「N 個時段」決定場次數，內容是關懷據點的基本服務：健康促進、共餐、休閒、聯誼
 * - 每個活動有適合年齡（65–74 / 75–84 / 85 以上…），給長者建議、給家屬篩選
 *
 * 同一個據點每次產生的結果都一樣（依據點 id 決定），方便 Demo。
 */
@Service
public class ActivitySeeder {
    private static final Logger log = LoggerFactory.getLogger(ActivitySeeder.class);
    public static final String SOURCE = "活動場次為黑客松模擬資料（依開放資料的據點類型與時段數產生）";

    private record Template(ActivityCategory category, String title, Integer minAge, Integer maxAge, String desc) {}

    private static final List<Template> HEALTH = List.of(
            new Template(ActivityCategory.HEALTH, "肌力強化運動班", 65, 79, "彈力帶與椅子操，增強腿力、預防跌倒"),
            new Template(ActivityCategory.HEALTH, "健走樂活團", 65, 74, "社區健走與伸展，邊走邊聊天"),
            new Template(ActivityCategory.HEALTH, "椅子瑜珈", 70, null, "坐著也能做的瑜珈，放鬆筋骨"),
            new Template(ActivityCategory.HEALTH, "延緩失能・輕柔伸展", 80, null, "專業老師帶領，動作溫和、安全"),
            new Template(ActivityCategory.HEALTH, "健康講座與量血壓", 65, null, "護理師量血壓、衛教講座"));
    private static final List<Template> LEARNING = List.of(
            new Template(ActivityCategory.LEARNING, "樂齡手機課", 65, 79, "學用 LINE 視訊、拍照、台北通"),
            new Template(ActivityCategory.LEARNING, "長青書法班", 65, null, "一筆一畫，靜心練字"),
            new Template(ActivityCategory.LEARNING, "樂齡英語會話", 65, 79, "生活英語，出國旅遊也能用"),
            new Template(ActivityCategory.LEARNING, "懷舊回憶分享", 80, null, "老照片、老歌，聊聊從前"),
            new Template(ActivityCategory.LEARNING, "防詐騙小學堂", 65, null, "認識常見詐騙手法，保護荷包"));
    private static final List<Template> LEISURE = List.of(
            new Template(ActivityCategory.LEISURE, "卡拉OK歡唱", 65, null, "唱老歌、交朋友"),
            new Template(ActivityCategory.LEISURE, "手作藝術課", 65, 84, "紙藝、黏土、編織，動手動腦"),
            new Template(ActivityCategory.LEISURE, "桌遊益智時光", 65, null, "簡單有趣的桌遊，活化腦力"),
            new Template(ActivityCategory.LEISURE, "園藝療癒", 70, null, "種花種菜，親近自然"));
    private static final List<Template> MEAL = List.of(
            new Template(ActivityCategory.MEAL, "社區共餐", 65, null, "營養午餐，大家一起吃飯"),
            new Template(ActivityCategory.MEAL, "健康餐點教室", 65, 84, "少油少鹽的家常菜示範"));
    private static final List<Template> SOCIAL = List.of(
            new Template(ActivityCategory.SOCIAL, "茶敘聯誼會", 65, null, "喝茶聊天，認識鄰居"),
            new Template(ActivityCategory.SOCIAL, "生日慶生會", 65, null, "每月一次，為壽星慶生"),
            new Template(ActivityCategory.SOCIAL, "關懷陪伴時光", 85, null, "志工陪伴聊天，溫暖相伴"));

    private static final String[] DAYS = {"一", "二", "三", "四", "五"};
    private static final String[] TIMES = {"09:30–11:30", "14:00–16:00", "10:00–12:00", "11:30–13:00"};

    private final ServicePointRepository points;
    private final ActivityRepository activities;

    public ActivitySeeder(ServicePointRepository points, ActivityRepository activities) {
        this.points = points;
        this.activities = activities;
    }

    @Transactional
    public int seedIfEmpty() {
        if (activities.count() > 0) return 0;
        List<Activity> all = new ArrayList<>();
        for (ServicePoint p : points.findAll()) all.addAll(forPoint(p));
        activities.saveAll(all);
        log.info("已產生 {} 個據點活動場次（{}）", all.size(), SOURCE);
        return all.size();
    }

    static List<Activity> forPoint(ServicePoint p) {
        String type = p.type == null ? "" : p.type;
        long seed = p.id == null ? 0 : p.id;
        List<List<Template>> pools = new ArrayList<>();
        int n;
        if (type.contains("樂齡學堂")) {
            pools.add(LEARNING); pools.add(LEARNING); pools.add(HEALTH); pools.add(SOCIAL);
            n = 4;
        } else if (type.contains("功能型")) {
            pools.add(HEALTH); pools.add(LEARNING); pools.add(LEISURE); pools.add(MEAL); pools.add(SOCIAL);
            n = 5;
        } else {
            pools.add(HEALTH); pools.add(MEAL); pools.add(LEISURE); pools.add(SOCIAL); pools.add(LEARNING);
            n = Math.max(2, Math.min(5, (slots(type) + 1) / 2)); // 2-3 時段→2、4-5→3、6-7→4、8 以上→5
        }
        List<Activity> out = new ArrayList<>();
        for (int i = 0; i < n && i < pools.size(); i++) {
            List<Template> pool = pools.get(i);
            Template t = pool.get((int) ((seed * 7 + i * 3) % pool.size()));
            if (i > 0 && out.stream().anyMatch(a -> a.title.equals(t.title()))) {
                continue; // 同據點不重複
            }
            Activity a = new Activity();
            a.servicePointId = p.id;
            a.title = t.title();
            a.category = t.category();
            a.minAge = t.minAge();
            a.maxAge = t.maxAge();
            a.description = t.desc();
            a.schedule = "每週" + DAYS[(int) ((seed + i * 2) % DAYS.length)] + " "
                    + (t.category() == ActivityCategory.MEAL ? TIMES[3] : TIMES[(int) ((seed + i) % 3)]);
            a.source = SOURCE;
            out.add(a);
        }
        return out;
    }

    /** 「6-7時段」→ 7、「10個時段」→ 10、沒有寫 → 4 */
    static int slots(String type) {
        Matcher m = Pattern.compile("(\\d+)(?:-(\\d+))?\\s*個?時段").matcher(type);
        if (!m.find()) return 4;
        return Integer.parseInt(m.group(2) != null ? m.group(2) : m.group(1));
    }
}
