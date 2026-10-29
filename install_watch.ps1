# 把 build/Mountain.prg 复制到用 USB 连着的佳明手表（MTP 设备）的 GARMIN\Apps 里。
# 用法（手表插上电脑后）：
#   pwsh -File install_watch.ps1                 安装正式版
#   pwsh -File install_watch.ps1 -Diag           安装诊断版（build/diag/Mountain.prg），并打开手表上的日志文件
#   pwsh -File install_watch.ps1 -Pull           把手表上的日志取回到 build/diag/MOUNTAIN.TXT
param([string]$Prg = '', [switch]$Diag, [switch]$Pull)

$ErrorActionPreference = 'Stop'
if (-not $Prg) { $Prg = Join-Path $PSScriptRoot ($(if ($Diag) { 'build\diag\Mountain.prg' } else { 'build\Mountain.prg' })) }
$name = Split-Path $Prg -Leaf
$log = 'MOUNTAIN.TXT'   # println 输出写进 GARMIN\Apps\LOGS 里与 PRG 同名的 .TXT（文件存在时才写）
$shell = New-Object -ComObject Shell.Application
$watch = $shell.NameSpace(17).Items() | Where-Object { $_.Name -match 'EPIX|Garmin|fenix|Forerunner|venu|epix' } | Select-Object -First 1
if (-not $watch) { Write-Error '没找到手表：请用数据线连上电脑，并确认手表没有处在充电专用模式。'; exit 1 }

function Child($folder, $childName) { $folder.GetFolder.Items() | Where-Object { $_.Name -ieq $childName } | Select-Object -First 1 }

# MTP 复制是异步的：等目标文件出现且大小对上
function Copy-Wait($destFolder, $file) {
    $leaf = Split-Path $file -Leaf
    $size = (Get-Item $file).Length
    $destFolder.GetFolder.CopyHere($file, 16)   # 16 = 有同名文件时直接替换
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        $f = Child $destFolder $leaf
        if ($f -and $f.ExtendedProperty('System.Size') -eq $size) { return $true }
    }
    return $false
}

$storage = $watch.GetFolder.Items() | Select-Object -First 1          # 内部存储
$garmin = Child $storage 'GARMIN'
if (-not $garmin) { Write-Error "手表 $($watch.Name) 上没找到 GARMIN 文件夹"; exit 1 }
$apps = Child $garmin 'Apps'
if (-not $apps) { Write-Error "手表 $($watch.Name) 上没找到 GARMIN\Apps 文件夹"; exit 1 }
$logs = Child $apps 'LOGS'

if ($Pull) {
    $f = if ($logs) { Child $logs $log } else { $null }
    if (-not $f) { Write-Error "手表上没有 LOGS\$log：先用 -Diag 安装诊断版"; exit 1 }
    $outDir = Join-Path $PSScriptRoot 'build\diag'
    New-Item -ItemType Directory -Force $outDir | Out-Null
    Remove-Item (Join-Path $outDir $f.Name) -ErrorAction SilentlyContinue
    $shell.NameSpace($outDir).CopyHere($f, 16)
    for ($i = 0; $i -lt 60 -and -not (Test-Path (Join-Path $outDir $f.Name)); $i++) { Start-Sleep -Milliseconds 500 }
    Write-Host "日志已取回：$(Join-Path $outDir $f.Name)（$($f.ExtendedProperty('System.Size')) 字节）"
    exit 0
}

if ($Diag) {
    if (-not $logs) { Write-Error '手表上没有 GARMIN\Apps\LOGS 文件夹'; exit 1 }
    if (-not (Child $logs $log)) {
        $tmp = Join-Path $PSScriptRoot "build\diag\$log"
        Set-Content -Path $tmp -Value 'mountain log'
        $ok = Copy-Wait $logs $tmp
        Remove-Item $tmp
        if (-not $ok) { Write-Error '日志文件没能建到手表上'; exit 1 }
        Write-Host "已在手表上建好 LOGS\$log"
    }
}

$existing = Child $apps $name
if ($existing) {
    # MTP 不能直接覆盖同名文件：先把手表上的旧文件移回电脑的 build\replaced\ 留底，再复制新的
    $backup = Join-Path $PSScriptRoot "build\replaced\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Force $backup | Out-Null
    $shell.NameSpace($backup).MoveHere($existing, 16)
    for ($i = 0; $i -lt 60 -and (Child $apps $name); $i++) { Start-Sleep -Milliseconds 500 }
    if (Child $apps $name) { Write-Error "没能把手表上的旧 $name 移走"; exit 1 }
    Write-Host "旧的 $name 已移到 $backup"
}
if (Copy-Wait $apps $Prg) { Write-Host "已安装到 $($watch.Name)\GARMIN\Apps\$name（$((Get-Item $Prg).Length) 字节）"; exit 0 }
Write-Error '复制超时：请在手表的 GARMIN\Apps 里确认文件是否已到位'
exit 1
