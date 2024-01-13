# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

<#
.SYNOPSIS
  Get database usage report for all mailbox databases in the organization.

.DESCRIPTION
  Get database information and file sizes for all databases.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  13-01-2023
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Import script.
. ('{0}bin\RemoteExchange.ps1' -f $env:ExchangeInstallPath) | Out-Null;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Output path for CSV.
$reportFilePath = ('{0}\DatabaseUsageReport.csv' -f [Environment]::GetFolderPath('Desktop'));

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Write to log.
Function Write-Log
{
  [cmdletbinding()]	
		
  Param
  (
    [Parameter(Mandatory = $false)][string]$Text
  )
  
  # If text is not present.
  If ([string]::IsNullOrEmpty($Text))
  {
    # Write to the console.
    Write-Output('');
  }
  Else
  {
    # Write to the console.
    Write-Output('[{0}]: {1}' -f (Get-Date).ToString('dd/MM-yyyy HH:mm:ss'), $Text);
  }
}

# Get the number of files and total size of a directory faster than Get-ChildItem.
function Get-ChildItemInfo
{
  [cmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$Path,
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)][string]$Filter
  )

  # Get statistics for a directory.
  function Get-Statistics
  {
    [cmdletBinding()]
    param
    (
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)]$Path,
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)]$Statistics,
      [Parameter(Mandatory = $false, ValueFromPipeline = $true)][string]$Filter
    )

    # Add the statistics for the current directory.
    foreach ($file in $Path.GetFiles())
    {
      # If a filter is specified and the file does not match the filter, skip it.
      if (!([string]::IsNullOrEmpty($Filter)) -and $file -notlike $Filter)
      {
        # Skip the file.
        continue; 
      }

      $Statistics.Count++;
      $Statistics.Size += $file.Length;
    }

    # Foreach directory under the path.
    foreach ($directory in $Path.GetDirectories())
    {
      # Recursively get the statistics for the subdirectory.
      Get-Statistics -Path $directory -Statistics $Statistics;
    }
  }

  # Create a statistics object.
  $statistics = [PSCustomObject]@{
    Count = 0;
    Size  = [long]0
  };

  # Get the statistics for the directory.
  Get-Statistics -Path (New-Object IO.DirectoryInfo $Path) -Statistics $statistics -Filter $Filter;

  # Return the statistics.
  return $statistics;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log ('Connecting to Exchange');

# Connect to Exchange server.
Connect-ExchangeServer -auto -ClientApplication:ManagementShell -AllowClobber:$true | Out-Null;

# Write to log.
Write-Log ('Getting all database information, this might take a few seconds');

# Get all mailbox databases.
$mailboxDatabases = Get-MailboxDatabase -Status -DumpsterStatistics -IncludeCorrupted;

# Write to log.
Write-Log ("Preparing report file '{0}'" -f $reportFilePath);

# Delete CSV file.
Remove-Item -Path $reportFilePath -Force -ErrorAction SilentlyContinue | Out-Null;

# Object array to store results.
$results = @();

# Foreach mailbox database.
foreach ($mailboxDatabase in $mailboxDatabases)
{
  # Write to log.
  Write-Log ('[{0}] Getting all logs files for database, this might take a few seconds' -f $mailboxDatabase.Name);
    
  # Get all log files.
  $logFiles = Get-ChildItemInfo -Path $mailboxDatabase.LogFolderPath.PathName -Filter '*.log';

  # Get combined size of log files.
  $logFilesSizeInBytes = ($logFiles).Size;

  # Get size in Gigabytes.
  $logFilesSizeInGb = [math]::Round($logFilesSizeInBytes / 1024 / 1024 / 1024);

  # Get number of mailboxes in database.
  $mailboxes = Get-Mailbox -Database $mailboxDatabase.Name -ResultSize Unlimited;

  # Create object.
  $result = [PSCustomObject]@{
    Name                    = $mailboxDatabase.Name;
    PrimaryServer           = $mailboxDatabase.MountedOnServer;
    DatabaseSize            = $mailboxDatabase.DatabaseSize;
    DatabaseFile            = $mailboxDatabase.EdbFilePath;
    DatabaseLogFilePath     = $mailboxDatabase.LogFolderPath;
    DatabaseLogFileCount    = $logFiles.Count;
    DatabaseLogFileSizeInGb = $logFilesSizeInGb;
    MailboxesInDatabase     = $mailboxes.count;        
  };

  # Export to CSV.
  $result | Export-Csv -Path $reportFilePath -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Confirm:$false -Force -Append;

  # Add to object array.
  $results += $result;
}

# Write to log.
Write-Log ("Report is available at '{0}'" -f $reportFilePath);

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
