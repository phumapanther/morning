# restore-session.ps1 — เปิดโปรแกรมที่ค้างไว้ก่อนปิดเครื่องรอบก่อนขึ้นมาอัตโนมัติ (รันตอน login)
# อ่านจาก last-session.json ที่ snapshot.ps1 เก็บไว้ เปิดเฉพาะตัวที่ยังไม่ได้เปิด
$ErrorActionPreference = 'SilentlyContinue'
$snapFile = "$PSScriptRoot\last-session.json"
if (-not (Test-Path $snapFile)) { return }

# ไม่เปิดคืน: เชลล์/เทอมินัล/เซิร์ฟเวอร์/ตัว CARAO เอง (เทอมินัล+claude ตั้งใจให้เปิดหลังผ่านประตู CARAO)
$ignore = @('explorer','WindowsTerminal','StartMenuExperienceHost','ShellExperienceHost',
            'ApplicationFrameHost','SystemSettings','TextInputHost','SearchHost','SearchApp',
            'LockApp','SecurityHealthSystray','claude','cmd','conhost','powershell','pwsh',
            'node','python','pythonw','wt','OpenConsole')

$snap = Get-Content $snapFile -Raw -Encoding utf8 | ConvertFrom-Json
$log = @("[restore] จาก snapshot $($snap.At)")
foreach ($s in $snap.Apps) {
    # ponytail: เปิดคืนด้วย exe path เท่านั้น (ไม่มี argument) — ข้าม python/สคริปต์โฮสต์ที่ต้องมี arg ถึงจะทำงาน
    if ($s.Name -in $ignore -or $s.Name -match '^python') { continue }
    if (Get-Process -Name $s.Name -ErrorAction SilentlyContinue) { $log += "[เปิดอยู่แล้ว] $($s.Name)"; continue }
    if ($s.Path -and (Test-Path $s.Path)) {
        try { Start-Process $s.Path; $log += "[เปิดคืนให้แล้ว] $($s.Name)" }
        catch { $log += "[เปิดคืนไม่ได้] $($s.Name): $_" }
    }
}
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
"[$stamp]`n" + ($log -join "`n") + "`n" | Add-Content "$PSScriptRoot\morning.log" -Encoding utf8
