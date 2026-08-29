# snapshot.ps1 — รันทุก 3 นาที (scheduled task) ทำ 2 อย่าง:
#   1) เก็บโปรแกรมที่เปิดอยู่ลง last-session.json  -> ให้ restore-session.ps1 เปิดคืนตอน login
#   2) เทียบกับรอบก่อน แล้ว log การเปิด/ปิดโปรแกรมลง app-usage.log  -> ไทม์ไลน์การใช้งาน
# ponytail: polling 3 นาที เลยพลาดโปรแกรมที่เปิด-ปิดภายใน 3 นาที. อยากได้เป๊ะทุกครั้ง
#           อัปเกรดเป็น WMI __InstanceCreationEvent watcher (ต้องมีโปรเซสเฝ้าตลอด)
$ErrorActionPreference = 'SilentlyContinue'
$snapFile  = "$PSScriptRoot\last-session.json"
$usageLog  = "$PSScriptRoot\app-usage.log"

# หน้าต่างระบบที่ไม่ใช่ "โปรแกรมที่ผู้ใช้เปิด" — ไม่นับ ไม่ log
$skip = @('TextInputHost','ApplicationFrameHost','SystemSettings','ShellExperienceHost',
          'StartMenuExperienceHost','SearchHost','SearchApp','LockApp','SecurityHealthSystray')

# สถานะปัจจุบัน: โปรแกรมที่มีหน้าต่าง
$cur = Get-Process | Where-Object { $_.MainWindowTitle -and $_.MainWindowHandle -ne 0 -and $_.ProcessName -notin $skip } |
    ForEach-Object {
        $path = $null; try { $path = $_.Path } catch {}   # elevated -> อ่าน Path ไม่ได้ ปล่อยว่าง
        [pscustomobject]@{ Name = $_.ProcessName; Title = $_.MainWindowTitle; Path = $path }
    } | Where-Object { $_.Path } | Sort-Object Name -Unique
if (-not $cur) { return }   # จอล็อก/ไม่มีหน้าต่าง — คงไฟล์เดิม ไม่ log

# เทียบกับรอบก่อนเพื่อ log การเปิด/ปิด (key = ชื่อโปรแกรม)
$old = @()
if (Test-Path $snapFile) {
    try { $old = (Get-Content $snapFile -Raw -Encoding utf8 | ConvertFrom-Json).Apps } catch {}
}
$oldNames = @($old.Name)
$curNames = @($cur.Name)
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$events = @()
foreach ($c in $cur) { if ($c.Name -notin $oldNames) { $events += "[$stamp] [+] เปิด $($c.Name) - $($c.Title)" } }
foreach ($o in $old) { if ($o.Name -notin $curNames) { $events += "[$stamp] [-] ปิด $($o.Name)" } }
if ($events) { $events -join "`n" | Add-Content $usageLog -Encoding utf8 }

# บันทึกสถานะไว้ให้ restore + เป็นฐานเทียบรอบถัดไป
[pscustomobject]@{ At = $stamp; Apps = @($cur) } | ConvertTo-Json -Depth 4 | Set-Content $snapFile -Encoding utf8
