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

## 2. 匯入開放資料

1. 到 data.taipei 或 data.gov.tw 搜尋「**臺北市銀髮族服務-社區照顧關懷據點**」（臺北市政府社會局，政府資料開放授權條款第 1 版），下載 CSV。
2. 存成 `backend/src/main/resources/data/service_points.csv`。
3. 刪掉 `backend/data/` 資料夾（清空資料庫），重新啟動，log 會顯示「已匯入 N 筆」。
4. 如果出現亂碼，到 `application.yml` 把 `app.open-data.charset` 改成 `Big5`。
5. 程式會依表頭名稱自動對應欄位。如果 log 顯示「找不到名稱欄位」，就把實際欄名加進 `DataSeeder.NAME_COLS`。

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

## 語音朗讀（長者端）

設計前提：長輩可能不太識字。
- 每頁打開時自動唸出這頁的內容，以及該按「什麼顏色」的按鈕（綠：讓家人幫忙／藍：誰在幫我／橘：做過的事／紅：收回／灰：不同意、換號碼）
- 邀請碼一個字一個字唸（「一，二，三…」），連續唸兩次，並附上防詐提醒
- 同意頁一項一項唸；點一下就打勾，並唸出「打勾了」或「取消了」
- 長按任何大按鈕，會唸出它是做什麼的；點紀錄、點家人的名字也會唸
- 「再聽一次」大喇叭：黃底黑框，固定在每頁右上角，正在唸的時候圖示會變成音波

使用 `flutter_tts`（MIT 授權），呼叫裝置內建的語音引擎，不經過雲端 AI，因此不受 LLM 規定限制。瀏覽器規定使用者要先點過畫面才能出聲。

## 測試用帳號（模擬資料）

Demo 使用以下台北通帳號。身分依生日自動判定（65 歲以上是長者，18–64 歲是家屬），第一次登入時自動建立。

| 台北通帳號 ID | 名稱 | 生日 | 身分 | 用途 |
|---|---|---|---|---|
| `7f3562f4-bb3f-4ec7-89b9-da3b4b5ff250` | 金大森 | 1988/12/12 | 家屬 | 台北通預設帳號（`TownPass/assets/mock_data/account.json`） |
| `grandma-0001` | 金阿嬤 | 1950/03/02 | 長者 | 手機 Demo：把 `account.json` 的 `id`、`realName`、`birthday` 改成這組再打包台北通 |
| `demo-townpass-grandma` | 金阿嬤 | 1950/03/02 | 長者 | 不在台北通裡（電腦瀏覽器）時，開發測試選單的帳號 |
| `demo-townpass-relative` | 金小妹 | 1995/06/18 | 家屬 | 同上，開發測試選單的帳號 |

> 後端第一次啟動時會先建立這四個帳號（id 依序是 1 金阿嬤（瀏覽器）、2 金小妹、3 金大森、4 金阿嬤（手機）），後端自動測試（`mvn test`）和 `demo.sh` 也是用這幾個帳號。

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


## 授權

AGPL-3.0-or-later，Copyright (C) 2026 麻辣燙不加辣。授權全文見 repo 根目錄的 [`LICENSE`](../LICENSE)（https://www.gnu.org/licenses/agpl-3.0.txt）。
