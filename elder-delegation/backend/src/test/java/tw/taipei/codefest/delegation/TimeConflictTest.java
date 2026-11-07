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
import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** 同一時段已報名，其他衝突的活動不列出、也不能報名；取消後恢復。 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:timeconflict;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "app.open-data.csv=classpath:does-not-exist.csv"
})
@AutoConfigureMockMvc
class TimeConflictTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired ActivityRepository activities;
    @Autowired ServicePointRepository points;

    private long act(String title, String schedule) {
        Activity a = new Activity();
        a.servicePointId = points.findAll().get(0).id;
        a.title = title;
        a.category = Enums.ActivityCategory.SOCIAL;
        a.minAge = 65;
        a.schedule = schedule;
        a.source = "test";
        return activities.save(a).id;
    }

    private Set<Long> listedIds() throws Exception {
        JsonNode res = json.readTree(mvc.perform(get("/api/elders/1/activities?category=SOCIAL").header("X-User-Id", "1"))
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8));
        Set<Long> ids = new HashSet<>();
        res.get("activities").forEach(a -> ids.add(a.get("id").asLong()));
        return ids;
    }

    private int hidden() throws Exception {
        return json.readTree(mvc.perform(get("/api/elders/1/activities?category=SOCIAL").header("X-User-Id", "1"))
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8)).get("hiddenByConflict").asInt();
    }

    @Test
    void sameSlotActivitiesAreHiddenAndBlockedUntilCancelled() throws Exception {
        long tue10 = act("週二早上", "每週二 10:00–12:00");
        long tue11 = act("週二重疊", "每週二 11:00–13:00");
        long tue12 = act("週二接著", "每週二 12:00–14:00");
        long wed10 = act("週三早上", "每週三 10:00–12:00");

        // 報名週二 10:00–12:00
        long bookingId = json.readTree(mvc.perform(post("/api/elders/1/bookings").header("X-User-Id", "1")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"activityId\":" + tue10 + "}"))
                .andExpect(status().isCreated()).andReturn().getResponse()
                .getContentAsString(StandardCharsets.UTF_8)).get("id").asLong();

        Set<Long> ids = listedIds();
        assertTrue(ids.contains(tue10), "已報名的仍顯示（標示已報名）");
        assertFalse(ids.contains(tue11), "時段重疊的不列出");
        assertTrue(ids.contains(tue12), "剛好接上（12:00 開始）不算衝突");
        assertTrue(ids.contains(wed10), "不同天不衝突");
        assertTrue(hidden() >= 1);

        // 直接報名衝突的活動也會被擋
        mvc.perform(post("/api/elders/1/bookings").header("X-User-Id", "1")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"activityId\":" + tue11 + "}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TIME_CONFLICT"));

        // 取消後，同時段的活動重新出現，也可以報名
        mvc.perform(post("/api/elders/1/bookings/" + bookingId + "/cancel").header("X-User-Id", "1"))
                .andExpect(status().isOk());
        assertTrue(listedIds().contains(tue11));
        mvc.perform(post("/api/elders/1/bookings").header("X-User-Id", "1")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"activityId\":" + tue11 + "}"))
                .andExpect(status().isCreated());
    }

    @Test
    void overlapRules() {
        Activity a = new Activity();
        a.schedule = "每週二 10:00–12:00";
        Activity b = new Activity();
        b.schedule = "每週二 09:00–10:30";
        assertTrue(a.conflictsWith(b));
        b.schedule = "每週二 09:00–10:00";
        assertFalse(a.conflictsWith(b));
        b.schedule = "每週四 10:00–12:00";
        assertFalse(a.conflictsWith(b));
        b.schedule = null;
        assertFalse(a.conflictsWith(b));
    }
}
