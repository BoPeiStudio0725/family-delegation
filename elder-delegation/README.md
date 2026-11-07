# 家人代辦｜長者家屬授權微服務

2026 臺北秋季程式設計節・城市通微服務大黑客松（主題：數位平權 × 友善共融）

長者用一組 6 位數邀請碼綁定家屬，**自己勾選**家屬可以幫忙的事和期限。家屬只能在授權範圍內代辦，每一次操作都會留下紀錄，長者隨時可以一鍵收回。

```
長者產生邀請碼 → 家屬輸入 → 長者勾選範圍並同意 → 家屬代辦 → 留下紀錄 → 長者可收回
```

## 專案結構

```
backend/   Spring Boot 3 + JPA（H2 免安裝 / PostgreSQL）
flutter/   lib/delegation/ 可直接複製進城市通 Flutter 專案
demo.sh    後端整條流程的 curl 測試
```

## 1. 啟動後端（Java 17+、Maven）

```bash
cd backend
mvn spring-boot:run          # http://localhost:8080
mvn test                     # 跑完整授權流程的自動測試
```

改用 PostgreSQL：在專案根目錄執行 `docker compose up --build`。

確認後端正常（需要 jq）：在專案根目錄執行 `./demo.sh`，整條流程會依序印出來，最後兩步應該分別是 403 和操作紀錄。

## 2. 匯入開放資料（重要：評分項目「資料來源正確」）

1. 到 data.taipei 或 data.gov.tw 搜尋「**臺北市銀髮族服務-社區照顧關懷據點**」（臺北市政府社會局，政府資料開放授權條款第 1 版），下載 CSV。
2. 存成 `backend/src/main/resources/data/service_points.csv`。
3. 刪掉 `backend/data/` 資料夾（清空資料庫），重新啟動，log 會顯示「已匯入 N 筆」。
4. 如果出現亂碼，到 `application.yml` 把 `app.open-data.charset` 改成 `Big5`。
5. 程式會依表頭名稱自動對應欄位。如果 log 顯示「找不到名稱欄位」，就把實際欄名加進 `DataSeeder.NAME_COLS`。

沒放 CSV 時會自動建立名稱帶【示範】的假據點。**Demo 前一定要換成真資料。**

## 3. 啟動 Flutter（建置成網頁，放進台北通 webview）

「家人代辦」是台北通的**網頁型微服務**：Flutter 建置成 Web，由台北通 App 用 `TPWebView` 開啟（就是上方有藍綠色標題列和 X 的那種畫面）。

```bash
cd flutter
flutter pub get
# 開發測試（直接用 Chrome）：會出現「開發測試模式」，可以選模擬的台北通帳號
flutter run -d chrome
# 給台北通 webview 開：讓同網路的手機或模擬器連得到
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 5000
```

- 後端位址：**沒有設定時，自動用「網頁所在主機的 8080 port」**。網頁和後端跑在同一台電腦上，就不用另外設定。不在同一台的話，加上 `--dart-define=API_BASE=http://<後端IP>:8080/api`。
- 在台北通原始碼的 `lib/page/city_service/model/my_service_model.dart` 加一個服務，`destinationUrl` 填 `http://<電腦IP>:5000/`，`forceWebViewTitle` 填 `家人代辦`。
- **Android 版台北通**：台北通預設不允許 http，要在台北通的 `android/app/src/main/AndroidManifest.xml` 的 `<application` 加上 `android:usesCleartextTraffic="true"`。另外，Android WebView 不支援網頁語音朗讀，所以 Demo 建議用 iOS。

## 台北通登入與身分辨識

```
從台北通打開「家人代辦」
  → 透過台北通注入的 flutterObject 送出 userinfo，取得登入帳號（id、姓名、生日…）
  → POST /api/auth/townpass 登入後端
  → 後端依「綁定關係」回傳身分
       ELDER  → 直接進長者介面（讓家人幫我、誰在幫我、做過的事）
       FAMILY → 直接進家屬介面（輸入邀請碼、幫長輩報名、查看資料）
       還沒有 → 選擇身分頁（第一次使用）
```

- **第一次使用**：選擇身分頁會依台北通的生日給建議（65 歲以上把「我是長輩」排在前面），但由使用者自己決定。
- **綁定時記住身分**：長輩產生邀請碼時記為長輩，家屬輸入邀請碼時記為家屬。之後再從台北通打開，就直接進入對應的介面。
- **選錯可以改**：還沒有任何綁定時，首頁下方有「重新選擇身分」。已經綁定就不能換，避免關係錯亂。
- **對應的程式**：前端在 `lib/delegation/townpass/`、`entry.dart`；後端在 `AccountService`、`AccountController`。
- **正式上線**：要改成驗證台北通發的 token，不能直接相信前端傳來的帳號 id。目前是黑客松版本。

### Demo 時要兩個不同的台北通帳號

台北通的帳號是假資料，寫在台北通原始碼的 `assets/mock_data/account.json`，預設是「金大森」。要讓兩台模擬器登入不同的人：

1. 模擬器 A 直接 `flutter run -d <A>`，登入的是預設的金大森（當家屬）。
2. 把 `account.json` 的 `id` 改成別的字串（例如 `grandma-0001`），`realName` 改成 `金阿嬤`，`birthday` 改成 `1950/03/02`，然後 `flutter run -d <B>`。B 會用改過的檔案重新建置，A 不受影響。

用 Chrome 開發時不需要這樣做，「開發測試模式」可以直接選金大森、金阿嬤、金小妹。

