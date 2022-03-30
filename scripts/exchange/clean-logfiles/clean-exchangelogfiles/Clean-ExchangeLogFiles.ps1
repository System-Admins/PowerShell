#requires -version 3;

<#
.SYNOPSIS
  Clean log files on Exchange servers.

.DESCRIPTION
  Find and delete log files on Exchange servers.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  31-01-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Days to store log files.
$Days = 5;

# Log file paths.
$LogFolders = @{
    IISLogPath = "C:\inetpub\logs\LogFiles\";
    ExchangeLoggingPath = "C:\Program Files\Microsoft\Exchange Server\V15\Logging\";
    ETLLoggingPath = "C:\Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\ETLTraces\";
    ETLLoggingPath2 = "C:\Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\Logs\";
};

# Transcript file.
$Transcript = @{
    Folder = "C:\LogFiles\Clean-ExchangeLogFiles";
    Log = ("C:\LogFiles\Clean-ExchangeLogFiles\{0}_Clean-ExchangeLogFiles.log" -f (Get-Date).ToString("yyyyMMdd"));
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
        Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
}

# Clean the logs.
Function Delete-LogFiles
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$TargetFolder
    )

    # Store files properties.
    $Files = $null;

    # Check if folder path exists.
    If (Test-Path $TargetFolder)
    {
        # Write to log.
        Write-Log ("Found folder '{0}'" -f $TargetFolder);

        # Get current date.
        $Now = Get-Date;

        # Get date to delete after.
        $LastWrite = $Now.AddDays(-$Days);

        # Find files in the target folder.
        $Files = Get-ChildItem $TargetFolder -Recurse | Where-Object { $_.Name -like "*.log" -or $_.Name -like "*.blg" -or $_.Name -like "*.etl" } | Where-Object { $_.lastWriteTime -le "$lastwrite" };

        # Foreach file.
        Foreach ($File in $Files)
        {
            # Write to log.
            Write-Log ("Deleting file '{0}'" -f $File.FullName);

            # Remove file.
            #Remove-Item $File.FullName -ErrorAction SilentlyContinue | Out-Null;
        }
    }
    Else
    {
        # Write to log.
        Write-Log ("Cant find folder '{0}'" -f $TargetFolder);
    }

    # Write to log.
    Write-Log ("");

    # Return files properties.
    Return $Files;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Create trascript folder.
New-Item -Path $Transcript.Folder -ItemType Directory -Force;

# Start transcript.
Start-Transcript -Path $Transcript.Log -Force;

# Files deleted.
$Files = @();

# Clean files.
$Files += Delete-LogFiles($LogFolders.IISLogPath);
$Files += Delete-LogFiles($LogFolders.ExchangeLoggingPath);
$Files += Delete-LogFiles($LogFolders.ETLLoggingPath);
$Files += Delete-LogFiles($LogFolders.ETLLoggingPath2);

# Write to log.
Write-Log ("");
Write-Log ("Deleted '{0}' files of size '{1:N2}' MB" -f ($Files.Count), (($Files | Measure-Object Length -Sum).Sum /1MB));

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Stop transcript.
Stop-Transcript;

############### Finalize - End ###############
#endregion