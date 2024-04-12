#Requires -version 5.1;

<#
.SYNOPSIS
  Move the cursor to prevent the screen from locking.

.DESCRIPTION
  This script moves the cursor to prevent the screen from locking.

.Parameter NoLimit
  If the mouse should be moved forever.

.Parameter WaitInSeconds
  The number of seconds to wait between each mouse move.

.Parameter TimeRange
  Time range when the script should run.
  Using the format HH:MM-HH:MM.

.EXAMPLE
  # Run between 08:00 and 17:00, and wait for 30 seconds between each move.
  .\Move-MouseCursor.ps1 -WaitInSeconds 30 -TimeRange "08:00-17:00"

.EXAMPLE
  # Run forever, and wait for 5 seconds between each move.
  .\Move-MouseCursor.ps1 -NoLimit -WaitInSeconds 5

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  12-04-2024
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

# Add assembly for Windows Forms.
Add-Type -AssemblyName System.Windows.Forms;

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

  # Get current cursor position.
  $cursorPosition = [System.Windows.Forms.Cursor]::Position;

  # Get new X and Y position.
  $x = ($cursorPosition.X % 500) + 1;
  $y = ($cursorPosition.Y % 500) + 1;

  # Write to log.
  Write-Verbose -Message ('Moving the cursor position {0} (horizontal), {1} (vertical), and waiting {2} seconds until next' -f $x, $y, $WaitInSeconds);

  # Set new cursor position.
  [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y);

  # Wait until next time.
  Start-Sleep -Seconds $WaitInSeconds;
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
