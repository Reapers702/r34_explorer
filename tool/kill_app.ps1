# 清理占用构建产物的残留进程（Windows 上重新编译前必跑）
#
# 为什么需要：
#   Windows 不允许覆盖正在运行的可执行文件/被其占用的 dll。只要 App 还开着，
#   flutter run / flutter build 就会报：
#     MSB3026: 无法将 WebView2Loader.dll 复制到 ... 文件正由另一进程使用
#     LNK1168: 无法打开 r34_video.exe 进行写入
#
#   更阴的是 WebView2：主进程被杀后，msedgewebview2 子进程经常还赖着不放句柄，
#   于是“明明关了 App 还是编不过”。
#
# 用法：
#   pwsh -File tool\kill_app.ps1          # 只杀本项目相关
#   pwsh -File tool\kill_app.ps1 -Deep    # 连 msedgewebview2 一起杀（会波及
#                                         # 其他用 WebView2 的程序，如 Teams/Outlook）

param(
    [switch]$Deep
)

$ErrorActionPreference = 'SilentlyContinue'

$targets = @('r34_video')
if ($Deep) {
    # 只在 -Deep 时动它：其他程序也可能在用 WebView2 运行时。
    $targets += 'msedgewebview2'
}

$killed = 0
foreach ($name in $targets) {
    Get-Process -Name $name | ForEach-Object {
        Write-Host "  kill $($_.ProcessName) (pid=$($_.Id))"
        $_.Kill()
        $killed++
    }
}

# flutter_tester 是 flutter test 留下的，多的时候也会拖慢机器。
$testers = Get-Process -Name 'flutter_tester'
if ($testers) {
    Write-Host "  另外还有 $($testers.Count) 个 flutter_tester 残留（flutter test 留下的，可留可杀）"
}

Start-Sleep -Milliseconds 800

$dll = Join-Path $PSScriptRoot '..\build\windows\x64\runner\Debug\WebView2Loader.dll'
if (Test-Path $dll) {
    try {
        $stream = [IO.File]::Open($dll, 'Open', 'ReadWrite', 'None')
        $stream.Close()
        Write-Host "构建产物已解锁，可以重新编译。" -ForegroundColor Green
    } catch {
        Write-Host "WebView2Loader.dll 仍被占用，试试：pwsh -File tool\kill_app.ps1 -Deep" -ForegroundColor Yellow
    }
} else {
    Write-Host "构建产物不存在（还没编过或无妨）。" -ForegroundColor Green
}

Write-Host "已结束 $killed 个进程。"
