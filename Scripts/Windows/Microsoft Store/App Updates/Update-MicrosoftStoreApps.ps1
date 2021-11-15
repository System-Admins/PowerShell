#requires -version 3

<#
.SYNOPSIS
  Forces an Microsoft Store app update when a user logon.

.DESCRIPTION
  Creates an task schedule that runs a PowerShell script through a VBS script (to hide the terminal).
  Needs to run in administrator context such as SYSTEM.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  15-11-2021
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Organization name.
$OrganizationName = "System Admins";

# Folders.
$Folders = @{
    Script = ("{0}\{1}\Scripts\UpdateMicrosoftStoreApps" -f $env:ProgramFiles, $OrganizationName);
    Log = ("{0}\{1}\Logs\UpdateMicrosoftStoreApps" -f $env:ProgramFiles, $OrganizationName);
};

# Files.
$Files = @{
    VBS = ("{0}\Update-MicrosoftStoreApps.vbs" -f $Folders.Script);
    PS1 = ("{0}\Update-MicrosoftStoreApps.ps1" -f $Folders.Script);
    Log = ("{0}\{1}-Update-MicrosoftStoreApps.log" -f $Folders.Log, (Get-Date).ToString("yyyyMMdd"));
};

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Write to the console.
Function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Text
    )
 
    # If the input is empty.
    If([string]::IsNullOrEmpty($Text))
    {
        $Text = " ";
    }
    Else
    {
        # Write to the console.
        Write-Output("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
}
# Create schedule task.
Function New-ScriptTaskSchedule
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$FolderPath,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Description,
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Argument
    )

    # Create a new object.
    $ScheduleService = New-Object -ComObject 'Schedule.Service';

    # Connect to schedule service.
    $ScheduleService.Connect();

    # Create a new task.
    $Task = $ScheduleService.NewTask(0);

    # Set description.
    $Task.RegistrationInfo.Description = $Description;

    # Enable the task.
    $Task.Settings.Enabled = $true;

    # Allow to run the schedule on demand.
    $Task.Settings.AllowDemandStart = $true

    # Create the trigger.
    $Trigger = $task.triggers.Create(9);

    # Enable the trigger.
    $Trigger.Enabled = $true;

    # Create action.
    $Action = $Task.Actions.Create(0);

    # Set action.
    $Action.Path = $Path;
    $Action.Arguments = ('"{0}"' -f $Argument)

    # Check if folder path already exist.
    Try
    {
        $null = $ScheduleService.GetFolder($FolderPath);
    }
    # The folder path doesnt exist.
    Catch
    {
        # Get root folder.
        $RootFolder = $ScheduleService.GetFolder("\");

        # Create folder.
        $null = $RootFolder.CreateFolder($FolderPath);
    }


    # Get folder path.
    $TaskFolder = $ScheduleService.GetFolder($FolderPath);

    # Create schedule task.
    $TaskFolder.RegisterTaskDefinition($Name, $Task , 6, 'Users', $null, 4);
}

# Create VBS file with content.
Function New-VbsScript
{

    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$PowerShellScriptPath,
        [Parameter(Mandatory=$true)][string]$OutputPath
    )

    $Content = @"
Dim objShell,objFSO,objFile

Set objShell=CreateObject("WScript.Shell")
Set objFSO=CreateObject("Scripting.FileSystemObject")

'enter the path for your PowerShell Script
strPath="$($PowerShellScriptPath)"

'verify file exists
If objFSO.FileExists(strPath) Then
'return short path name
    set objFile=objFSO.GetFile(strPath)
    strCMD="powershell -nologo -command " & Chr(34) & "&{" &_
     objFile.ShortPath & "}" & Chr(34)
    'Uncomment next line for debugging
    'WScript.Echo strCMD
   
    'use 0 to hide window
    objShell.Run strCMD,0

Else

'Display error message
    WScript.Echo "Failed to find " & strPath
    WScript.Quit
   
End If
"@;

    # Export to file.
    $Content | Out-File -FilePath $OutputPath -Encoding utf8 -Force;
}

# Create PowerShell file with content.
Function New-Ps1Script
{

    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$OutputPath
    )

    $Content = @"
Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName "UpdateScanMethod";
"@;

    # Export to file.
    $Content | Out-File -FilePath $OutputPath -Encoding utf8 -Force;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Create new directories.
New-Item -Path $Folders.Script -ItemType Directory -Force;
New-Item -Path $Folders.Log -ItemType Directory -Force;

# Start transcript.
Start-Transcript -Path $Files.Log -Force -Append -Confirm:$false;

# Write to log.
Write-Log ("Creating new file:");
Write-Log ($Files.PS1);
Write-Log ($Files.VBS);

# Create script files.
New-VbsScript -PowerShellScriptPath $Files.PS1 -OutputPath $Files.VBS;
New-Ps1Script -OutputPath $Files.PS1;

# Write to log.
Write-Log ("Creating new schedule task called 'UpdateMicrosoftStoreApps'");

# Create new task schedule.
New-ScriptTaskSchedule -FolderPath "\$OrganizationName" -Name "UpdateMicrosoftStoreApps" -Description 'Forces update Microsoft Store apps' -Path 'C:\Windows\System32\wscript.exe' -Argument $Files.VBS;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Stop transcript.
Stop-Transcript;

############### Finalize - End ###############
#endregion
