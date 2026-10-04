# 修复工程目录的「强制完整性级别」标签。
#
# 背景（真实踩过的坑）
# -------------------
# Windows 的规则：**exe 文件带什么完整性标签，进程就以什么完整性运行。**
# 如果工程目录被打上了 `Low Mandatory Level`，那么从它里面编译/启动的一切
# 都会是低完整性进程，而低完整性：
#
#   * 写不了 %TEMP% / %APPDATA%（这两个位置只给 Medium 及以上写权限）
#     -> 表现为 flutter_cache_manager / media_kit / shared_preferences 抛
#        PathAccessException ... (OS Error: 拒绝访问。, errno = 5)
#   * 甚至无法被同会话正常结束（Kill 报"拒绝访问"）
#   * 但写工程目录本身是成功的（工作区 ACL 往往含 Everyone / Authenticated Users）
#
# 最坑的一点：标签**会遗传**。工程根被标了，build\...\Debug 每一层都继承，
# 于是每次重新编译得到的新 exe 自动带上标签 -> 问题反复复现。
#
# 这类标签通常是某个沙箱工具（如 Codex 沙箱）加上的，不是 Flutter 的问题，
# 也绝不是「组件在 Windows 上不能用」。**不要为此去 override 组件**。
#
# 正确修法就是本脚本：把工程目录（递归）的完整性级别设回 Medium。
#
# 用法
# ----
#   pwsh -File tool\fix_integrity.ps1                 # 处理当前工程
#   pwsh -File tool\fix_integrity.ps1 -Path D:\some\dir
#   pwsh -File tool\fix_integrity.ps1 -DryRun         # 只体检，不改动
#
# 需要「写文件权限（写 DACL）」：工程目录属主是你自己时通常无需管理员。

