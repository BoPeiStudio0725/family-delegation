package tw.taipei.codefest.delegation;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * 雙重確認：家屬代為報名 → 長輩在「已報名活動清單」確認或取消 → 家屬收到通知。
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:bookingconfirm;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "app.open-data.csv=classpath:does-not-exist.csv"
})
@AutoConfigureMockMvc
class BookingConfirmFlowTest {
    private static final String ELDER = "1";    // 陳阿嬤
    private static final String FAMILY = "2";   // 陳小明
    private static final String STRANGER = "3"; // 林志明

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    @Test
    void familyBookingNeedsElderConfirmationAndNotifiesFamily() throws Exception {
        grantBookService();

        // 家屬代為報名 → 待長輩確認
        long first = book(FAMILY, 1, "PENDING_ELDER");
        long second = book(FAMILY, 2, "PENDING_ELDER");

        // 長輩收到「家人幫您報名了活動」的通知（手機會跳出通知）
        mvc.perform(get("/api/notices").header("X-User-Id", ELDER))
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].type").value("BOOKING_REQUESTED"))
                .andExpect(jsonPath("$[0].title").value("陳小明 幫您報名了活動"))
                .andExpect(jsonPath("$[0].read").value(false));

        // 只有長輩本人可以確認或取消
        mvc.perform(post("/api/elders/1/bookings/" + first + "/confirm").header("X-User-Id", FAMILY))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ELDER_ONLY"));
        mvc.perform(post("/api/elders/1/bookings/" + first + "/cancel").header("X-User-Id", STRANGER))
                .andExpect(status().isForbidden());

        // 長輩的清單上看得到「待長輩確認」和報名的人
        mvc.perform(get("/api/elders/1/bookings").header("X-User-Id", ELDER))
                .andExpect(jsonPath("$[0].status").value("PENDING_ELDER"))
                .andExpect(jsonPath("$[0].statusLabel").value("待長輩確認"))
                .andExpect(jsonPath("$[0].bookedByName").value("陳小明"));

        // 自動更新：長輩確認後，家屬那邊的版本戳記會改變
        String before = body(mvc.perform(get("/api/sync").header("X-User-Id", FAMILY)).andReturn()).get("stamp").asText();
        String elderBefore = body(mvc.perform(get("/api/sync").header("X-User-Id", ELDER)).andReturn()).get("stamp").asText();

        // 長輩確認第一個
        mvc.perform(post("/api/elders/1/bookings/" + first + "/confirm").header("X-User-Id", ELDER))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CONFIRMED"));
        String after = body(mvc.perform(get("/api/sync").header("X-User-Id", FAMILY)).andReturn()).get("stamp").asText();
        String elderAfter = body(mvc.perform(get("/api/sync").header("X-User-Id", ELDER)).andReturn()).get("stamp").asText();
        org.junit.jupiter.api.Assertions.assertNotEquals(before, after);
        org.junit.jupiter.api.Assertions.assertNotEquals(elderBefore, elderAfter);
        // 沒有新動作時，戳記不變
        mvc.perform(get("/api/sync").header("X-User-Id", FAMILY)).andExpect(jsonPath("$.stamp").value(after));

        // 不能重複確認
        mvc.perform(post("/api/elders/1/bookings/" + first + "/confirm").header("X-User-Id", ELDER))
                .andExpect(status().isConflict());

        // 家屬收到「確認」通知
        mvc.perform(get("/api/notices").header("X-User-Id", FAMILY))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].type").value("BOOKING_CONFIRMED"))
                .andExpect(jsonPath("$[0].read").value(false));

        // 長輩取消第二個 → 家屬收到「取消」通知
        mvc.perform(post("/api/elders/1/bookings/" + second + "/cancel").header("X-User-Id", ELDER))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
        mvc.perform(get("/api/notices").header("X-User-Id", FAMILY))
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].type").value("BOOKING_CANCELLED"));

        // 已確認的活動，長輩之後也可以取消，家屬一樣收到通知
        mvc.perform(post("/api/elders/1/bookings/" + first + "/cancel").header("X-User-Id", ELDER))
                .andExpect(jsonPath("$.status").value("CANCELLED"));
        mvc.perform(get("/api/notices").header("X-User-Id", FAMILY))
                .andExpect(jsonPath("$.length()").value(3));

        // 標成已讀
        mvc.perform(post("/api/notices/read").header("X-User-Id", FAMILY))
                .andExpect(jsonPath("$.count").value(3));
        mvc.perform(get("/api/notices").header("X-User-Id", FAMILY))
                .andExpect(jsonPath("$[0].read").value(true));

        // 長輩只收到報名通知（自己的確認 / 取消不會通知自己），別人看不到
        mvc.perform(get("/api/notices").header("X-User-Id", ELDER))
                .andExpect(jsonPath("$.length()").value(2));
        mvc.perform(get("/api/notices").header("X-User-Id", STRANGER))
                .andExpect(jsonPath("$.length()").value(0));

        // 取消後可以重新報名
        long again = book(FAMILY, 2, "PENDING_ELDER");

        // 家屬自己取消 → 長輩收到通知
        mvc.perform(delete("/api/elders/1/bookings/" + again).header("X-User-Id", FAMILY))
                .andExpect(status().isOk());
        mvc.perform(get("/api/notices").header("X-User-Id", ELDER))
                .andExpect(jsonPath("$[0].type").value("BOOKING_CANCELLED_BY_FAMILY"));

        // 長輩的操作也留在「做過的事」
        mvc.perform(get("/api/elders/1/logs").header("X-User-Id", ELDER))
                .andExpect(jsonPath("$[2].action").value("BOOKING_CANCELLED"));
    }

    @Test
    void elderOwnBookingIsConfirmedAndSendsNoNotice() throws Exception {
        long id = book("4", 3, "CONFIRMED"); // 王阿公自己報名
        mvc.perform(post("/api/elders/4/bookings/" + id + "/cancel").header("X-User-Id", "4"))
                .andExpect(jsonPath("$.status").value("CANCELLED"));
        mvc.perform(post("/api/elders/4/bookings/" + id + "/cancel").header("X-User-Id", "4"))
                .andExpect(status().isConflict());
    }

    private void grantBookService() throws Exception {
        String code = body(mvc.perform(post("/api/invitations").header("X-User-Id", ELDER))
                .andExpect(status().isCreated()).andReturn()).get("code").asText();
        long delegationId = body(mvc.perform(post("/api/invitations/accept").header("X-User-Id", FAMILY)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isCreated()).andReturn()).get("id").asLong();
        mvc.perform(post("/api/delegations/" + delegationId + "/approve").header("X-User-Id", ELDER)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"scopes\":[\"VIEW_INFO\",\"BOOK_SERVICE\"],\"days\":30}"))
                .andExpect(status().isOk());
    }

    private long book(String userId, int pointId, String expectedStatus) throws Exception {
        String elder = userId.equals(FAMILY) ? ELDER : userId;
        return body(mvc.perform(post("/api/elders/" + elder + "/bookings").header("X-User-Id", userId)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"servicePointId\":" + pointId + "}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value(expectedStatus)).andReturn()).get("id").asLong();
    }

    private JsonNode body(MvcResult r) throws Exception {
        return json.readTree(r.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }
}