## 語音朗讀（長者端）

設計前提：長輩可能不太識字。
- 每頁打開時自動唸出這頁的內容，以及該按「什麼顏色」的按鈕（綠：讓家人幫忙／藍：誰在幫我／橘：做過的事／紅：收回／灰：不同意、換號碼）
- 邀請碼一個字一個字唸（「一，二，三…」），連續唸兩次，並附上防詐提醒
- 同意頁一項一項唸；點一下就打勾，並唸出「打勾了」或「取消了」
- 長按任何大按鈕，會唸出它是做什麼的；點紀錄、點家人的名字也會唸
- 「再聽一次」大喇叭：黃底黑框，固定在每頁右上角，正在唸的時候圖示會變成音波

使用 `flutter_tts`（MIT 授權），呼叫裝置內建的語音引擎，不經過雲端 AI，因此不受 LLM 規定限制。瀏覽器規定使用者要先點過畫面才能出聲。

## 測試用帳號（模擬資料，給 mvn test 和 demo.sh）

| id | 名稱 | 角色 |
|---|---|---|
| 1 | 陳阿嬤 | 長者 |
| 2 | 陳小明 | 家屬 |
| 3 | 林志明 | 家屬（用來示範「沒授權的人看不到」） |
| 4 | 王阿公 | 長者 |

從台北通進來的使用者，會在第一次登入時自動建立。

## API

| 方法 | 路徑 | 誰 | 說明 |
|---|---|---|---|
| POST | /api/auth/townpass | 公開 | 台北通帳號登入：`{"id","realName","birthday","phoneNo","district"}`，回傳 `{id, role, linked, suggestedRole}` |
| GET | /api/me | 已登入 | 自己的身分 |
| POST | /api/me/role | 已登入 | 選擇身分 `{"role":"ELDER"}`（已綁定不能換） |
| POST | /api/me/reset-role | 已登入 | 重新選擇身分（沒有綁定才可以） |
| POST | /api/invitations | 長者 | 產生 6 位數邀請碼（10 分鐘有效） |
| POST | /api/invitations/accept | 家屬 | `{"code":"123456"}` |
| GET | /api/delegations/pending | 長者 | 待同意的申請 |
| POST | /api/delegations/{id}/approve | 長者 | `{"scopes":["VIEW_INFO","BOOK_SERVICE"],"days":30}` |
| POST | /api/delegations/{id}/reject | 長者 | 拒絕 |
| POST | /api/delegations/{id}/revoke | 長者/家屬 | 收回 / 解除 |
| GET | /api/delegations | 都可 | 長者看「誰在幫我」，家屬看「我照顧的長輩」 |
| GET | /api/elders/{elderId}/profile | 本人或 VIEW_INFO | 基本資料 |
| GET | /api/elders/{elderId}/bookings | 本人或 VIEW_INFO | 報名紀錄 |
| POST | /api/elders/{elderId}/bookings | 本人或 BOOK_SERVICE | `{"servicePointId":1}` |
| DELETE | /api/elders/{elderId}/bookings/{id} | 本人或 BOOK_SERVICE | 取消報名 |
| GET | /api/elders/{elderId}/logs | 僅長者本人 | 誰幫我做了什麼 |
| GET | /api/service-points?district= | 公開 | 開放資料據點 |
| GET | /api/service-points/districts | 公開 | 各區據點數 |

錯誤格式一律是 `{"code":"SCOPE_DENIED","message":"長輩沒有授權您「幫我報名據點活動」"}`，前端直接顯示 message。

## 權限設計（評審問架構時講這段）

- 所有代辦 API 都標上 `@RequiresScope(...)`，由 `ScopeInterceptor` 統一檢查。檢查四件事：是不是本人、有沒有生效中的授權、有沒有過期、範圍夠不夠。
- 檢查通過、而且操作成功之後，同一個 interceptor 會自動寫一筆 `ActionLog`，不會漏記。
- 新增代辦項目只要兩步：在 `Enums.Scope` 加一個值，然後在 API 上標註，權限和紀錄就自動生效。
- 授權有期限，長者可以隨時收回，收回後立刻生效。

## 2 分鐘 Demo 腳本

用兩台模擬器開台北通：左邊是長輩（金阿嬤），右邊是家屬（金大森）。開場先示範「第一次使用」的選擇身分頁，綁定之後關掉再從台北通打開，畫面會直接進入長輩或家屬介面。

1. 痛點（10 秒）：長輩不會用 App，家人只好拿長輩的手機、記長輩的密碼。這樣既不安全，也沒有紀錄。
2. 阿嬤按「讓家人幫我辦事」，畫面出現大字號碼。
3. 小明輸入號碼，阿嬤的手機自動跳到同意頁。
4. 阿嬤勾選「查看我的資料」和「幫我報名據點活動」，期限選 30 天，按同意。
5. 小明從開放資料據點中幫阿嬤報名。（決選 5 分鐘時可以加演：另一位家屬只拿到「查看資料」的授權，按報名會被擋下。）
6. 阿嬤打開「家人幫我做過的事」，每一筆操作都看得到。
7. 阿嬤按「收回」，小明再按報名，跳出「長輩已收回授權」。
8. 收尾：長者保有自主權，家人也能安心代辦。

## 授權

AGPL-3.0-or-later。依活動須知第捌條，請在根目錄放 `LICENSE`，內容為 https://www.gnu.org/licenses/agpl-3.0.txt 的全文，並把 `DelegationApplication.java` 開頭的 `<隊名>` 換成你們的隊名。
