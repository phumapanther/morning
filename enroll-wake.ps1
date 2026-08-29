# enroll-wake.ps1 — อัดเสียง "เฮ้ คอด" ของผู้ใช้ 3 ครั้งเป็นแม่แบบ แล้วคำนวณ threshold
# รันด้วย powershell.exe (PS 5.1) เท่านั้น — ไมค์
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\WRec.ps1"
$wdir = "$PSScriptRoot\wake"
$null = New-Item -ItemType Directory -Force $wdir
$py = "$env:LOCALAPPDATA\Microsoft\WindowsApps\python3.12.exe"

$i = 1
while ($i -le 3) {
    Write-Host "ครั้งที่ $i/3 — พูด 'เฮ้ คอด' หลังเสียงบี๊บ" -ForegroundColor Cyan
    Start-Sleep -Milliseconds 500
    [Console]::Beep(1200, 250)
    $peak = [WRec]::Record("$wdir\wake$i.wav", 3, 600, 800)
    if ($peak -lt 800) { Write-Host "  เงียบไป (peak $peak) อัดใหม่" -ForegroundColor Yellow; continue }
    Write-Host "  ok (peak $peak)" -ForegroundColor Green
    $i++
}
$thr = & $py "$PSScriptRoot\wake_check.py" --calib
if ($LASTEXITCODE -ne 0) { Write-Host "calib FAIL: $thr" -ForegroundColor Red; exit 1 }
Set-Content "$wdir\threshold.txt" $thr
Write-Host "เสร็จ — threshold: $thr (แก้ได้ที่ wake\threshold.txt)" -ForegroundColor Green
