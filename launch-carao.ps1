# launch-carao.ps1 — เปิด CARAO kiosk ทุกจอ: จอหลัก = ตัวสั่งงาน, จออื่น = จอเอฟเฟกต์ (mirror)
Add-Type -AssemblyName System.Windows.Forms
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$i = 0
foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
    $b = $s.Bounds
    $suffix = if ($i -eq 0) { '' } else { "$i" }          # แยกโพรไฟล์ต่อจอ ไม่งั้น Edge รวมเป็นโปรเซสเดียวแล้วไม่ยอมวางตำแหน่ง
    $url = if ($s.Primary) { 'file:///C:/Users/watch/morning/carao.html' } else { 'file:///C:/Users/watch/morning/carao.html?mirror=1' }
    Start-Process $edge -ArgumentList "--user-data-dir=C:\Users\watch\morning\.edge-carao$suffix", '--no-first-run',
        '--kiosk', $url, '--edge-kiosk-type=fullscreen', "--window-position=$($b.X),$($b.Y)",
        '--autoplay-policy=no-user-gesture-required', '--use-fake-ui-for-media-stream'
    $i++
}
