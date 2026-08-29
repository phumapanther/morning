# listen.ps1 — CARAO voice: ฟังตลอด
#   "อรุณสวัสดิ์"            -> เปิดโปรแกรมประจำ (morning.ps1)
#   "เฮ้ คอร์ด"              -> เข้าโหมดรับคำสั่ง สะสมข้อความเรื่อย ๆ
#   "เอาตามนี้"              -> จบคำสั่ง วางลง Claude Code แล้วกด Enter ให้
# ต้องรันด้วย Windows PowerShell 5.1 (powershell.exe) — pwsh/Python จาก Store โดนบล็อกไมค์
$ErrorActionPreference = 'Stop'

# กันรันซ้อนหลายตัว
$dup = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
       Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match 'listen\.ps1' }
if ($dup) { exit }

$lib = "$PSScriptRoot\lib"
$chunk = "$env:TEMP\morning_chunk.wav"
$morning = "$PSScriptRoot\morning.ps1"
$logFile = "$PSScriptRoot\listener.log"
$cooldownUntil = [DateTime]::MinValue

function Log([string]$m) {
    try { "$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) $m" | Add-Content $logFile -Encoding UTF8 } catch {
        try { "$([DateTime]::Now.ToString('HH:mm:ss')) LOGERR ($m): $_" | Out-File "$PSScriptRoot\listener-err.log" -Append -Encoding UTF8 } catch {}
    }
}

Log '=== listener starting ==='

# ---- init (ลองซ้ำได้ เผื่อบูตมาแล้วอะไรยังไม่พร้อม) ----
while ($true) {
    try {
        . "$lib\WRec.ps1"
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName PresentationCore
        Log 'init ok'
        break
    } catch {
        Log "init FAIL: $_"
        Start-Sleep -Seconds 20
    }
}

# SendKeys ทำ Ctrl หลุดเป็นตัว v เฉย ๆ บ่อย — ใช้ keybd_event กด Ctrl ค้างจริงแทน
if (-not ([System.Management.Automation.PSTypeName]'Kbd').Type) {
    Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
using System.Threading;
public class Kbd {
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, int flags, int extra);
    public static void Paste() {
        keybd_event(0x11, 0, 0, 0); Thread.Sleep(80);   // Ctrl down
        keybd_event(0x56, 0, 0, 0); Thread.Sleep(80);   // V down
        keybd_event(0x56, 0, 2, 0); Thread.Sleep(30);   // V up
        keybd_event(0x11, 0, 2, 0);                     // Ctrl up
    }
    public static void Enter() {
        keybd_event(0x0D, 0, 0, 0); Thread.Sleep(50);
        keybd_event(0x0D, 0, 2, 0);
    }
}
'@
}

$env:PYTHONIOENCODING = 'utf-8'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$script:player = New-Object System.Windows.Media.MediaPlayer
function Play-Voice([string]$name, [int]$ms) {
    try {
        $f = "$PSScriptRoot\$name"
        if (Test-Path $f) {
            $script:player.Open([Uri]$f); $script:player.Play(); Start-Sleep -Milliseconds $ms
        } else { [Console]::Beep(880, 250) }
    } catch {}
}
function Voice-Wake    { Play-Voice 'voice_wake.mp3'   700 }   # "ครับผม" — รอแค่ต้นเสียง แล้วรีบกลับไปฟังต่อ
function Voice-Confirm { Play-Voice 'voice_done.mp3'   2300 }  # "รับทราบ กำลังดำเนินการครับ"
function Voice-Cancel  { Play-Voice 'voice_cancel.mp3' 1300 }  # "ยกเลิกครับ"

