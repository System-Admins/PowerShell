#requires -version 3;

<#
.SYNOPSIS
  Add TCP test monitors.

.DESCRIPTION
  Adds monitors for TCP port testing. Add the folder to "C:\Program Files (x86)\Site24x7\WinAgent\monitoring\Plugins" (dont rename the files).
  Remember to change the monitor threshold to listen to "Down".

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  03-03-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
param
(
    [Parameter(Mandatory=$false)][string]$Destination = "dr.dk",
    [Parameter(Mandatory=$false)][string]$Port = "443"
)

# Test name.
$TestName = ("{0}-{1}" -f $Destination, $Port)

# Name in Site24x7.
$PluginName = "{0}_{1}" -f $env:COMPUTERNAME, $TestName;

# Plugin version (increase with 1 for each edit).
$PluginVersion = 1;

# Heartbeat required.
$PluginHeartbeat = "true";

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# TCP test.
Function New-TCPTest
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Destination,
        [Parameter(Mandatory=$true)]$Port
    )

    # Test connection.
    $Test = Test-NetConnection -ComputerName $Destination -Port $Port -ErrorAction SilentlyContinue -WarningAction SilentlyContinue;

    # Return test.
    Return $Test.TcpTestSucceeded;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get test result.
$TestResult = New-TCPTest -Destination $Destination -Port $Port;

# Construct message.
If($TestResult)
{
    # Create message.
    $Message = "TCP connection valid from {0} to {1} on port TCP/{2}" -f $env:COMPUTERNAME, $Destination, $Port;

    # Set status.
    $Status = 1;

    # Threshold.
    $Threshold = "Up"
}
Else
{
    # Create message.
    $Message = "TCP connection is NOT valid from {0} to {1} on port TCP/{2}" -f $env:COMPUTERNAME, $Destination, $Port;

    # Set status.
    $Status = 0;

    # Threshold.
    $Threshold = "Down"
}

# JSON to return.
$JSON = @{
    "plugin_version" = $PluginVersion;
    "heartbeat_required" = $PluginHeartbeat;
    "displayname" = $PluginName;
    "status" = $Status;
    "data" = @{
        ($TestName) = $Threshold;
    };
    "msg" = $Message;
} | ConvertTo-Json;

# Return JSON.
return $JSON;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
