package tw.taipei.codefest.delegation.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.stereotype.Component;
import tw.taipei.codefest.delegation.domain.AppUser;
import tw.taipei.codefest.delegation.domain.Enums.Role;
import tw.taipei.codefest.delegation.domain.ServicePoint;
import tw.taipei.codefest.delegation.repo.AppUserRepository;
import tw.taipei.codefest.delegation.repo.ServicePointRepository;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.Charset;
import java.util.*;

/**
 * 啟動時：
 * 1. 建立示範帳號（模擬資料）
 * 2. 匯入開放資料 CSV（app.open-data.csv 設定的路徑）
 *
 * CSV 欄位用「表頭名稱」自動對應，所以 data.taipei 下載的檔案不用改欄位名就能匯入。
 */
@Component
public class DataSeeder implements CommandLineRunner {
    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    // 表頭可能的名稱（依 data.taipei / data.gov.tw 常見欄位）
    private static final List<String> NAME_COLS = List.of("據點名稱", "機構名稱", "名稱", "name");
    private static final List<String> TYPE_COLS = List.of("據點類型", "類型", "類別", "type");
    private static final List<String> ADDR_COLS = List.of("地址", "據點地址", "機構地址", "address");
    private static final List<String> DIST_COLS = List.of("行政區", "區域", "行政區名稱", "district");
    private static final List<String> DIST_CODE_COLS = List.of("行政區代碼");
    private static final List<String> PHONE_COLS = List.of("電話", "聯絡電話", "phone");
    private static final List<String> LAT_COLS = List.of("緯度", "lat", "Latitude", "latitude", "Y");
    private static final List<String> LNG_COLS = List.of("經度", "lng", "lon", "Longitude", "longitude", "X");

    private static final List<String> TAIPEI_DISTRICTS = List.of(
            "中正區", "大同區", "中山區", "松山區", "大安區", "萬華區",
            "信義區", "士林區", "北投區", "內湖區", "南港區", "文山區");

    private final AppUserRepository users;
    private final ServicePointRepository points;
    private final ResourceLoader resources;
    private final ActivitySeeder activitySeeder;

    @Value("${app.open-data.csv:classpath:data/service_points.csv}")
    private String csvLocation;

    @Value("${app.open-data.charset:UTF-8}")
    private String csvCharset;

    @Value("${app.open-data.source:臺北市政府社會局｜臺北市銀髮族服務-社區照顧關懷據點（data.taipei，政府資料開放授權條款第1版）}")
    private String sourceLabel;

    public DataSeeder(AppUserRepository users, ServicePointRepository points, ResourceLoader resources,
                      ActivitySeeder activitySeeder) {
        this.users = users;
        this.points = points;
        this.resources = resources;
        this.activitySeeder = activitySeeder;
    }

    @Override
    public void run(String... args) throws Exception {
        seedUsers();
        if (points.count() == 0) {
            int n = importCsv();
            if (n == 0) {
                seedPlaceholderPoints();
            }
        }
        activitySeeder.seedIfEmpty(); // 據點有了以後，產生活動場次（模擬資料）
    }

    private void seedUsers() {
        if (users.count() > 0) return;
        // 全部為模擬資料（給自動測試和 demo.sh 用）。
        // 從台北通進來的使用者會在第一次登入時自動建立，不用寫在這裡。
        // 依序存，id 會是 1、2、3、4。
        for (AppUser u : List.of(
                new AppUser("demo-elder-chen", "陳阿嬤", Role.ELDER, "0912-000-001", "士林區", "1950/03/02", 480),
                new AppUser("demo-family-chen", "陳小明", Role.FAMILY, "0912-000-002", "大安區", "1990/08/15", null),
                new AppUser("demo-family-lin", "林志明", Role.FAMILY, "0912-000-003", "信義區", "1985/01/20", null),
                new AppUser("demo-elder-wang", "王阿公", Role.ELDER, "0912-000-004", "北投區", "1948/11/11", 320))) {
            users.save(u);
        }
        log.info("已建立示範帳號：1 陳阿嬤(長者) / 2 陳小明(家屬) / 3 林志明(家屬) / 4 王阿公(長者)");
    }