$script:rec = $null
function Get-Recognizer {
    # Python ถอดเสียงตัวเดียวรันค้างไว้ — ตายเมื่อไรค่อยเปิดใหม่
    if ($script:rec -and -not $script:rec.HasExited) { return $script:rec }
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:LOCALAPPDATA\Microsoft\WindowsApps\python3.12.exe"
    $psi.Arguments = "`"$PSScriptRoot\recognize_daemon.py`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
    $script:rec = [Diagnostics.Process]::Start($psi)
    Log "recognizer daemon started pid $($script:rec.Id)"
    return $script:rec
}

function Recognize-Chunk {
    # ส่งไฟล์อัดล่าสุดให้ Google daemon ถอดเป็นข้อความ
    try {
        $r = Get-Recognizer
        $r.StandardInput.WriteLine($chunk)
        $t = $r.StandardOutput.ReadLine()
    } catch { Log "recog error: $_"; $t = '' }
    if ($t) { return "$t".Trim() } else { return '' }
}

# ---- ตัวจับคำปลุกในเครื่อง: เทียบกับเสียง "เฮ้ คอด" ของผู้ใช้เอง (อัดด้วย enroll-wake.ps1) ----
$script:wakeD = $null
function Get-WakeDaemon {
    if ($script:wakeD -and -not $script:wakeD.HasExited) { return $script:wakeD }
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:LOCALAPPDATA\Microsoft\WindowsApps\python3.12.exe"
    $psi.Arguments = "`"$PSScriptRoot\wake_check.py`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true
    $script:wakeD = [Diagnostics.Process]::Start($psi)
    Log "wake daemon started pid $($script:wakeD.Id)"
    return $script:wakeD
}

$wakeThresh = 0
if (Test-Path "$PSScriptRoot\wake\threshold.txt") {
    $wakeThresh = [double](Get-Content "$PSScriptRoot\wake\threshold.txt" | Select-Object -First 1)
}

function Get-WakeScore {
    # คะแนนความเหมือนกับแม่แบบ (ต่ำ = เหมือน), $null = เช็คไม่ได้
    if (-not $wakeThresh) { return $null }
    try {
        $d = Get-WakeDaemon
        $d.StandardInput.WriteLine($chunk)
        $s = $d.StandardOutput.ReadLine()
        if ($s) { return [double]$s }
    } catch { Log "wake check error: $_" }
    return $null
}

function Focus-Claude {
    # โฟกัสแท็บที่แอ็กทีฟของ Windows Terminal (เปิด claude ให้ถ้ายังไม่เปิด)
    # ponytail: ถ้าเปิดหลายแท็บ ข้อความไปลงแท็บที่แอ็กทีฟ — ปกติ claude คือแท็บเดียว
    $wt = Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $wt) {
        Log 'no terminal, launching claude'
        Start-Process "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe" -ArgumentList '-d', 'C:\Users\watch', 'C:\Users\watch\.local\bin\claude.exe', '--continue'
        Start-Sleep -Seconds 12   # ponytail: รอแบบกะเวลา ถ้าเครื่องอืดมากอาจพลาด พูดใหม่อีกรอบได้
        $wt = Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if (-not $wt) { Log 'FAIL: no WindowsTerminal window'; return $false }
    }
    $ws = New-Object -ComObject WScript.Shell
    $null = $ws.AppActivate($wt.Id)
    Start-Sleep -Milliseconds 200
    return $true
}

function Send-ToClaude([string]$text) {
    # วางข้อความทั้งก้อนลง Claude Code แล้วกด Enter — วางครั้งเดียว กันคีย์หลุดจากการยิงถี่ ๆ
    if (-not (Focus-Claude)) { return $false }
    Set-Clipboard -Value $text
    Start-Sleep -Milliseconds 400   # รอโฟกัสนิ่งก่อนค่อยวาง
    [Kbd]::Paste()
    Start-Sleep -Milliseconds 300
    [Kbd]::Enter()
    Log "sent to claude: $text"
    return $true
}

# ponytail: Google ถอดเสียงปลุกเพี้ยนหนักตามสำเนียง — จับกว้างทุกเสียงโทน "คอด" ตามที่ผู้ใช้สั่ง
# ปลุกพลาดแค่ "ครับผม" เกินมาแล้วหมดเวลาเอง ไม่อันตราย ถ้าปลุกมั่วบ่อยค่อยตัดคำออก
$wakeRx = 'คอร์[ดสทตซ]|คอ[ดตทสซช]|ค[ดต]|ค้อ[ดต]|โค้?[ดตส]|โค้ท|ครอด|คลอด|กอด|ก[็๊]อ[ดตท]|ขอด|คร[อ้]ส|claude|cloud|code|cord|chord|court|cost|god|got'
$endRx  = 'เอา\s*ตาม\s*นี้|โอเคร?|okay|\bok\b|แค่นี้'

