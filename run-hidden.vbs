' run a powershell script fully hidden (no console flash). arg0 = .ps1 path
CreateObject("WScript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -File """ & WScript.Arguments(0) & """", 0, False
