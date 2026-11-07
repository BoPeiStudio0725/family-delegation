# 一鍵啟動「家人代辦」後端
# 1. 停掉占用 8080 的舊後端  2. 清掉舊資料庫  3. 編譯並啟動新版
# 所有輸出同時存到 backend\run.log
$ErrorActionPreference = 'Continue'
$backend = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $backend
Set-Location $backend
$log = Join-Path $backend 'run.log'
"=== 啟動時間 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $log -Encoding utf8

function Say($msg) { Write-Host $msg -ForegroundColor Cyan; $msg | Out-File $log -Append -Encoding utf8 }

# --- 1. 停掉占用 8080 的程式（通常是還在跑的舊版後端）---
$conns = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
foreach ($c in $conns) {
    $p = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
    if ($p) {
        Say "[1] 8080 被 $($p.ProcessName)（PID $($p.Id)）占用，停止它…"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
if (-not $conns) { Say '[1] 8080 沒有被占用' }
Start-Sleep -Seconds 2

# --- 2. 清掉舊資料庫（資料表結構改過）---
if (Test-Path (Join-Path $backend 'data')) {
    Remove-Item -Recurse -Force (Join-Path $backend 'data') -ErrorAction SilentlyContinue
    Say '[2] 已刪除舊資料庫 backend\data'
} else { Say '[2] 沒有舊資料庫' }

# 順便清掉 Flutter 舊版留下、已經不用的檔案
foreach ($f in @('flutter\lib\delegation\demo_entry.dart', 'flutter\lib\delegation\phrases.dart', 'flutter\assets')) {
    $full = Join-Path $root $f
    if (Test-Path $full) { Remove-Item -Recurse -Force $full -ErrorAction SilentlyContinue; Say "    已刪除舊檔 $f" }
}

# --- 3. 找到 Maven ---
$mvn = Get-Command mvn -ErrorAction SilentlyContinue
if (-not $mvn) {
    $guess = Get-ChildItem (Join-Path $env:USERPROFILE 'tools') -Directory -Filter 'apache-maven-*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($guess) { $env:Path = (Join-Path $guess.FullName 'bin') + ';' + $env:Path; Say "[3] 使用 $($guess.FullName)" }
}
if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) {
    Say '[3] 找不到 Maven（mvn），請把畫面拍給 Claude'
    Read-Host '按 Enter 關閉'
    exit 1
}
# 找真正的 JDK：問 java 自己裝在哪（Oracle 的 javapath 捷徑資料夾不是 JDK）
function IsJdk($p) { return $p -and (Test-Path (Join-Path $p 'bin\javac.exe')) }
if (-not (IsJdk $env:JAVA_HOME)) {
    $env:JAVA_HOME = $null
    $props = & java -XshowSettings:properties -version 2>&1 | ForEach-Object { "$_" }
    $line = $props | Where-Object { $_ -match '^\s*java\.home\s*=' } | Select-Object -First 1
    if ($line) {
        $jh = ($line -split '=', 2)[1].Trim()
        if (IsJdk $jh) { $env:JAVA_HOME = $jh }
    }
    if (-not $env:JAVA_HOME) {
        $cand = Get-ChildItem 'C:\Program Files\Java' -Directory -ErrorAction SilentlyContinue |
            Where-Object { IsJdk $_.FullName } | Sort-Object Name -Descending | Select-Object -First 1
        if ($cand) { $env:JAVA_HOME = $cand.FullName }
    }
}
if (-not (IsJdk $env:JAVA_HOME)) {
    Say '[3] 找不到 JDK（需要有 javac 的 Java），請把這個畫面給 Claude 看'
    Read-Host '按 Enter 關閉'
    exit 1
}
Say "[3] Maven OK，JAVA_HOME=$env:JAVA_HOME"

# --- 4. 編譯並啟動（看到 Tomcat started on port 8080 就成功）---
Say '[4] 編譯並啟動中，第一次會比較久…'
& mvn -B clean spring-boot:run 2>&1 | ForEach-Object { $line = "$_"; Write-Host $line; $line | Out-File $log -Append -Encoding utf8 }
Say '後端已停止。'
Read-Host '按 Enter 關閉'
