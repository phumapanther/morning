# ปิดหน้าต่าง CARAO kiosk (เฉพาะ Edge ที่ใช้โพรไฟล์ .edge-carao เท่านั้น ไม่แตะ Edge ปกติ)
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" |
    Where-Object { $_.CommandLine -match 'edge-carao' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
