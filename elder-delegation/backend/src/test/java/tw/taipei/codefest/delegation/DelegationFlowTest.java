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
 * 跑完整 Demo 流程：邀請 → 綁定 → 同意 → 代辦 → 撤回 → 被擋。
 * 指令：mvn test
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "app.open-data.csv=classpath:does-not-exist.csv"
})
@AutoConfigureMockMvc
class DelegationFlowTest {
    private static final String ELDER = "1";   // 金阿嬤
    private static final String FAMILY = "2";  // 金小妹
    private static final String STRANGER = "3"; // 金大森（沒有授權）

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    @Test
    void fullDemoFlow() throws Exception {
        // 沒授權的家屬不能看資料
        mvc.perform(get("/api/elders/1/profile").header("X-User-Id", FAMILY))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NO_DELEGATION"));

        // 1. 長者產生邀請碼
        String code = body(mvc.perform(post("/api/invitations").header("X-User-Id", ELDER))
                .andExpect(status().isCreated()).andReturn()).get("code").asText();

        // 2. 家屬輸入邀請碼
        long delegationId = body(mvc.perform(post("/api/invitations/accept").header("X-User-Id", FAMILY)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("PENDING")).andReturn()).get("id").asLong();

        // 邀請碼不能用第二次
        mvc.perform(post("/api/invitations/accept").header("X-User-Id", STRANGER)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isNotFound());

        // 待同意期間仍然不能代辦
        mvc.perform(get("/api/elders/1/profile").header("X-User-Id", FAMILY))
                .andExpect(status().isForbidden());

        // 長者看到待同意
        mvc.perform(get("/api/delegations/pending").header("X-User-Id", ELDER))
                .andExpect(jsonPath("$[0].familyName").value("金小妹"));

        // 家屬不能自己同意
        mvc.perform(post("/api/delegations/" + delegationId + "/approve").header("X-User-Id", FAMILY)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"scopes\":[\"VIEW_INFO\"],\"days\":30}"))
                .andExpect(status().isForbidden());

        // 3. 長者只同意「查看資料」
        mvc.perform(post("/api/delegations/" + delegationId + "/approve").header("X-User-Id", ELDER)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"scopes\":[\"VIEW_INFO\"],\"days\":30}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACTIVE"));

        // 4. 家屬可以看資料
        mvc.perform(get("/api/elders/1/profile").header("X-User-Id", FAMILY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("金阿嬤"));

        // 但不能報名（沒授權 BOOK_SERVICE）
        mvc.perform(post("/api/elders/1/bookings").header("X-User-Id", FAMILY)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"servicePointId\":1}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("SCOPE_DENIED"));

        // 別的家屬完全不能看
        mvc.perform(get("/api/elders/1/profile").header("X-User-Id", STRANGER))
                .andExpect(status().isForbidden());

        // 長者本人永遠可以
        mvc.perform(post("/api/elders/1/bookings").header("X-User-Id", ELDER)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"servicePointId\":1}"))
                .andExpect(status().isCreated());

        // 5. 長者收回授權
        mvc.perform(post("/api/delegations/" + delegationId + "/revoke").header("X-User-Id", ELDER))
                .andExpect(jsonPath("$.status").value("REVOKED"));

        // 6. 立刻失效
        mvc.perform(get("/api/elders/1/profile").header("X-User-Id", FAMILY))
                .andExpect(status().isForbidden());

        // 7. 操作紀錄完整，且只有長者本人能看
        mvc.perform(get("/api/elders/1/logs").header("X-User-Id", FAMILY))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/elders/1/logs").header("X-User-Id", ELDER))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].action").value("DELEGATION_REVOKED"))
                .andExpect(jsonPath("$.length()").value(4)); // 申請、同意、查看資料、收回
    }

    @Test
    void missingLoginIs401() throws Exception {
        mvc.perform(get("/api/delegations")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/service-points")).andExpect(status().isOk()); // 公開
    }

    private JsonNode body(MvcResult r) throws Exception {
        return json.readTree(r.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }
}
