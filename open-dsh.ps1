# ============================================================
#  DSH 自动启动器  — 主脚本
#  流程：1) 命令行获取 DSH 地址  2) 查找夸克浏览器
#        3) 通过夸克浏览器打开 http://localhost:3080/
#  用法：直接运行，或  powershell -ExecutionPolicy Bypass -File open-dsh.ps1
#       加参数 -DryRun 可只演示流程而不真正打开浏览器
# ============================================================
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
# 保证控制台按 UTF-8 显示中文（解决 Windows PowerShell 5.1 乱码问题）
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$DSH_URL = 'http://localhost:3080/'

function Write-Step($text) { Write-Host $text -ForegroundColor Yellow }
function Write-Ok($text)   { Write-Host "      $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "      $text" -ForegroundColor DarkYellow }

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "              DSH 自动启动器" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ---------------- 第 1 步：通过命令行获取 DSH 地址 ----------------
Write-Step "[1/3] 正在获取 DSH 地址 ..."

# 1a) 检查 3080 端口是否在监听
$portListening = $false
try {
    $conn = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction Stop
    if ($conn) { $portListening = $true }
} catch { }
if ($portListening) {
    Write-Ok "端口 3080 正在监听，DSH 服务已启动。"
} else {
    Write-Warn "端口 3080 未检测到监听，DSH 可能尚未启动（仍将尝试打开）。"
}

# 1b) 用 HTTP 请求确认服务可用
try {
    $resp = Invoke-WebRequest -Uri $DSH_URL -UseBasicParsing -TimeoutSec 3
    Write-Ok "HTTP 请求成功，状态码: $($resp.StatusCode)"
} catch {
    Write-Warn "HTTP 请求暂时无响应（服务可能还在启动中）。"
}

# 1c) 列出本机可访问的地址（本机 + 局域网 IP）
$addr = @($DSH_URL)
try {
    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Select-Object -ExpandProperty IPAddress
    foreach ($ip in $ips) { $addr += "http://$ip`:3080/" }
} catch { }
Write-Ok "DSH 地址: $($addr -join '   |   ')"
Write-Host ""

# ---------------- 第 2 步：查找夸克浏览器 ----------------
Write-Step "[2/3] 正在查找夸克浏览器 ..."
$quark = $null

# 2a) 常见安装路径
$candidates = @(
    "$env:LOCALAPPDATA\Quark\Application\Quark.exe",
    "$env:ProgramFiles\Quark\Application\Quark.exe",
    "${env:ProgramFiles(x86)}\Quark\Application\Quark.exe",
    "$env:LOCALAPPDATA\Programs\Quark\Application\Quark.exe"
)
foreach ($p in $candidates) {
    if (Test-Path -LiteralPath $p) { $quark = $p; break }
}

# 2b) 开始菜单快捷方式
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

# 2c) 注册表卸载信息
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

if ($quark) {
    Write-Ok "找到夸克浏览器: $quark"
} else {
    Write-Warn "未找到夸克浏览器，将回退到系统默认浏览器。"
}
Write-Host ""

# ---------------- 第 3 步：打开 DSH ----------------
Write-Step "[3/3] 正在打开 DSH ..."
if ($DryRun) {
    if ($quark) { Write-Ok "[演示模式] 将执行: Start-Process '$quark' -ArgumentList '$DSH_URL'" }
    else        { Write-Ok "[演示模式] 将执行: Start-Process '$DSH_URL'" }
} else {
    if ($quark) {
        Start-Process -FilePath $quark -ArgumentList $DSH_URL
        Write-Ok "已通过夸克浏览器打开: $DSH_URL"
    } else {
        Start-Process $DSH_URL
        Write-Ok "已通过默认浏览器打开: $DSH_URL"
    }
}

Write-Host ""
Write-Host "完成！" -ForegroundColor Cyan
Write-Host ""
