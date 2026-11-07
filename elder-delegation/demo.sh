#!/usr/bin/env bash
# 後端煙霧測試：跑完整 Demo 流程。先啟動後端，再執行 ./demo.sh
# 需要 curl 和 jq（mac: brew install jq）
set -euo pipefail
API=${API:-http://localhost:8080/api}
ELDER=1; FAMILY=2

say() { printf '\n\033[1;34m▶ %s\033[0m\n' "$1"; }
call() { local who=$1; shift; curl -sS -H "X-User-Id: $who" -H 'Content-Type: application/json' "$@"; echo; }

say "家屬在沒授權時查看長輩資料（應該 403）"
call $FAMILY "$API/elders/$ELDER/profile"

say "1. 陳阿嬤產生邀請碼"
CODE=$(call $ELDER -X POST "$API/invitations" | jq -r .code)
echo "邀請碼：$CODE"

say "2. 陳小明輸入邀請碼"
DID=$(call $FAMILY -X POST "$API/invitations/accept" -d "{\"code\":\"$CODE\"}" | jq -r .id)
echo "授權編號：$DID"

say "3. 陳阿嬤同意：查看資料 + 報名活動，30 天"
call $ELDER -X POST "$API/delegations/$DID/approve" -d '{"scopes":["VIEW_INFO","BOOK_SERVICE"],"days":30}'

say "4. 陳小明查看長輩資料"
call $FAMILY "$API/elders/$ELDER/profile"

say "5. 陳小明幫長輩報名第一個據點"
PID=$(curl -sS "$API/service-points" | jq -r '.[0].id')
call $FAMILY -X POST "$API/elders/$ELDER/bookings" -d "{\"servicePointId\":$PID}"

say "6. 陳阿嬤收回授權"
call $ELDER -X POST "$API/delegations/$DID/revoke"

say "7. 陳小明再查看（應該 403）"
call $FAMILY "$API/elders/$ELDER/profile"

say "8. 陳阿嬤看「誰幫我做了什麼」"
call $ELDER "$API/elders/$ELDER/logs" | jq -r '.[] | "\(.createdAt)  \(.message)"'
