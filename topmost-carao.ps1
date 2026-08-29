# topmost-carao.ps1 — ตรึงหน้าต่าง CARAO kiosk ให้อยู่บนสุดเสมอ จนกว่าหน้าจะปิด
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WinPin {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint flags);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    public static readonly IntPtr TOPMOST = new IntPtr(-1);
}
'@

$deadline = [DateTime]::Now.AddMinutes(15)   # กันลูปค้างถ้าอะไรผิดปกติ
$seen = $false
while ([DateTime]::Now -lt $deadline) {
    $procs = Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -match 'edge-carao' }
    $mirrorIds = @(($procs | Where-Object { $_.CommandLine -match 'edge-carao\d' }).ProcessId)
    $wins = @()
    if ($procs) { $wins = @(Get-Process -Id $procs.ProcessId -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }) }
    if ($wins.Count) {
        $seen = $true
        # 0x0013 = NOMOVE|NOSIZE|NOACTIVATE — ตรึงบนสุดทุกจอโดยไม่แย่งโฟกัสกันเอง
        foreach ($w in $wins) { [WinPin]::SetWindowPos($w.MainWindowHandle, [WinPin]::TOPMOST, 0, 0, 0, 0, 0x0013) | Out-Null }
        # โฟกัสอยู่ที่จอหลัก (ตัวที่มีช่องพิมพ์) เสมอ
        $main = $wins | Where-Object { $mirrorIds -notcontains $_.Id } | Select-Object -First 1
        if (-not $main) { $main = $wins[0] }
        [WinPin]::SetForegroundWindow($main.MainWindowHandle) | Out-Null
    } elseif ($seen) {
        break   # เคยเห็นแล้วหายหมด = ผ่านประตูแล้ว จบงาน
    }
    Start-Sleep -Seconds 1
}
