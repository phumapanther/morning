' carao-boot.vbs - single boot entry: CARAO kiosk first, everything else silent in background
' (VBS Run with style 0 = truly hidden, no console flash)
Set sh = CreateObject("WScript.Shell")

' 1) CARAO gate - first: one fullscreen kiosk per monitor (main = command, others = mirror)
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\watch\morning\launch-carao.ps1", 0, False

' 2) keep CARAO on top of everything until it closes
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\watch\morning\topmost-carao.ps1", 0, False

' 3) bridge server (page -> run programs)
sh.Run """C:\Program Files\nodejs\node.exe"" C:\Users\watch\morning\carao-server.js", 0, False

' 4) voice listener (hidden)
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\watch\morning\listen.ps1", 0, False

' 5) restore last session's apps - WAIT (must read last-session.json before the loop overwrites it)
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\watch\morning\restore-session.ps1", 0, True

' 6) keep snapshotting open apps every 3 min (tomorrow's restore + app-usage.log)
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\watch\morning\snapshot-loop.ps1", 0, False
