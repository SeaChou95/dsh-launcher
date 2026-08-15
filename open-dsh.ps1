# ============================================================
#  DSH 自动启动器 — 主脚本
#
#  功能：
#    1) 自动获取 DSH(DeepSeek Harness) 的地址
#    2) 若 DSH web 未运行，自动运行 dsh web 把服务拉起来
#    3) 然后用浏览器打开 DSH Web 界面
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
#    powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -NoAutoStart    # 不自动启动 dsh web
#
#  日常使用请双击“启动DSH.vbs”（无窗口）；需要看详细输出时用 启动DSH.bat 前台调试。
# ============================================================
param(
    [string]$Url = 'http://localhost:3080/',
    [ValidateSet('auto', 'default', 'quark')]
    [string]$Browser = 'auto',
    [switch]$DryRun,
    [switch]$Log,
    [switch]$NoAutoStart
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

# ---------------- 工具函数 ----------------
function Test-PortListen($port) {
    return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
}
function Wait-Port($port, $maxSeconds) {
    for ($i = 0; $i -lt $maxSeconds; $i++) {
        if (Test-PortListen $port) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}
function Find-DshCommand {
    # 优先使用 dsh.cmd（cmd 脚本，Start-Process 可直接启动；dsh.ps1 不能直接 Start-Process）
    $c1 = Join-Path $env:APPDATA 'npm\dsh.cmd'
    if (Test-Path -LiteralPath $c1) { return $c1 }
    $c = Get-Command dsh.cmd -ErrorAction SilentlyContinue
    if ($c -and $c.Source) { return $c.Source }
    $c2 = Get-Command dsh -ErrorAction SilentlyContinue
    if ($c2 -and $c2.Source -and $c2.Source -like '*.cmd') { return $c2.Source }
    try {
        $prefix = (& npm.cmd prefix -g 2>$null | Select-Object -Last 1)
        if ($prefix) {
            $c3 = Join-Path $prefix 'dsh.cmd'
            if (Test-Path -LiteralPath $c3) { return $c3 }
        }
    } catch { }
    return $null
}

function Start-DshWebHidden($file, $argList) {
    # 用 ProcessStartInfo + CreateNoWindow 让子进程真正脱离当前控制台：
    #   1) 子进程没有自己的控制台窗口（彻底无窗口）
    #   2) 子进程不挂靠在启动器的控制台上，关闭启动器窗口不会连带杀死它
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $file
    $quoted = @()
    foreach ($a in $argList) { $quoted += '"' + ($a -replace '"', '\"') + '"' }
    $psi.Arguments = ($quoted -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    # 工作目录用用户主目录，而不是启动器所在目录：
    # dsh web 会把会话/报错文件写到进程工作目录，设成启动器目录会导致会话错乱
    $psi.WorkingDirectory = $env:USERPROFILE
    [System.Diagnostics.Process]::Start($psi) | Out-Null
}

LogWrite "=== 开始 (Url=$DSH_URL, Browser=$Browser, NoAutoStart=$NoAutoStart) ==="
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "              DSH 自动启动器" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ---------------- 第 1 步：获取 DSH 地址并确保服务运行 ----------------
Write-Step "[1/4] 正在获取 DSH 地址 ..."

# 从地址解析端口和主机（支持自定义 -Url）
$uriObj = [uri]$DSH_URL
$port = $uriObj.Port
if ($port -le 0) { $port = if ($DSH_URL -like 'https*') { 443 } else { 80 } }
$hostName = $uriObj.Host

if (Test-PortListen $port) {
    Write-Ok "端口 $port 正在监听，DSH web 已运行。"
} else {
    if ($NoAutoStart) {
        Write-Warn "端口 $port 未监听（已跳过自动启动），请先手动运行 dsh web。"
    } else {
        Write-Warn "端口 $port 未监听，DSH web 尚未运行，尝试自动启动 ..."
        $dsh = Find-DshCommand
        # 优先用 node 直接跑 bin.js（node 是控制台程序，-WindowStyle Hidden 能彻底隐藏窗口；
        # 而 dsh.cmd 是批处理脚本，隐藏不彻底会闪出黑窗口）
        $node = (Get-Command node -ErrorAction SilentlyContinue).Source
        $binJs = Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh\lib\bin.js'
        $launchFile = $null
        $launchArgs = @()
        if ($node -and (Test-Path -LiteralPath $binJs)) {
            $launchFile = $node
            $launchArgs = @($binJs, 'web')
        } elseif ($dsh) {
            $launchFile = $dsh
            $launchArgs = @('web')
        }
        if ($launchFile) {
            if ($port -ne 3080) { $launchArgs += @('--port', "$port") }
            $isLocal = ($hostName -eq 'localhost' -or $hostName -eq '127.0.0.1' -or $hostName -eq '::1')
            if (-not $isLocal) { $launchArgs += @('--host', $hostName) }
            if ($DryRun) {
                Write-Ok "[演示模式] 将执行: $launchFile $($launchArgs -join ' ')"
            } else {
                try {
                    Start-DshWebHidden $launchFile $launchArgs
                    Write-Ok "已启动 dsh web（后台隐藏，无窗口），等待端口 $port 就绪（最多 60 秒）..."
                    if (Wait-Port $port 60) {
                        Write-Ok "DSH web 启动成功。"
                    } else {
                        Write-Warn "等待超时：DSH web 未能就绪，请手动运行 dsh web 排查（日志见 launcher.log）。"
                    }
                } catch {
                    Write-Warn "自动启动 dsh web 失败: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Warn "找不到 node / dsh 命令，无法自动启动。请先安装 DSH，或手动运行 dsh web。"
        }
    }
}

# HTTP 探测（端口就绪时才有意义）
if (Test-PortListen $port) {
    try {
        $resp = Invoke-WebRequest -Uri $DSH_URL -UseBasicParsing -TimeoutSec 3
        Write-Ok "HTTP 请求成功，状态码: $($resp.StatusCode)"
    } catch {
        Write-Warn "HTTP 请求暂时无响应（服务可能还在启动中）。"
    }
} else {
    Write-Warn "端口 $port 仍未监听，浏览器打开后可能连接被拒绝。请确认 dsh web 已启动。"
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
