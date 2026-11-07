# 家人代辦（Family Delegation）

台北通（城市通）「家人代辦」微服務：長輩授權家人代辦事項（查看資料、報名社區關懷據點活動），長輩隨時可收回，每一筆操作都留紀錄。

| 資料夾 | 內容 |
|---|---|
| [`elder-delegation/`](elder-delegation/) | 家人代辦本體：Flutter Web 前端（長者／家屬介面）＋ Spring Boot 後端 |
| [`TownPass/`](TownPass/) | 台北通 App（[taipei-doit/TownPass](https://github.com/taipei-doit/TownPass)）加上「家人代辦」入口、原生語音朗讀（`speak` web message）、網頁免點擊出聲設定 |

詳細說明見 [elder-delegation/README.md](elder-delegation/README.md)。

## 授權

- 家人代辦（`elder-delegation/`）：AGPL-3.0-or-later，Copyright (C) 2026 麻辣燙不加辣，全文見 [`LICENSE`](LICENSE)。
- 台北通（`TownPass/`）：沿用原專案的授權，見 [`TownPass/LICENSE`](TownPass/LICENSE)。
