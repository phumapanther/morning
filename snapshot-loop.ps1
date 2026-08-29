# snapshot-loop.ps1 — วน snapshot ทุก 3 นาที (แทน scheduled task ที่ Group Policy บล็อก)
# carao-boot.vbs สตาร์ตตัวนี้ค้างไว้ตอน login; ตายเองตอนปิดเครื่อง (snapshot ล่าสุดถูกเซฟไว้แล้ว)
$ErrorActionPreference = 'SilentlyContinue'
while ($true) {
    & "$PSScriptRoot\snapshot.ps1"
    Start-Sleep -Seconds 180
}
