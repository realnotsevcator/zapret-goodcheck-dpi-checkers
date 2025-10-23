Set args = WScript.Arguments
If args.count = 0 Then
    wscript.echo "elevate.vbs <executable> <parameters>"
Else
    Set UAC = CreateObject("Shell.Application")
    Set fso = CreateObject("Scripting.FileSystemObject")
    cmd = args(0)
    param = ""
    dir = ""
    
    If args.count >= 2 Then
        param = Chr(34) & args(1) & Chr(34)
        For i = 2 To args.count - 1
            param = param & " " & Chr(34) & args(i) & Chr(34)
        Next
    End If
    
    On Error Resume Next
    If fso.FileExists(cmd) Then
        dir = fso.GetParentFolderName(fso.GetAbsolutePathName(cmd))
    ElseIf fso.FolderExists(cmd) Then
        dir = fso.GetAbsolutePathName(cmd)
    End If
    On Error GoTo 0

    UAC.ShellExecute cmd, param, dir, "runas", 1
End If
