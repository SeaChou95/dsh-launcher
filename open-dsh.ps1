# ============================================================
#  DSH 自动启动器 — 主脚本
#
#  功能：自动获取 DSH(DeepSeek Harness) 的地址，
#        然后用浏览器打开 DSH Web 界面。
#
#  浏览器策略（-Browser 参数）：
#    auto    （默认）优先使用夸克浏览器，找不到就使用系统默认浏览器
#    default 始终使用系统默认浏览器（任何机器都可用）
#    quark   只尝试夸克浏览器，找不到则提示手动打开
#
#  用法示例：
#    powershell -ExecutionPolicy Bypass -File open-dsh.ps1
#    powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -Browser default
#    powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -Url http://localhost:3080/ -DryRun
#
#  日常使用请双击“启动DSH.vbs”（无窗口）；需要看详细输出时用 启动DSH.bat 前台调试。
# ============================================================
param(
    [string]$Url = 'http://localhost:3080/',
    [ValidateSet('auto', 'default', 'quark')]
    [string]$Browser = 'auto',
    [switch]$DryRun,
    [switch]$Log
)

$ErrorActionPreference = 'Continue'
# 保证控制台按 UTF-8 显示中文（解决 Windows PowerShell 5.1 乱码问题）
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$DSH_URL = $Url

# ---------------- 日志（-Log 时写入同目录 launcher.log） ----------------
$logPath = Join-Path $PSScriptRoot 'launcher.log'
function LogWrite($msg) {
    if ($Log) {
        try { Add-Content -Path $logPath -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding UTF8 } catch { }
    }
}
function Write-Step($text) { Write-Host $text -ForegroundColor Yellow; LogWrite $text }
function Write-Ok($text)   { Write-Host "      $text" -ForegroundColor Green; LogWrite "OK: $text" }
function Write-Warn($text) { Write-Host "      $text" -ForegroundColor DarkYellow; LogWrite "WARN: $text" }

LogWrite "=== 开始 (Url=$DSH_URL, Browser=$Browser) ==="
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "              DSH 自动启动器" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ---------------- 第 1 步：获取 DSH 地址 ----------------
Write-Step "[1/4] 正在获取 DSH 地址 ..."

# 从地址解析端口（支持自定义 -Url 端口）
$port = ([uri]$DSH_URL).Port
if ($port -le 0) { $port = if ($DSH_URL -like 'https*') { 443 } else { 80 } }

$portListening = $false
try {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop
    if ($conn) { $portListening = $true }
} catch { }
if ($portListening) {
    Write-Ok "端口 $port 正在监听，DSH 服务已启动。"
} else {
    Write-Warn "端口 $port 未检测到监听，DSH 可能尚未启动（仍将尝试打开）。"
}

try {
    $resp = Invoke-WebRequest -Uri $DSH_URL -UseBasicParsing -TimeoutSec 3
    Write-Ok "HTTP 请求成功，状态码: $($resp.StatusCode)"
} catch {
    Write-Warn "HTTP 请求暂时无响应（服务可能还在启动中）。"
}

$addr = @($DSH_URL)
try {
    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Select-Object -ExpandProperty IPAddress
    foreach ($ip in $ips) { $addr += "http://$ip`:$port/" }
} catch { }
Write-Ok "DSH 地址: $($addr -join '   |   ')"
Write-Host ""

# ---------------- 第 2 步：确定浏览器 ----------------
Write-Step "[2/4] 正在确定浏览器 ..."

