#!/usr/bin/env bash
# 建置 Flutter Web 並部署到 Firebase Hosting。
#
# 網頁放在 /app/ 底下（根目錄只有 index.html），好處：
# - 以後若要讓所有手機重新下載全部檔案（例如快取出問題），把 APP_DIR 換個名字再部署即可
# - 台北通的網址（根目錄）不用改
#
# 用法：./deploy-web.sh https://xxxx.ngrok-free.dev/api
set -euo pipefail
API_BASE="${1:?請給後端網址，例如 https://xxxx.ngrok-free.dev/api}"
APP_DIR="app"

cd "$(dirname "$0")"
flutter build web --release --no-web-resources-cdn --base-href "/$APP_DIR/" --dart-define=API_BASE="$API_BASE"

rm -rf hosting
mkdir -p "hosting/$APP_DIR"
cp -R build/web/. "hosting/$APP_DIR/"
cp build/web/index.html hosting/index.html   # 根目錄的首頁（<base href="/app/">）

# 加速：一打開頁面就先和後端（ngrok）建立連線，第一個 API 請求不用再等連線握手
ORIGIN="$(python3 -c 'import sys,urllib.parse as u;p=u.urlparse(sys.argv[1]);print(f"{p.scheme}://{p.netloc}")' "$API_BASE")"
for f in hosting/index.html "hosting/$APP_DIR/index.html"; do
  python3 - "$f" "$ORIGIN" <<'PY'
import sys
path, origin = sys.argv[1], sys.argv[2]
s = open(path, encoding='utf-8').read()
tag = f'<link rel="preconnect" href="{origin}" crossorigin>'
if tag not in s:
    s = s.replace('<meta charset="UTF-8">', '<meta charset="UTF-8">\n  ' + tag, 1)
open(path, 'w', encoding='utf-8').write(s)
PY
done

firebase deploy --only hosting
