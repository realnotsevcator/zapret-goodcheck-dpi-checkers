Set args = WScript.Arguments
If args.count = 0 Then
    wscript.echo "elevate.vbs <executable> <parameters>"
Else
    Set UAC = CreateObject("Shell.Application")
    cmd = args(0)
    param = ""
    
    If args.count >= 2 Then
        param = Chr(34) & args(1) & Chr(34)
        For i = 2 To args.count - 1
            param = param & " " & Chr(34) & args(i) & Chr(34)
        Next
    End If
    
    UAC.ShellExecute cmd, param, "", "runas", 1
End If
