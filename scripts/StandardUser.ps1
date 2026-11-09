<#
Helpers shared by open-unity.ps1 and open-vs.ps1. Dot-source it; it does nothing on its own.

Windows PowerShell 5.1 reads a BOM-less script as ANSI, so every script in this folder stays ASCII.
#>

function Test-Elevated {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
Starts a process with the standard-user token from an elevated shell. A child of an elevated process
inherits Administrator; a scheduled task registered with RunLevel Limited is the launcher that hands
out the standard-user token. The task runs a hidden powershell that Start-Processes the target and
exits, so the task ends at once and the target outlives it. The task is removed before returning.

Returns $true when the task exited 0, or is still running its Start-Process after the wait.
#>
function Start-StandardUserProcess {
    param(
        [Parameter(Mandatory)] [string]$TaskName,
        [Parameter(Mandatory)] [string]$FilePath,
        [Parameter(Mandatory)] [string]$ArgumentList,
        [Parameter(Mandatory)] [string]$Log
    )

    # 0x41303: the task has not run yet.
    $notYetRun = 267011
    # 0x41301: the task is still running.
    $stillRunning = 267009
    $inner = "Start-Process -FilePath '{0}' -ArgumentList '{1}'" -f $FilePath.Replace("'", "''"), $ArgumentList.Replace("'", "''")
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner))

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand $encoded"
    $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    try {
        Register-ScheduledTask -TaskName $TaskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskName $TaskName | Out-Null

        $result = $notYetRun
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep -Seconds 1
            $result = (Get-ScheduledTaskInfo -TaskName $TaskName).LastTaskResult
            if ((Get-ScheduledTask -TaskName $TaskName).State -ne 'Running' -and $result -ne $notYetRun) { break }
        }

        Add-Content -LiteralPath $Log -Value "task $TaskName ran $FilePath, last result $result"
        return ($result -eq 0) -or ($result -eq $stillRunning)
    }
    catch {
        Add-Content -LiteralPath $Log -Value "task $TaskName failed: $_"
        return $false
    }
    finally {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
}
