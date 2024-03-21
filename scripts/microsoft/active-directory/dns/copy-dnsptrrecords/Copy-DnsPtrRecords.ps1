#Requires -Version 5.1;
#Requires -Module DnsServer;

<#
.SYNOPSIS
  Copy PTR records from one zone to another in Windows DNS server.

.DESCRIPTION
    This script will copy PTR records from one reverse zone to another reverse zone in Windows DNS server.
    Should be ran on the Domain Controller (DNS server) or a machine with the DnsServer module.

.Parameter SourceZones
    Source reverse zones to copy from.

.Parameter TargetZoneName
    Destination reverse zone to copy to.

.EXAMPLE
    # Copy specific reverse zones to another reverse zone.
    .\Copy-DnsPtrRecords.ps1 -SourceZones @('10.45.10.in-addr.arpa', '20.50.10.in-addr.arpa') -TargetZoneName '10.in-addr.arpa';

.EXAMPLE
    # Use wildcard to copy to another reverse zone.
    .\Copy-DnsPtrRecords.ps1 -SourceZones '*.10.in-addr.arpa' -TargetZoneName '10.in-addr.arpa';
    
.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  21-03-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

param
(
    # Source reverse zones to copy from.
    [Parameter(Mandatory = $true)]
    [string[]]$SourceZones,

    # Destination reverse zone to copy to.
    [Parameter(Mandatory = $true)]
    [string]$TargetZoneName
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

# Stop any transcript.
$null = Stop-Transcript -ErrorAction SilentlyContinue;

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

# Record types to exclude.
$excludeRecordTypes = @('NS', 'SOA');

# Transcript log file path.
$transcriptLogFilePath = ('{0}\{1}_dnsptrcopy.log' -f $env:TEMP, (Get-Date).ToString('yyyyMMdd-HHmmss'));

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

function Write-Log
{
    <#
    .SYNOPSIS
        Writes a message to a log file and optionally to the console.
    .DESCRIPTION
        Write error, warning, information or debug messages to a log file with some additional parameters.
    .PARAMETER Message
        Message to write to the log.
    .PARAMETER Path
        (Optional) Path to log file.
    .PARAMETER Level
        (Optional) Log level such as debug, information, error etc.
    .PARAMETER NoDateTime
        (Optional) If date and time should not be added to the log message.
    .PARAMETER NoAppend
        (Optional) If the log message should not be appended to the log file.
    .PARAMETER NoLogLevel
        (Optional) If the log level should not be logged.
    .PARAMETER NoConsole
        (Optional) If the log message should not be output to the console.
    .EXAMPLE
        # Write a information message to the console.
        Write-Log -Message 'This is an information message'
    .EXAMPLE
        # Write a debug message to a log file and console.
        Write-Log -Message 'This is an debug message' -Path 'C:\Temp\log.txt' -Level Debug
    .EXAMPLE
        # Write a error message to a log file but not to the console.
        Write-Log -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level Error -NoConsole
    .EXAMPLE
        # Write a information message to a log file but not to the console and do not append to the log file.
        Write-Log -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level 'Information' -NoConsole -NoAppend
    #>
    [cmdletbinding()]
    param
    (
    
        # Message to write to log.
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        # If category should be included.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Category,

        # If subcategory should be included.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Subcategory,
    
        # (Optional) Path to log file.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Path,
        
        # (Optional) Log level.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Error', 'Warning', 'Information', 'Debug')]
        [string]$Level = 'Information',
        
        # (Optional) If date and time should not be added to the log message.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoDateTime,

        # (Optional) If the log message should not be appended to the log file.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoAppend,

        # (Optional) If the log level should not be logged.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoLogLevel,

        # (Optional) If the log message should not be output to the console.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoConsole,

        # (Optional) If the log message should not be added to a file.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoLogFile
    )
    
    BEGIN
    {
        # Store original preferences.
        $originalInformationPreference = $InformationPreference;

        # Output to file.
        [bool]$outputToFile = $false;
    }
    PROCESS
    { 
        # If log file path is specified.
        if (!([string]::IsNullOrEmpty($Path)))
        {
            # If the message should saved to the log file.
            if ($false -eq $NoLogFile)
            {
                # Do not output to file.
                $outputToFile = $true;
            }
            
            # If log file don't exist.
            if (!(Test-Path -Path $Path -PathType Leaf))
            {
                # Get folder path.
                [string]$folderPath = Split-Path -Path $Path -Parent;

                # If folder path don't exist.
                if (!(Test-Path -Path $folderPath -PathType Container))
                {
                    # Create folder path.
                    $null = New-Item -Path $folderPath -ItemType Directory -Force;
                }

                # Create log file.
                $null = New-Item -Path $Path -ItemType File -Force;
            }
            # If log file exist.
            else
            {
                # If log file should not be appended.
                if ($true -eq $NoAppend)
                {
                    # Clear log file.
                    $null = Clear-Content -Path $Path -Force;
                }
            }
        }        

        # Construct log message.
        [string]$logMessage = '';

        # If date and time should be added to log message.
        if ($false -eq $NoDateTime)
        {
            # Add date and time to log message.
            $logMessage += ('[{0}]' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'));
        }

        # If log level should be added to log message.
        if ($false -eq $NoLogLevel)
        {
            # Add log level to log message.
            $logMessage += ('[{0}]' -f $Level.ToUpper());
        }

        # If category should be added to log message.
        if ($false -eq [string]::IsNullOrEmpty($Category))
        {
            # Add category to log message.
            $logMessage += ('[{0}]' -f $Category);
        }

        # If subcategory should be added to log message.
        if ($false -eq [string]::IsNullOrEmpty($Subcategory))
        {
            # Add category to log message.
            $logMessage += ('[{0}]' -f $Subcategory);
        }

        # If log message is not empty.
        if (!([string]::IsNullOrEmpty($logMessage)))
        {
            # Add message to log message.
            $logMessage = ('{0} {1}' -f $logMessage, $Message);
        }
        # Else log message is empty.
        else
        {
            # Add message to log message.
            $logMessage = ('{0}' -f $Message);
        }
        
  
        switch ($Level)
        {
            'Error'
            {
                Write-Error -Message $logMessage -ErrorAction Stop;
            }
            'Warning'
            {
                Write-Warning -Message $logMessage;
            }
            'Information'
            {
                $InformationPreference = 'Continue';
                Write-Information -MessageData $logMessage;
            }
            'Debug'
            {
                Write-Debug -Message $logMessage;
            }
        }

        # If output should be written to file.
        if ($true -eq $outputToFile)
        {
            # Construct splat parameters.
            $params = @{
                'Path'     = $Path;
                'Force'    = $true;
                'Encoding' = 'utf8';
            }

            # If log file should be appended.
            if ($false -eq $NoAppend)
            {
                # Add append parameter.
                $params.Add('Append', $true);
            }
            

            # Write log message to file.
            $null = $logMessage | Out-File @params;
        }
    }
    END
    {
        # Restore original preferences.
        $InformationPreference = $originalInformationPreference;
    }
}

# Get the IP address from the distinguished name.
function Get-ReverseRecordIPAddress
{
    param
    (
        [Parameter(Mandatory = $true)]    
        [string]$DistinguishedName
    )

    # Get parts.
    $parts = $DistinguishedName.Split(',');

    # IP address.
    $reverseIpAddress = '';

    # Split up the part.
    foreach ($part in $parts)
    {
        # If part starts with "DC=".
        if ($part.StartsWith('DC='))
        {
            # Remove DC part.
            $partData = $part.Replace('DC=', '');

            # If the string contains a digit.
            if ($partData -match '^\d')
            {
                # Remove '.in-addr.arpa'.
                $partData = $partData.Replace('.in-addr.arpa', '');

                # If ip address is empty.
                if ([string]::IsNullOrEmpty($reverseIpAddress))
                {
                    # Add to string.
                    $reverseIpAddress = $partData;
                }
                # Else
                else
                {
                    # Add to string.
                    $reverseIpAddress = $reverseIpAddress + '.' + $partData;
                }
            }
        }
        # Else not IP data.
        else
        {
            # Break loop.
            break;
        }
    }

    # If ip address is not empty.
    if (!([string]::IsNullOrEmpty($reverseIpAddress)))
    {
        # Split the IP address into its constituent parts
        $parts = $reverseIpAddress -split '\.';

        # Reverse the order of the parts
        $reversedParts = $parts[-1..-4];

        # Join the reversed parts back together
        $forwardIpAddress = $reversedParts -join '.';

        # Return object.
        return [PSCustomObject]@{
            ReverseIP = $reverseIpAddress;
            ForwardIP = $forwardIpAddress;
        };
    }
}

# Get the hostname (IP octet) from the reverse zone name and IP address.
function Get-ReverseZoneHostName
{
    param
    (
        # Reverse zone name like '10.in-addr.arpa'    
        [Parameter(Mandatory = $true)]     
        [string]$ZoneName,

        # Reverse zone IP address like '65.40.45.10'
        [Parameter(Mandatory = $true)] 
        [string]$IpAddress
    )

    # Remove in-addr.arpa from the zone name.
    [string]$reverseZoneName = $ZoneName.Replace('.in-addr.arpa', '')

    # Split the reverse zone name into its constituent parts
    [string[]]$reverseZoneNameparts = $reverseZoneName -split '\.';

    # Count the number of octets in the reverse zone name.
    [int]$reverseZoneOctets = $reverseZoneNameparts.Count;

    # Split the IP address.
    [string[]]$ipAddressParts = $IpAddress -split '\.';

    # Calculate the number of missing octets.
    $missingOctets = 4 - $reverseZoneOctets;

    # Extract the missing octets from the IP address.
    $missingOctetsValues = $ipAddressParts[0..($missingOctets - 1)];

    # Hostname to return.
    [string]$hostname = $missingOctetsValues -join '.';

    # Return hostname.
    return $hostname;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log -Message ("Starting log to file '{0}'" -f $transcriptLogFilePath);

# Start transcript.
$null = Start-Transcript -Path $transcriptLogFilePath -Append -NoClobber -Force -ErrorAction SilentlyContinue;

# Write to log.
Write-Log -Message ('Getting all DNS reverse lookup zone, this might take a few seconds');

# Get all reverse lookup zones.
$reverseLookupZones = Get-DnsServerZone | Where-Object { $true -eq $_.IsReverseLookupZone };

# Get target zone.
$targetZone = $reverseLookupZones | Where-Object { $_.ZoneName -eq $TargetZoneName };

# If the target zone do not exist.
if ($null -eq $targetZone)
{
    # Throw execption.
    throw ("The reverse zone '{0}' dont exist, aborting" -f $TargetZoneName);
}

# Object array to store all records.
$sourceResourceRecords = @();

# Foreach reverse lookup zone.
foreach ($reverseLookupZone in $reverseLookupZones)
{
    # Foreach source zone.
    foreach ($sourceZone in $SourceZones)
    {
        # If the zone is specified in the source.
        if ($reverseLookupZone.ZoneName -like $sourceZone)
        {
            # Add to source resource records.
            $sourceResourceRecords += Get-DnsServerResourceRecord -ZoneName $reverseLookupZone.ZoneName;
        }
    }
}

# Get all existing resource records in target reverse zone.
$existingTargetReverseZoneRecords = Get-DnsServerResourceRecord -ZoneName $TargetZoneName;

# Foreach source resource record.
foreach ($sourceResourceRecord in $sourceResourceRecords)
{
    # If the record type should be excluded.
    if ($sourceResourceRecord.RecordType -in $excludeRecordTypes)
    {
        # Write to log.
        Write-Log -Message ("Record '{0}' ({1}) is of type '{2}', skipping" -f $sourceResourceRecord.HostName, $sourceResourceRecord.RecordData.PtrDomainName, $sourceResourceRecord.RecordType);

        # Continue to next record.
        continue;
    }

    # Get IP address.
    $ipAddress = Get-ReverseRecordIPAddress -DistinguishedName $sourceResourceRecord.DistinguishedName -ErrorAction SilentlyContinue;

    # If IP adress is empty.
    if ([string]::IsNullOrEmpty($ipAddress))
    {        
        # Continue to next record.
        continue;
    }

    # Get hostname.
    $hostname = Get-ReverseZoneHostName -ZoneName $TargetZoneName -IpAddress $ipAddress.ReverseIP;

    # Get existing record.
    $existingTargetReverseZoneRecord = $existingTargetReverseZoneRecords | Where-Object {
        $_.HostName -eq $hostname -and
        $_.RecordType -eq $sourceResourceRecord.RecordType
    };

    # If record already exist.
    if ($null -ne $existingTargetReverseZoneRecord)
    {
        # Write to log.
        Write-Log -Message ("PTR '{0}' ({1}) in the zone '{2}' already exist, skipping" -f $hostname, $sourceResourceRecord.RecordData.PtrDomainName, $TargetZoneName);

        # Continue to next record.
        continue;
    }

    # If the record type is PTR.
    if ($sourceResourceRecord.RecordType -eq 'PTR')
    {
        # Try to add the record.
        try
        {
            # Write to log.
            Write-Log -Message ("Adding PTR '{0}' ({1}) to the zone '{2}'" -f $hostname, $sourceResourceRecord.RecordData.PtrDomainName, $TargetZoneName);

            # Add the record.
            Add-DnsServerResourceRecordPtr -Name $hostname `
                -ZoneName $TargetZoneName `
                -PtrDomainName $sourceResourceRecord.RecordData.PtrDomainName;
        }
        catch
        {
            # Write to log.
            Write-Log -Message ("Something went wrong while adding PTR '{0}' ({1}) to the zone '{2}', execption is: {3}" -f $hostname, $sourceResourceRecord.RecordData.PtrDomainName, $TargetZoneName, $_) -Level Warning;
        }
        
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Stop any transcript.
$null = Stop-Transcript -ErrorAction SilentlyContinue;

# Write to log.
Write-Log -Message ("Script execution completed, transcript log file path: '{0}'" -f $transcriptLogFilePath);

############### Finalize - End ###############
#endregion