[CmdletBinding()]
param(
    # 要处理的根目录，默认是脚本所在工程的上一级。
    [string]$Path,

    # 只检查并报告，不做任何修改。
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'

if (-not $Path -or $Path.Trim().Length -eq 0) {
    $Path = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "路径不存在: $Path" -ForegroundColor Red
    exit 2
}

$root = (Resolve-Path -LiteralPath $Path).Path

# 取某个路径的完整性级别标签。返回 $null 表示没有标签（即继承默认 Medium）。
function Get-IntegrityLabel {
    param([string]$Target)

    $output = & icacls $Target 2>&1
    $text = ($output | Out-String)

    # 形如：Mandatory Label\Low Mandatory Level:(I)(NW)
    $match = [regex]::Match($text, 'Mandatory Label\\([^:]+):')
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return $null
}

# 探针可执行文件：优先看构建产物，其次看工程根。
function Find-ProbeExe {
    param([string]$Root)

    $candidates = @(
        (Join-Path $Root 'build\windows\x64\runner\Debug\r34_video.exe'),
        (Join-Path $Root 'build\windows\x64\runner\Release\r34_video.exe')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

Write-Host "工程目录: $root"
Write-Host ""

$rootLabel = Get-IntegrityLabel $root
$exePath = Find-ProbeExe $root
$exeLabel = if ($exePath) { Get-IntegrityLabel $exePath } else { $null }

Write-Host "体检结果"
Write-Host "--------"
if ($rootLabel) {
    $rootColor = if ($rootLabel -match 'Low|Untrusted') { 'Red' } else { 'Yellow' }
    Write-Host ("  目录根    : {0}" -f $rootLabel) -ForegroundColor $rootColor
} else {
    Write-Host "  目录根    : (无标签，走默认 Medium)" -ForegroundColor Green
}

if ($exePath) {
    $shortExe = $exePath.Replace($root, '.')
    if ($exeLabel) {
        $exeColor = if ($exeLabel -match 'Low|Untrusted') { 'Red' } else { 'Yellow' }
        Write-Host ("  构建产物  : {0}  <- {1}" -f $exeLabel, $shortExe) -ForegroundColor $exeColor
    } else {
        Write-Host ("  构建产物  : (无标签，走默认 Medium)  <- {0}" -f $shortExe) -ForegroundColor Green
    }
} else {
    Write-Host "  构建产物  : (还没编译过，跳过)" -ForegroundColor DarkGray
}

$isLow = ($rootLabel -and $rootLabel -match 'Low|Untrusted') -or
         ($exeLabel -and $exeLabel -match 'Low|Untrusted')

Write-Host ""
if (-not $isLow) {
    Write-Host "结论：完整性级别正常，无需处理。" -ForegroundColor Green
    Write-Host "（若仍然出现 Access denied，请确认运行 App 的终端不是在某个沙箱会话里。）"
    exit 0
}

Write-Host "结论：检测到低完整性标签 —— 这正是 %TEMP%/%APPDATA% 写入被拒的原因。" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host ""
    Write-Host "-DryRun 指定，未做任何修改。去掉该参数即可修复。" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "开始修复（递归设置完整性级别为 Medium）..."
Write-Host "  注意：个别文件可能因被占用/权限不足而跳过，脚本会统计并给出提示。"

$output = & icacls $root /setintegritylevel Medium /T /C 2>&1
$text = ($output | Out-String)

$okMatch = [regex]::Match($text, 'Successfully processed (\d+) files; Failed processing (\d+) files')
$failedFiles = @()
foreach ($line in $output) {
    $s = "$line"
    if ($s -match 'Access is denied' -or $s -match '拒绝访问') {
        $f = ($s -split ':')[0].Trim()
        if ($f) { $failedFiles += $f }
    }
}

if ($okMatch.Success) {
    Write-Host ("  成功 {0} 个文件，失败 {1} 个。" -f $okMatch.Groups[1].Value, $okMatch.Groups[2].Value)
} else {
    Write-Host "  未能解析 icacls 统计输出，原始输出末尾："
    $output | Select-Object -Last 5 | ForEach-Object { Write-Host "    $_" }
}

if ($failedFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "  以下文件跳过（通常是被运行中的进程占用，或权限不足）：" -ForegroundColor Yellow
    $failedFiles | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" }
    if ($failedFiles.Count -gt 10) {
        Write-Host ("    ...另有 {0} 个" -f ($failedFiles.Count - 10))
    }
    Write-Host "  处理办法：先结束占用进程再重跑本脚本（构建产物被占用时用 tool\kill_app.ps1）。"
}

Write-Host ""
Write-Host "复验"
Write-Host "----"
$rootLabel2 = Get-IntegrityLabel $root
if ($rootLabel2 -match 'Low|Untrusted') {
    Write-Host ("  目录根    : 仍为 {0}  —— 修复未完全生效" -f $rootLabel2) -ForegroundColor Red
} else {
    Write-Host ("  目录根    : {0}" -f ($(if ($rootLabel2) { $rootLabel2 } else { '(无标签/Medium)' }))) -ForegroundColor Green
}

if ($exePath) {
    $exeLabel2 = Get-IntegrityLabel $exePath
    if ($exeLabel2 -match 'Low|Untrusted') {
        Write-Host ("  构建产物  : 仍为 {0}  —— 需要重新编译（建议 flutter clean 后再 build）" -f $exeLabel2) -ForegroundColor Yellow
    } else {
        Write-Host ("  构建产物  : {0}" -f ($(if ($exeLabel2) { $exeLabel2 } else { '(无标签/Medium)' }))) -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "建议接下来：" -ForegroundColor Cyan
Write-Host "  1) flutter clean && flutter build windows --debug   # 让产物继承已修正的目录"
Write-Host "  2) 运行 App，确认不再出现 PathAccessException"
Write-Host ""
Write-Host "说明：这类标签可能被沙箱工具再次打上；复现时重跑本脚本即可，不需要改任何代码。"
exit 0
