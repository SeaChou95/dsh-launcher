' ============================================
'  DSH 自动启动器 - 静默启动（无窗口版）
'  双击本文件即可：自动获取 DSH 地址，
'  优先用夸克浏览器、找不到就用系统默认浏览器打开
'  运行日志自动写入同目录 launcher.log（方便排查）
' ============================================
Option Explicit
Dim shell, fso, scriptDir, psArgs, extra, i
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptDir & "\open-dsh.ps1"" -Log"

' 透传附加参数（例如 -DryRun、-Browser default、-Url http://localhost:3080/）
extra = ""
For i = 0 To WScript.Arguments.Count - 1
    extra = extra & " " & WScript.Arguments(i)
Next
If Len(extra) > 0 Then psArgs = psArgs & extra

' 0 = 隐藏窗口，False = 不等待进程结束
shell.Run "powershell.exe " & psArgs, 0, False
