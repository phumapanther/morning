# morning.ps1 — "อรุณสวัสดิ์" launcher: เช็คโปรแกรมประจำ ตัวไหนยังไม่เปิดก็เปิดให้
# -Quiet = ไม่เล่นเสียง (ใช้ตอนสั่งจากหน้า CARAO ซึ่งพูดเองอยู่แล้ว กันเสียงซ้อน)
param([switch]$Quiet)
$ErrorActionPreference = 'Continue'

# กันยิงซ้ำ (หน้า CARAO + ตัวฟังเสียงอาจได้ยินพร้อมกัน)
$lock = "$PSScriptRoot\morning.lock"
if ((Test-Path $lock) -and (([DateTime]::Now - (Get-Item $lock).LastWriteTime).TotalSeconds -lt 60)) { exit }
Get-Date | Set-Content $lock

$log = @()

# ---- GUI apps: ชื่อโปรเซส -> วิธีเปิด ----
$apps = @(
    @{ Name='Chrome';         Proc='chrome';        Exe='C:\Program Files\Google\Chrome\Application\chrome.exe' }
    @{ Name='Edge';           Proc='msedge';        Exe='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'; Args='--profile-directory="Profile 1"' }
    @{ Name='VS Code';        Proc='Code';          Exe="$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"; Args='"C:\Users\watch\Documents\TCGWorkspace"' }
    @{ Name='GitHub Desktop'; Proc='GitHubDesktop'; Exe="$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe" }
    @{ Name='eM Client';      Proc='MailClient';    Exe='C:\Program Files (x86)\eM Client\MailClient.exe' }
    @{ Name='MS Teams';       Proc='ms-teams';      Exe='shell:AppsFolder\MSTeams_8wekyb3d8bbwe!MSTeams' }
    @{ Name='Notepad';        Proc='Notepad';       Exe='notepad' }
)

foreach ($a in $apps) {
    if (Get-Process -Name $a.Proc -ErrorAction SilentlyContinue) {
        $log += "[เปิดอยู่แล้ว] $($a.Name)"
    } else {
        try {
            if ($a.Args) { Start-Process $a.Exe -ArgumentList $a.Args } else { Start-Process $a.Exe }
            $log += "[เปิดให้แล้ว] $($a.Name)"
        } catch { $log += "[เปิดไม่ได้] $($a.Name): $_" }
    }
}

# ---- TCG WorkSync (API 9051 + Frontend 9050) — ใช้ start_all.bat ของเดิม ----
# ponytail: เช็คแค่พอร์ต ถ้าขาดตัวใดตัวหนึ่งรัน start_all ทั้งชุด (ตัวที่ซ้ำจะ error ในหน้าต่างตัวเองแล้วปล่อยไว้)
$api = Get-NetTCPConnection -LocalPort 9051 -State Listen -ErrorAction SilentlyContinue
$web = Get-NetTCPConnection -LocalPort 9050 -State Listen -ErrorAction SilentlyContinue
if ($api -and $web) {
    $log += "[เปิดอยู่แล้ว] TCG server + web"
} else {
    Start-Process 'C:\Users\watch\Documents\TCGWorkspace\server_scripts\start_all.bat'
    $log += "[เปิดให้แล้ว] TCG server + web (start_all.bat)"
}

# ---- MMORPG Bot Manager (launcher.py เปิด bot.main ต่อเอง) ----
$bot = Get-CimInstance Win32_Process -Filter "Name LIKE 'python%'" -ErrorAction SilentlyContinue |
       Where-Object { $_.CommandLine -match 'launcher\.py' }
if ($bot) {
    $log += "[เปิดอยู่แล้ว] MMORPG Bot Manager"
} else {
    Start-Process "$env:LOCALAPPDATA\Microsoft\WindowsApps\pythonw3.12.exe" `
        -ArgumentList '"C:\Users\watch\OneDrive\PanTher\mmorpg-bot-manager\launcher.py"' `
        -WorkingDirectory 'C:\Users\watch\OneDrive\PanTher\mmorpg-bot-manager'
    $log += "[เปิดให้แล้ว] MMORPG Bot Manager"
}

# ---- สรุปผล ----
$opened = ($log | Where-Object { $_ -like '*เปิดให้แล้ว*' }).Count
$log | ForEach-Object { Write-Host $_ }
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
"[$stamp]`n" + ($log -join "`n") + "`n" | Add-Content "$PSScriptRoot\morning.log" -Encoding utf8

# พูดตอบด้วยเสียงไทยที่สร้างไว้ล่วงหน้า (edge-tts) — พังก็เงียบไป ไม่ใช่เรื่องคอขาดบาดตาย
if (-not $Quiet) {
    try {
        Add-Type -AssemblyName PresentationCore
        $player = New-Object System.Windows.Media.MediaPlayer
        $player.Open([Uri]"$PSScriptRoot\voice_morning.mp3")
        $player.Play()
        Start-Sleep -Milliseconds 3500
    } catch {}
}

# เปิด/ดึงหน้าต่าง Claude Code ขึ้นมาหน้าสุด (Claude ไม่เปิดตอนบูตแล้ว — มาเปิดตรงนี้หลังผ่านประตู CARAO)
try {
    $wt = Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $wt) {
        Start-Process "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe" -ArgumentList '-d', 'C:\Users\watch', 'C:\Users\watch\.local\bin\claude.exe', '--continue'
    } else {
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Win { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); }'
        [Win]::ShowWindow($wt.MainWindowHandle, 9) | Out-Null   # 9 = SW_RESTORE
        [Win]::SetForegroundWindow($wt.MainWindowHandle) | Out-Null
    }
} catch {}
