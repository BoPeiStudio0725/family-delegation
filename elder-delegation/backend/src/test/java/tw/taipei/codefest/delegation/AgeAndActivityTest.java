package tw.taipei.codefest.delegation;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import tw.taipei.codefest.delegation.domain.Activity;
import tw.taipei.codefest.delegation.domain.Enums;
import tw.taipei.codefest.delegation.repo.ActivityRepository;
import tw.taipei.codefest.delegation.repo.ServicePointRepository;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** 年齡自動判定身分、依年齡篩選活動、年齡不符不能報名。 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:ageactivity;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "app.open-data.csv=classpath:does-not-exist.csv"
})
@AutoConfigureMockMvc
class AgeAndActivityTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired ActivityRepository activities;
    @Autowired ServicePointRepository points;

    private JsonNode login(String id, String name, LocalDate birthday) throws Exception {
        String b = birthday.toString().replace('-', '/');
        String body = "{\"id\":\"" + id + "\",\"realName\":\"" + name + "\",\"birthday\":\"" + b + "\",\"district\":\"士林區\"}";
        return json.readTree(mvc.perform(post("/api/auth/townpass").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    @Test
    void roleIsAssignedByAge() throws Exception {
        LocalDate today = LocalDate.now();
        // 剛好 65 歲 → 長者（含 65）
        JsonNode e65 = login("age-65", "剛滿六十五", today.minusYears(65));
        assertEquals("ELDER", e65.get("role").asText());
        assertEquals("YOUNG_OLD", e65.get("ageGroup").asText());
        // 64 歲 → 家屬
        assertEquals("FAMILY", login("age-64", "六十四", today.minusYears(65).plusDays(1)).get("role").asText());
        // 剛好 18 歲 → 成年，家屬
        assertEquals("FAMILY", login("age-18", "十八", today.minusYears(18)).get("role").asText());
        // 17 歲 → 未成年，不指定身分，也不能選家屬
        JsonNode minor = login("age-17", "十七", today.minusYears(18).plusDays(1));
        assertTrue(minor.get("role").isNull());
        assertEquals("MINOR", minor.get("ageGroup").asText());
        mvc.perform(post("/api/me/role").header("X-User-Id", minor.get("id").asText())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"role\":\"FAMILY\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("MINOR"));
        // 85 歲 → 長青關懷
        assertEquals("OLDEST_OLD", login("age-85", "八十五", today.minusYears(85)).get("ageGroup").asText());
    }

    @Test
    void roleFollowsBirthdayChanges() throws Exception {
        LocalDate today = LocalDate.now();
        // 75 歲 → 長者介面
        JsonNode elder = login("bday-change", "改生日的人", today.minusYears(75));
        assertEquals("ELDER", elder.get("role").asText());
        // 在台北通把生日改成 63 歲 → 下次進來是家屬介面
        JsonNode family = login("bday-change", "改生日的人", today.minusYears(63));
        assertEquals("FAMILY", family.get("role").asText());
        assertEquals(63, family.get("age").asInt());
        assertEquals(elder.get("id").asText(), family.get("id").asText()); // 同一個人
        // 改回 65 歲（含）→ 又變回長者
        assertEquals("ELDER", login("bday-change", "改生日的人", today.minusYears(65)).get("role").asText());
        // 改成 16 歲 → 未成年，不指定身分
        assertTrue(login("bday-change", "改生日的人", today.minusYears(16)).get("role").isNull());
    }

    @Test
    void linkedElderAlsoSwitchesByAge() throws Exception {
        // 金阿嬤（id 1）已有授權申請；生日改成 40 歲 → 也會變成家屬
        JsonNode g = login("demo-townpass-grandma", "金阿嬤", LocalDate.now().minusYears(40));
        assertEquals("FAMILY", g.get("role").asText());
        // 改回 1950 → 長者
        assertEquals("ELDER", login("demo-townpass-grandma", "金阿嬤", LocalDate.of(1950, 3, 2)).get("role").asText());
    }

    @Test
    void activitiesAreFilteredByElderAgeAndCategory() throws Exception {
        // 金阿嬤（id 1）1950/03/02 出生
        JsonNode res = json.readTree(mvc.perform(get("/api/elders/1/activities").header("X-User-Id", "1"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8));
        int age = res.get("age").asInt();
        assertTrue(age >= 65);
        assertEquals(5, res.get("categories").size());
        assertTrue(res.get("activities").size() > 0);
        for (JsonNode a : res.get("activities")) {
            Activity act = activities.findById(a.get("id").asLong()).orElseThrow();
            assertTrue(act.fitsAge(age), act.title + " 不適合 " + age + " 歲");
        }
        // 依類型篩選
        JsonNode meal = json.readTree(mvc.perform(get("/api/elders/1/activities?category=MEAL").header("X-User-Id", "1"))
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8));
        for (JsonNode a : meal.get("activities")) assertEquals("MEAL", a.get("category").asText());

        // 沒有授權的家屬看不到
        mvc.perform(get("/api/elders/1/activities").header("X-User-Id", "2"))
                .andExpect(status().isForbidden());
    }

    @Test
    void cannotBookActivityThatDoesNotFitAge() throws Exception {
        Activity tooOld = new Activity();
        tooOld.servicePointId = points.findAll().get(0).id;
        tooOld.title = "測試：九十歲以上";
        tooOld.category = Enums.ActivityCategory.SOCIAL;
        tooOld.minAge = 90;
        tooOld.source = "test";
        tooOld = activities.save(tooOld);
        mvc.perform(post("/api/elders/1/bookings").header("X-User-Id", "1")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"activityId\":" + tooOld.id + "}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("AGE_MISMATCH"));

        // 適合的活動可以報名，報名後清單上標示已報名
        long ok = json.readTree(mvc.perform(get("/api/elders/1/activities").header("X-User-Id", "1"))
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8)).get("activities").get(0).get("id").asLong();
        mvc.perform(post("/api/elders/1/bookings").header("X-User-Id", "1")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"activityId\":" + ok + "}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.activityId").value(ok))
                .andExpect(jsonPath("$.status").value("CONFIRMED"));
        mvc.perform(post("/api/elders/1/bookings").header("X-User-Id", "1")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"activityId\":" + ok + "}"))
                .andExpect(status().isConflict());
    }
}