    private int importCsv() {
        Resource res = resources.getResource(csvLocation);
        if (!res.exists()) {
            log.warn("找不到開放資料檔 {}，改用示範據點。請到 data.taipei 下載 CSV 放到此路徑。", csvLocation);
            return 0;
        }
        List<ServicePoint> batch = new ArrayList<>();
        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(res.getInputStream(), Charset.forName(csvCharset)))) {
            String headerLine = br.readLine();
            if (headerLine == null) return 0;
            headerLine = headerLine.replace("﻿", ""); // 去掉 BOM
            List<String> header = parseCsvLine(headerLine);
            Map<String, Integer> idx = new HashMap<>();
            for (int i = 0; i < header.size(); i++) idx.put(header.get(i).trim(), i);

            Integer cName = find(idx, NAME_COLS);
            if (cName == null) {
                log.error("CSV 找不到名稱欄位，表頭為：{}（請在 DataSeeder.NAME_COLS 加上正確欄名）", header);
                return 0;
            }
            Integer cType = find(idx, TYPE_COLS), cAddr = find(idx, ADDR_COLS), cDist = find(idx, DIST_COLS),
                    cDistCode = find(idx, DIST_CODE_COLS), cPhone = find(idx, PHONE_COLS),
                    cLat = find(idx, LAT_COLS), cLng = find(idx, LNG_COLS);

            String record;
            // 一次讀一筆「記錄」而不是一行：開放資料的欄位內常有換行（引號內的換行）
            while ((record = readRecord(br)) != null) {
                if (record.isBlank()) continue;
                List<String> row = parseCsvLine(record);
                String name = joinLines(get(row, cName), "");
                if (name == null || name.isBlank()) continue;

                ServicePoint p = new ServicePoint();
                p.name = name;
                p.type = joinLines(get(row, cType), " ");
                p.address = joinLines(get(row, cAddr), "");
                p.phone = joinLines(get(row, cPhone), " ");
                p.district = get(row, cDist);
                if (p.district == null) p.district = districtFromAddress(p.address);
                if (p.district == null) p.district = districtFromCode(get(row, cDistCode));
                if (p.district == null) p.district = get(row, cDistCode); // 最後才用原始代碼
                p.lat = parseDouble(get(row, cLat));
                p.lng = parseDouble(get(row, cLng));
                p.source = sourceLabel;
                batch.add(p);
            }
        } catch (Exception e) {
            log.error("匯入開放資料失敗（若是亂碼，請把 app.open-data.charset 改成 Big5）", e);
            return 0;
        }
        points.saveAll(batch);
        log.info("已匯入 {} 筆開放資料據點，來源：{}", batch.size(), sourceLabel);
        return batch.size();
    }

    /** 沒有開放資料檔時的備案。名稱明確標示「示範」，正式 Demo 前一定要換成真資料。 */
    private void seedPlaceholderPoints() {
        String src = "示範資料（尚未匯入開放資料，請替換）";
        List<ServicePoint> list = new ArrayList<>();
        String[][] rows = {
                {"【示範】士林區關懷據點 A", "士林區"},
                {"【示範】士林區關懷據點 B", "士林區"},
                {"【示範】大安區關懷據點 A", "大安區"},
                {"【示範】北投區關懷據點 A", "北投區"},
        };
        for (String[] r : rows) {
            ServicePoint p = new ServicePoint();
            p.name = r[0];
            p.type = "社區照顧關懷據點";
            p.district = r[1];
            p.address = "臺北市" + r[1] + "（示範地址）";
            p.source = src;
            list.add(p);
        }
        points.saveAll(list);
    }

    // ---------- CSV helpers ----------
    /** 讀一筆 CSV 記錄；引號還沒關上就繼續讀下一行（欄位內有換行）。讀完回傳 null。 */
    static String readRecord(BufferedReader br) throws java.io.IOException {
        String line = br.readLine();
        if (line == null) return null;
        StringBuilder sb = new StringBuilder(line);
        boolean open = hasOpenQuote(line, false);
        while (open) {
            String next = br.readLine();
            if (next == null) break;
            sb.append('\n').append(next);
            open = hasOpenQuote(next, true);
        }
        return sb.toString();
    }

    /** 這一行結束時，引號是否還開著（startOpen：這行開始時是否在引號內）。 */
    private static boolean hasOpenQuote(String s, boolean startOpen) {
        boolean open = startOpen;
        for (int i = 0; i < s.length(); i++) {
            if (s.charAt(i) == '"') open = !open; // "" 跳脫會切換兩次，不影響結果
        }
        return open;
    }

    /** 把欄位內的換行（含前後空白）換成 sep。 */
    static String joinLines(String s, String sep) {
        return s == null ? null : s.replaceAll("\\s*\\R\\s*", sep).trim();
    }

    /** 內政部行政區代碼 → 臺北市行政區名稱 */
    private static final Map<String, String> DISTRICT_CODES = Map.ofEntries(
            Map.entry("63000010", "松山區"), Map.entry("63000020", "信義區"),
            Map.entry("63000030", "大安區"), Map.entry("63000040", "中山區"),
            Map.entry("63000050", "中正區"), Map.entry("63000060", "大同區"),
            Map.entry("63000070", "萬華區"), Map.entry("63000080", "文山區"),
            Map.entry("63000090", "南港區"), Map.entry("63000100", "內湖區"),
            Map.entry("63000110", "士林區"), Map.entry("63000120", "北投區"));

    static String districtFromCode(String code) {
        return code == null ? null : DISTRICT_CODES.get(code.trim());
    }

    static List<String> parseCsvLine(String line) {
        List<String> out = new ArrayList<>();
        StringBuilder sb = new StringBuilder();
        boolean inQuotes = false;
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (inQuotes) {
                if (c == '"') {
                    if (i + 1 < line.length() && line.charAt(i + 1) == '"') {
                        sb.append('"');
                        i++;
                    } else {
                        inQuotes = false;
                    }
                } else {
                    sb.append(c);
                }
            } else if (c == '"') {
                inQuotes = true;
            } else if (c == ',') {
                out.add(sb.toString());
                sb.setLength(0);
            } else {
                sb.append(c);
            }
        }
        out.add(sb.toString());
        return out;
    }

    private static Integer find(Map<String, Integer> idx, List<String> candidates) {
        for (String c : candidates) {
            if (idx.containsKey(c)) return idx.get(c);
        }
        return null;
    }

    private static String get(List<String> row, Integer col) {
        if (col == null || col >= row.size()) return null;
        String v = row.get(col).trim();
        return v.isEmpty() ? null : v;
    }

    private static Double parseDouble(String s) {
        if (s == null) return null;
        try {
            return Double.parseDouble(s);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    static String districtFromAddress(String address) {
        if (address == null) return null;
        for (String d : TAIPEI_DISTRICTS) {
            if (address.contains(d)) return d;
        }
        return null;
    }
}