# 查找夸克浏览器（多层策略：安装路径 -> 开始菜单 -> 注册表卸载信息）
$quark = $null
$candidates = @(
    "$env:LOCALAPPDATA\Quark\Application\Quark.exe",
    "$env:ProgramFiles\Quark\Application\Quark.exe",
    "${env:ProgramFiles(x86)}\Quark\Application\Quark.exe",
    "$env:LOCALAPPDATA\Programs\Quark\Application\Quark.exe"
)
foreach ($p in $candidates) {
    if (Test-Path -LiteralPath $p) { $quark = $p; break }
}
if (-not $quark) {
    $lnk = @(
        (Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu" -Filter '*夸克*' -Recurse -ErrorAction SilentlyContinue),
        (Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu" -Filter '*Quark*' -Recurse -ErrorAction SilentlyContinue),
        (Get-ChildItem "$env:ProgramData\Microsoft\Windows\Start Menu" -Filter '*夸克*' -Recurse -ErrorAction SilentlyContinue),
        (Get-ChildItem "$env:ProgramData\Microsoft\Windows\Start Menu" -Filter '*Quark*' -Recurse -ErrorAction SilentlyContinue)
    ) | Where-Object { $_ } | Select-Object -First 1
    if ($lnk) {
        try {
            $sh = New-Object -ComObject WScript.Shell
            $target = $sh.CreateShortcut($lnk.FullName).TargetPath
            if ($target -and (Test-Path -LiteralPath $target)) { $quark = $target }
        } catch { }
    }
}
if (-not $quark) {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($k in $keys) {
        Get-ItemProperty $k -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like '*夸克*' -or $_.DisplayName -like '*Quark*' } |
            ForEach-Object {
                $exe = Join-Path $_.InstallLocation 'Quark.exe'
                if ($_.InstallLocation -and (Test-Path -LiteralPath $exe)) { $quark = $exe }
            }
        if ($quark) { break }
    }
}

# 识别系统默认浏览器（注册表 UserChoice）
function Get-DefaultBrowser {
    $progId = $null
    try { $progId = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice' -ErrorAction Stop).ProgId } catch { }
    if (-not $progId) { try { $progId = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction Stop).ProgId } catch { } }
    $names = @{
        'QuarkHTM' = '夸克浏览器'; 'ChromeHTML' = 'Google Chrome'; 'MSEdgeHTM' = 'Microsoft Edge';
        'FirefoxURL' = 'Mozilla Firefox'; 'OperaStable' = 'Opera'; 'BraveHTML' = 'Brave';
        '360se6URL' = '360 安全浏览器'; 'SogouExplorer' = '搜狗浏览器'; 'QQBrowser' = 'QQ 浏览器'
    }
    if ($progId -and $names.ContainsKey($progId)) { return $names[$progId] }
    if ($progId) { return $progId }
    return '系统默认浏览器'
}
$defaultName = Get-DefaultBrowser

# 按策略决定打开方式
$openBrowser = 'default'   # default / quark / none
switch ($Browser) {
    'default' {
        Write-Ok "使用系统默认浏览器: $defaultName"
        $openBrowser = 'default'
    }
    'quark' {
        if ($quark) { Write-Ok "使用夸克浏览器: $quark"; $openBrowser = 'quark' }
        else { Write-Warn "未找到夸克浏览器（-Browser quark），本次无法自动打开"; $openBrowser = 'none' }
    }
    default {   # auto
        if ($quark) { Write-Ok "使用夸克浏览器: $quark"; $openBrowser = 'quark' }
        else { Write-Ok "未找到夸克浏览器，改用系统默认浏览器: $defaultName"; $openBrowser = 'default' }
    }
}
Write-Host ""

# ---------------- 第 3 步：打开 DSH ----------------
Write-Step "[3/4] 正在打开 DSH ..."
switch ($openBrowser) {
    'quark' {
        if ($DryRun) {
            Write-Ok "[演示模式] 将执行: Start-Process '$quark' -ArgumentList '$DSH_URL'"
        } else {
            Start-Process -FilePath $quark -ArgumentList $DSH_URL
            Write-Ok "已通过夸克浏览器打开: $DSH_URL"
        }
    }
    'default' {
        if ($DryRun) {
            Write-Ok "[演示模式] 将执行: Start-Process '$DSH_URL'（默认浏览器 $defaultName）"
        } else {
            Start-Process $DSH_URL
            Write-Ok "已通过默认浏览器（$defaultName）打开: $DSH_URL"
        }
    }
    'none' {
        Write-Warn "没有可用的浏览器，请手动打开: $DSH_URL"
    }
}

# ---------------- 第 4 步：完成 ----------------
Write-Host ""
Write-Step "[4/4] 完成"
Write-Host "完成！" -ForegroundColor Cyan
Write-Host ""
LogWrite "=== 结束 ==="
