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

import java.nio.charset.StandardCharsets;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * 台北通登入 → 第一次沒有身分 → 綁定後再登入自動辨識長輩 / 家屬。
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:townpass;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "app.open-data.csv=classpath:does-not-exist.csv"
})
@AutoConfigureMockMvc
class TownPassLoginFlowTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    private JsonNode login(String townpassId, String name, String birthday) throws Exception {
        String body = "{\"id\":\"" + townpassId + "\",\"realName\":\"" + name + "\",\"birthday\":\"" + birthday + "\"}";
        MvcResult r = mvc.perform(post("/api/auth/townpass").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andReturn();
        return json.readTree(r.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    @Test
    void roleIsDecidedByBinding() throws Exception {
        // 1. 第一次登入：依生日自動判定（65 歲含以上 → 長者，18–64 → 家屬）
        JsonNode grandma = login("tp-grandma", "金阿嬤", "1948/05/01");
        JsonNode son = login("tp-son", "金大森", "1980/02/02");
        assert "ELDER".equals(grandma.get("role").asText());
        assert "FAMILY".equals(son.get("role").asText());
        assert "OLDEST_OLD".equals(grandma.get("ageGroup").asText()) || "MIDDLE_OLD".equals(grandma.get("ageGroup").asText());
        assert "ADULT".equals(son.get("ageGroup").asText());
        String g = grandma.get("id").asText();
        String s = son.get("id").asText();

        // 2. 阿嬤產生邀請碼 → 變成長輩；兒子輸入 → 變成家屬
        String code = json.readTree(mvc.perform(post("/api/invitations").header("X-User-Id", g))
                .andExpect(status().isCreated()).andReturn().getResponse()
                .getContentAsString(StandardCharsets.UTF_8)).get("code").asText();
        mvc.perform(post("/api/invitations/accept").header("X-User-Id", s)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isCreated());

        // 3. 再次從台北通登入 → 直接辨識身分，且已綁定
        JsonNode g2 = login("tp-grandma", "金阿嬤", "1948/05/01");
        JsonNode s2 = login("tp-son", "金大森", "1980/02/02");
        assert "ELDER".equals(g2.get("role").asText()) && g2.get("linked").asBoolean();
        assert "FAMILY".equals(s2.get("role").asText()) && s2.get("linked").asBoolean();
        assert g2.get("id").asText().equals(g); // 同一個台北通帳號 → 同一個使用者
        // 登入時一起帶回首頁資料（少一趟網路來回）
        assert g2.get("home").get("delegations").size() == 1;
        assert g2.get("home").get("sync").get("stamp").isTextual();
        assert s2.get("home").get("bookings").size() == 0;

        // 4. 已綁定就不能換身分
        mvc.perform(post("/api/me/reset-role").header("X-User-Id", s))
                .andExpect(status().isConflict());
        mvc.perform(post("/api/me/role").header("X-User-Id", s)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"role\":\"ELDER\"}"))
                .andExpect(status().isConflict());

        // 5. 家屬不能產生邀請碼、長輩不能輸入邀請碼
        mvc.perform(post("/api/invitations").header("X-User-Id", s)).andExpect(status().isForbidden());
    }

    @Test
    void canChooseAndResetRoleBeforeBinding() throws Exception {
        String id = login("tp-new", "新使用者", "1990/01/01").get("id").asText();
        mvc.perform(post("/api/me/role").header("X-User-Id", id)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"role\":\"FAMILY\"}"))
                .andExpect(jsonPath("$.role").value("FAMILY"));
        mvc.perform(post("/api/me/reset-role").header("X-User-Id", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").doesNotExist());
    }

    @Test
    void loginWithoutIdIsRejected() throws Exception {
        mvc.perform(post("/api/auth/townpass").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest());
    }
}
