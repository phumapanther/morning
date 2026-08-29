# WRec.ps1 — โหลด NAudio + คลาสอัดเสียง (หยุดเองเมื่อเงียบ) ใช้ร่วมกันระหว่าง listen.ps1 / enroll-wake.ps1
$lib = $PSScriptRoot
Add-Type -Path "$lib\NAudio.Core.dll"
Add-Type -Path "$lib\NAudio.Wasapi.dll"
if (-not ([System.Management.Automation.PSTypeName]'WRec').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Threading;
using NAudio.Wave;
using NAudio.CoreAudioApi;
public class WRec {
    // อัดจนกว่าจะเงียบต่อเนื่อง silenceMs หลังจากมีเสียงดังเกิน thresh (หรือครบ maxSeconds)
    // เงียบตั้งแต่ต้นก็รอแค่ ~1 วิแล้วเลิก — ไม่เสียเวลาอัดอากาศเปล่า
    public static int Record(string path, int maxSeconds, int silenceMs, int thresh) {
        int peak = 0;
        long lastLoud = 0; bool any = false; long start = DateTime.UtcNow.Ticks;
        using (var cap = new WasapiCapture()) {
            var fmt = cap.WaveFormat;
            int ch = fmt.Channels;
            var outFmt = new WaveFormat(fmt.SampleRate, 16, 1);
            using (var w = new WaveFileWriter(path, outFmt)) {
                cap.DataAvailable += (s, e) => {
                    if (fmt.Encoding == WaveFormatEncoding.IeeeFloat) {
                        for (int i = 0; i + 4 * ch <= e.BytesRecorded; i += 4 * ch) {
                            float sum = 0;
                            for (int c = 0; c < ch; c++) sum += BitConverter.ToSingle(e.Buffer, i + 4 * c);
                            int v = (int)(sum / ch * 32767f);
                            if (v > 32767) v = 32767; if (v < -32768) v = -32768;
                            w.WriteByte((byte)(v & 0xFF)); w.WriteByte((byte)((v >> 8) & 0xFF));
                            int a = Math.Abs(v); if (a > peak) peak = a;
                            if (a > thresh) { any = true; lastLoud = DateTime.UtcNow.Ticks; }
                        }
                    } else {
                        for (int i = 0; i + 2 * ch <= e.BytesRecorded; i += 2 * ch) {
                            int sum = 0;
                            for (int c = 0; c < ch; c++) sum += BitConverter.ToInt16(e.Buffer, i + 2 * c);
                            int v = sum / ch;
                            w.WriteByte((byte)(v & 0xFF)); w.WriteByte((byte)((v >> 8) & 0xFF));
                            int a = Math.Abs(v); if (a > peak) peak = a;
                            if (a > thresh) { any = true; lastLoud = DateTime.UtcNow.Ticks; }
                        }
                    }
                };
                cap.StartRecording();
                while (true) {
                    Thread.Sleep(60);
                    double sec = (DateTime.UtcNow.Ticks - start) / 1e7;
                    if (sec >= maxSeconds) break;
                    if (any) {
                        if ((DateTime.UtcNow.Ticks - lastLoud) / 10000 >= silenceMs) break;
                    } else if (sec >= 0.6) break;
                }
                cap.StopRecording();
                Thread.Sleep(100);
            }
        }
        return peak;
    }
}
'@ -ReferencedAssemblies "$lib\NAudio.Core.dll", "$lib\NAudio.Wasapi.dll", 'netstandard', 'System.Threading.Thread'
}
