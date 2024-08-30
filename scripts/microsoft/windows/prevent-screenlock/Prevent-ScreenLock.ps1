#Requires -version 5.1;

<#
.SYNOPSIS
  Press the scroll lock to prevent the screen from locking.

.DESCRIPTION
  This script toggle the scroll lock keyboard button.

.Parameter NoLimit
  If the button should be pressed forever.

.Parameter WaitInSeconds
  The number of seconds to wait between each press.

.Parameter TimeRange
  Time range when the script should run.
  Using the format HH:MM-HH:MM.

.EXAMPLE
  # Run between 08:00 and 17:00, and wait for 30 seconds between each press.
  .\Move-MouseCursor.ps1 -WaitInSeconds 30 -TimeRange "08:00-17:00"

.EXAMPLE
  # Run forever, and wait for 5 seconds between each press.
  .\Prevent-ScreenLock.ps1 -NoLimit -WaitInSeconds 5

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  30-08-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]
[OutputType([void])]
param
(
  # If the mouse should be moved forever.
  [Parameter(Mandatory = $false)]
  [switch]$NoLimit = $false,

  # The number of seconds to wait between each mouse move.
  [Parameter(Mandatory = $false)]
  [int]$WaitInSeconds = 30,

  # Time range when the script should run.
  [Parameter(Mandatory = $false, HelpMessage = 'Must be in format HH:MM-HH:MM')]
  [ValidatePattern('^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]-(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$')]
  [string]$TimeRange = '08:00-17:00'
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

# Write to log.
Write-Verbose -Message ('Starting processing {0}' -f $MyInvocation.MyCommand.Name);

# If operating system is not Windows.
if (-not ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)))
{
  # Throw exception.
  throw 'This script only works on Windows operating systems';
}

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

# Try to convert to time range.
try
{
  # Split the time range into start and end time.
  [datetime]$startTime = $TimeRange.Split('-')[0];
  [datetime]$endTime = $TimeRange.Split('-')[-1];
}
catch
{
  # Throw exeception.
  throw "Parameter '-TimeRange' must be in format HH:MM-HH:MM";
}

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Create new shell object.
$shellObject = New-Object -ComObject 'Wscript.Shell';

# Boolean for outside of time range.
$isInTimeRange = $true;

# As long we are not in time range.
while ($true -eq $isInTimeRange -or $NoLimit -eq $true)
{
  # Get current time.
  $currentTime = Get-Date;

  # Check if current time is in time range.
  if ($currentTime -lt $startTime -and $currentTime -gt $endTime)
  {
    # Set boolean to true.
    $isInTimeRange = $false;

    # Write to log.
    Write-Verbose -Message 'Time is outside of range, aborting script';

    # Exit script.
    break;
  }
  # Else if no limit.
  elseif ($NoLimit -eq $true)
  {
    # Write to log.
    Write-Verbose -Message 'No time range specified (running script forever)';
  }
  # Else if in time range.
  else
  {
    # Write to log.
    Write-Verbose -Message ("Time is within range '{0}', proceeding" -f $TimeRange);
  }

  # Write to log.
  Write-Verbose -Message ('{0} - Pressing the scroll lock button' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'));

  # Send scroll lock key to prevent screen from locking.
  $shellObject.SendKeys('{SCROLLLOCK 2}');

  # Wait until next time.
  Start-Sleep -Seconds $WaitInSeconds;
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Verbose -Message ('Ending processing {0}' -f $MyInvocation.MyCommand.Name);

############### Finalize - End ###############
#endregion