function Invoke-CommandMode {
    # หลังปลุก: อัดท่อนถัดไปพร้อมกับที่ท่อนก่อนกำลังถอดอยู่ (double-buffer)
    # ไมค์ไม่หยุดฟังระหว่างรอ Google — คำไม่หล่น และไม่เสียเวลารอถอดทีละท่อน
    Voice-Wake
    $buf = ''; $silent = 0; $rounds = 0
    $pending = $false; $flip = $false
    $r = Get-Recognizer
    while ($true) {
        $rounds++
        if ($rounds -gt 40) { Voice-Cancel; break }          # เพดาน ~2 นาที กันลืมปิด
        $flip = -not $flip
        $cur = if ($flip) { "$env:TEMP\cmd_a.wav" } else { "$env:TEMP\cmd_b.wav" }
        $peak = [WRec]::Record($cur, 8, 500, 800)

        # เก็บผลของท่อนก่อนหน้า (ถอดเสร็จไปแล้วระหว่างที่เพิ่งอัด)
        if ($pending) {
            $pending = $false
            $t = $r.StandardOutput.ReadLine()
            if ($t) { $t = $t.Trim() }
            if ($t) {
                $silent = 0
                if ($t -imatch $endRx) {
                    $buf = ($buf + ' ' + ($t -replace "($endRx)[\s\S]*$", '')).Trim()
                    if ($buf) { if (Send-ToClaude $buf) { Voice-Confirm } else { Voice-Cancel } }
                    else { Voice-Cancel }
                    break
                }
                $buf = ($buf + ' ' + $t).Trim()
            }
        }

        if ($peak -ge 800) {
            $r.StandardInput.WriteLine($cur)
            $pending = $true
        } else {
            $silent++
            if ($silent -ge 6) { Log 'command timeout'; Voice-Cancel; break }
        }
    }
}

$null = Get-Recognizer   # อุ่นเครื่อง daemon ตั้งแต่ต้น จะได้ไม่หน่วงตอนพูดครั้งแรก
if ($wakeThresh) { $null = Get-WakeDaemon; Log "local wake armed, threshold $wakeThresh" }
Log 'listening...'
# ponytail: อัดเป็นช่วง ๆ — พูดคร่อมรอยต่ออาจตกหล่น พูดซ้ำได้
while ($true) {
    try {
        $peak = [WRec]::Record($chunk, 4, 500, 800)
        if ($peak -lt 800) { continue }

        # เช็คคำปลุกในเครื่องก่อน — เร็วกว่าและตรงสำเนียงผู้ใช้ ไม่ต้องรอเน็ต
        $score = Get-WakeScore
        if ($null -ne $score -and $score -le $wakeThresh) {
            Log "wake(local): score $score"
            Invoke-CommandMode
            continue
        }

        # ไม่ใช่คำปลุกแบบเป๊ะ — ให้ Google ถอดเผื่อเป็น อรุณสวัสดิ์ หรือคำปลุกที่เพี้ยน
        $text = Recognize-Chunk
        if (-not $text) { continue }
        Log "heard: $text (wake score $score)"

        if ($text -match 'อรุณสวัส|อรุณสวัสดี') {
            if ([DateTime]::Now -lt $cooldownUntil) { continue }
            $cooldownUntil = [DateTime]::Now.AddSeconds(60)
            Log "trigger morning: $text"
            Start-Process pwsh -ArgumentList '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $morning -WindowStyle Hidden
            continue
        }

        if ($text -imatch $wakeRx) {
            Log "wake: $text"
            Invoke-CommandMode
            continue
        }
    } catch {
        Log "loop error: $_"
        Start-Sleep -Seconds 30    # ไมค์หลุด/อุปกรณ์เปลี่ยน รอแล้วลองใหม่
    }
}
