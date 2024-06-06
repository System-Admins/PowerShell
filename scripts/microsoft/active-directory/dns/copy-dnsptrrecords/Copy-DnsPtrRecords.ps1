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

.Parameter RemoveSourceRecord
    Remove source records after copy.

.Parameter ExcludeRecordTypes
    Record types to exclude.

.Parameter OutputFilePath
    File path to record export. Default is on the desktop.

.EXAMPLE
    # Copy specific reverse zones to another reverse zone.
    .\Copy-DnsPtrRecords.ps1 -SourceZones @('10.45.10.in-addr.arpa', '20.50.10.in-addr.arpa') -TargetZoneName '10.in-addr.arpa';

.EXAMPLE
    # Copy specific reverse zones to another reverse zone. Delete source records after copy.
    .\Copy-DnsPtrRecords.ps1 -SourceZones @('10.45.10.in-addr.arpa', '20.50.10.in-addr.arpa') -TargetZoneName '10.in-addr.arpa';

.EXAMPLE
    # Use wildcard to copy to another reverse zone.
    .\Copy-DnsPtrRecords.ps1 -SourceZones '*.172.in-addr.arpa' -TargetZoneName '172.in-addr.arpa';

.EXAMPLE
    # Copy specific reverse zones to another reverse zone. Exclude NS and SOA records. Export records to a file.
    .\Copy-DnsPtrRecords.ps1 -SourceZones @('10.45.10.in-addr.arpa', '20.50.10.in-addr.arpa') -TargetZoneName '10.in-addr.arpa' -ExcludeRecordTypes @('NS', 'SOA') -OutputFilePath 'C:\Temp\dnsptrcopy.csv';

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  06-06-2024
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
    [string]$TargetZoneName,

    # Remove source records after copy.
    [Parameter(Mandatory = $false)]
    [switch]$RemoveSourceRecord,

    # Record types to exclude.
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeRecordTypes = @('NS', 'SOA'),

    # File path to record export.
    [Parameter(Mandatory = $false)]
    [string]$OutputFilePath = ('{0}\{1}_dnsptrcopy.csv' -f ([Environment]::GetFolderPath('Desktop'), (Get-Date -Format 'yyyyMMddHHmmss')))
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

# Log file path.
$script:logFilePath = ('{0}\{1}_dnsptrcopy.log' -f ([Environment]::GetFolderPath('Desktop'), (Get-Date -Format 'yyyyMMddHHmmss')));

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

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

# Get the name (IP octet) from the reverse zone name and IP address.
function Get-ReverseZoneName
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

function Write-CustomLog
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
    .PARAMETER NoLogFile
        (Optional) If the log message should not be added to a file.
    .EXAMPLE
        # Write a information message to the console.
        Write-MyLog -Message 'This is an information message'
    .EXAMPLE
        # Write a debug message to a log file and console.
        Write-CustomLog -Message 'This is a debug message' -Path 'C:\Temp\log.txt' -Level Verbose
    .EXAMPLE
        # Write an error message to a log file but not to the console.
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level Error
    .EXAMPLE
        # Write an information message to a log file but not to the console and do not append to the log file.
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level 'Information' -NoAppend
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
        [string]$Path = $script:logFilePath,

        # (Optional) Log level.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Console', 'Error', 'Warning', 'Information', 'Debug', 'Verbose')]
        [string]$Level = 'Information',

        # (Optional) If date and time should not be added to the log message.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoDateTime,

        # (Optional) If the log message should not be appended to the log file.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoAppend,

        # (Optional) If the log level should not be logged.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoLogLevel = $true,

        # (Optional) If the log message should not be added to a file.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoLogFile,

        # (Optional) Indent level (only works when the level is console).
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]$IndentLevel = 0,

        # (Optional) Color of the message (only works when the level is console).
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Green', 'Red', 'Yellow', 'White', 'Black')]
        [string]$Color = 'White'
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


        # Based on the level.
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
            'Verbose'
            {
                Write-Verbose -Message $logMessage;
            }
            'Console'
            {
                # Prefix meessage.
                [string]$prefixMessage = '';

                # For each indent level.
                for ($i = 0; $i -lt $IndentLevel; $i++)
                {
                    # Add indent.
                    $prefixMessage += '  ';
                }

                # If indent level is greater than 0.
                if ($IndentLevel -gt 0)
                {
                    # Add message.
                    $prefixMessage += ('{0}[-] ' -f $prefixMessage);
                }
                # Else indent level is 0.
                else
                {
                    # Add message.
                    $prefixMessage += ('{0}[+] ' -f $prefixMessage);
                }

                # Write to console.
                Write-Host -Object $prefixMessage -NoNewline;
                Write-Host -Object $Message -ForegroundColor $Color;
            }
        }

        # If output should be written to file.
        if ($true -eq $outputToFile)
        {
            # Construct splat parameters.
            $params = @{
                'FilePath' = $Path;
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

function Test-DomainAdmin
{
    [cmdletbinding()]
    param
    (
    )

    # Get current user.
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent();

    # Get current user principal.
    $windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($currentUser);

    # If user is member of the Domain Admins group.
    if ($WindowsPrincipal.IsInRole('Domain Admins'))
    {
        # Return true.
        return $true;
    }
    # Else user is not member of the Domain Admins group.
    else
    {
        # Return false.
        return $false;
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Test if user member of domain admin.
if ($false -eq (Test-DomainAdmin))
{
    # Throw execption.
    throw ("User '{0}\{1}' need to be member of the '{0}\Domain Admins' to run this script" -f $env:USERDOMAIN, $env:USERNAME);
}

# Write to log.
Write-CustomLog -Message ('Starting script') -Level Console;
Write-CustomLog -Message ('{0}' -f (Get-Date).ToString('dd-MM-yyyy HH:mm:ss')) -Level Console -IndentLevel 1;
Write-CustomLog -Message ("Log file available at '{0}'" -f $script:logFilePath) -Level Console -IndentLevel 1;
Write-CustomLog -Message ('Collecting data') -Level Console;
Write-CustomLog -Message ('Getting all reverse lookup zones') -Level Verbose;

# Get all reverse lookup zones.
$reverseLookupZones = Get-DnsServerZone | Where-Object { $true -eq $_.IsReverseLookupZone };

# Write to log.
Write-CustomLog -Message ('Found {0} reverse lookup zones' -f $reverseLookupZones.Count) -Level Console -IndentLevel 1;

# Get target zone.
$targetZone = $reverseLookupZones | Where-Object { $_.ZoneName -eq $TargetZoneName };

# If the target zone do not exist.
if ($null -eq $targetZone)
{
    # Write to log.
    Write-CustomLog -Message ("The target reverse zone '{0}' dont exist, aborting" -f $TargetZoneName) -Level Verbose;

    # Throw execption.
    throw ("The target reverse zone '{0}' dont exist, aborting" -f $TargetZoneName);
}

# Write to log.
Write-CustomLog -Message ("Target reverse lookup zone '{0}' exist" -f $TargetZoneName) -Level Console -IndentLevel 1;

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
            # Write to log.
            Write-CustomLog -Message ("Found reverse lookup zone '{0}' up zone that matches '{1}'" -f $reverseLookupZone.ZoneName, $TargetZoneName) -Level Verbose;

            # Get all resource records in the source zone.
            $dnsServerResourceRecords = Get-DnsServerResourceRecord -ZoneName $reverseLookupZone.ZoneName;

            # Write to log.
            Write-CustomLog -Message ("Reverse zone '{0}' have {1} record(s)" -f $TargetZoneName, $dnsServerResourceRecords.Count) -Level Console -IndentLevel 1;

            # Add to object array.
            $sourceResourceRecords += $dnsServerResourceRecords;
        }
    }
}

# Write to log.
Write-CustomLog -Message ('Analysing data') -Level Console;
Write-CustomLog -Message ('Filtering records to copy, this might take a few minutes' -f $sourceResourceRecords.Count) -Level Console -IndentLevel 1;

# Get all existing resource records in target reverse zone.
$existingTargetReverseZoneRecords = Get-DnsServerResourceRecord -ZoneName $TargetZoneName;

# Object array for records to copy.
$recordsToCopy = @();

# Foreach source resource record.
foreach ($sourceResourceRecord in $sourceResourceRecords)
{
    # Bool if record already exist.
    [bool]$recordAlreadyExist = $false;

    # Bool if record should be skipped.
    [bool]$skipRecord = $false;

    # Get source zone.
    $sourceZoneName = ($sourceResourceRecord.DistinguishedName -split ',')[1] -replace 'DC=', '';

    # If the record type should be excluded.
    if ($sourceResourceRecord.RecordType -in $ExcludeRecordTypes)
    {
        # Set skip record to true.
        $skipRecord = $true;

        # Write to log.
        Write-CustomLog -Category $sourceZoneName -Subcategory $sourceResourceRecord.HostName -Message ("Skipping due to record type '{0}'" -f $sourceResourceRecord.RecordType) -Level Verbose;
    }

    # Get IP address.
    $ipAddress = Get-ReverseRecordIPAddress -DistinguishedName $sourceResourceRecord.DistinguishedName -ErrorAction SilentlyContinue;

    # If IP adress is empty.
    if ([string]::IsNullOrEmpty($ipAddress))
    {
        # Write to log.
        Write-CustomLog -Category $sourceZoneName -Subcategory $sourceResourceRecord.HostName -Message ('Skipping due to no IP-address available in source record') -Level Verbose;

        # Continue to next record.
        continue;
    }

    # Get name.
    $name = Get-ReverseZoneName -ZoneName $TargetZoneName -IpAddress $ipAddress.ReverseIP;

    # Get existing record.
    $existingTargetReverseZoneRecord = $existingTargetReverseZoneRecords | Where-Object {
        $_.HostName -eq $name -and
        $_.RecordType -eq $sourceResourceRecord.RecordType
    };

    # If record already exist.
    if ($null -ne $existingTargetReverseZoneRecord)
    {
        # Set record already exist to true.
        $recordAlreadyExist = $true;

        # Write to log.
        Write-CustomLog -Category $sourceZoneName -Subcategory $sourceResourceRecord.HostName -Message ("Already exist in the target reverse lookup zone '{0}'" -f $TargetZoneName) -Level Verbose;
    }

    # If the record type is PTR.
    if ($sourceResourceRecord.RecordType -eq 'PTR')
    {
        # Add to records to copy.
        $recordsToCopy += [PSCustomObject]@{
            SourceName              = $sourceResourceRecord.HostName;
            TargetName              = $name;
            SourceZoneName          = $sourceZoneName;
            TargetZoneName          = $TargetZoneName;
            RecordExistInTargetZone = $recordAlreadyExist;
            PtrDomainName           = $sourceResourceRecord.RecordData.PtrDomainName;
            SkipRecord              = $skipRecord;
            ReverseIP               = $ipAddress.ReverseIP;
            ForwardIP               = $ipAddress.ForwardIP;
            SourceAddCommand        = ('Add-DnsServerResourceRecordPtr -Name "{0}" -ZoneName "{1}" -PtrDomainName "{2}"' -f $sourceResourceRecord.HostName, $sourceZoneName, $sourceResourceRecord.RecordData.PtrDomainName);
            TargetAddCommand        = ('Add-DnsServerResourceRecordPtr -Name "{0}" -ZoneName "{1}" -PtrDomainName "{2}"' -f $name, $TargetZoneName, $sourceResourceRecord.RecordData.PtrDomainName);
            SourceRemoveCommand     = ('Remove-DnsServerResourceRecord -ZoneName "{0}" -Name "{1}" -RRType Ptr -Force' -f $sourceZoneName, $sourceResourceRecord.HostName);
            TargetRemoveCommand     = ('Remove-DnsServerResourceRecord -ZoneName "{0}" -Name "{1}" -RRType Ptr -Force' -f $TargetZoneName, $name);
        };
    }
}

# If no records to copy.
if ($recordsToCopy.Count -eq 0)
{
    # Write to log.
    Write-CustomLog -Message ('No records to copy') -Level Console -IndentLevel 1;

    # Exit script.
    return;
}
# Else records to copy.
else
{
    # Write to log.
    Write-CustomLog -Message ("Found {0} record(s) for copy to zone '{1}'" -f $recordsToCopy.Count, $TargetZoneName) -Level Console -IndentLevel 1;
}

# Write to log.
Write-CustomLog -Message ('Exporting data') -Level Console;
Write-CustomLog -Message ("Saving records for copy to file '{0}'" -f $OutputFilePath) -Level Console -IndentLevel 1;

# Create output folder.
$null = New-Item -Path (Split-Path -Path $OutputFilePath -Parent) -ItemType Directory -Force;

# Exporting records to file.
$recordsToCopy | Export-Csv -Path $OutputFilePath -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force;

# Write to log.
Write-CustomLog -Message ('Copy data') -Level Console;

# Copy step.
[string]$copyStep = '';

# Sort by source zone.
$recordsToCopy = $recordsToCopy | Sort-Object -Property SourceZoneName;

# Foreach record to copy.
foreach ($recordToCopy in $recordsToCopy)
{
    # If copy step is not the same.
    if ($copyStep -ne $recordToCopy.SourceZoneName)
    {
        # Set copy step.
        $copyStep = $recordToCopy.SourceZoneName;

        # Write to log.
        Write-CustomLog -Message ("Copying records from '{0}' to '{1}'" -f $recordToCopy.SourceZoneName, $recordToCopy.TargetZoneName) -Level Console -IndentLevel 1;
    }

    # If the record was added and the record should be removed from the source zone.
    if ($true -eq $RemoveSourceRecord)
    {
        # Try to remove the record from the source zone.
        try
        {
            # Remove the record from the source zone.
            $null = Remove-DnsServerResourceRecord -ZoneName $recordToCopy.SourceZoneName -Name $recordToCopy.SourceName -RRType Ptr -Force -ErrorAction Stop;

            # Write to log.
            Write-CustomLog -Message ("Removed record '{0}' from zone '{1}'" -f $recordToCopy.SourceName, $recordToCopy.SourceZoneName) -Level Verbose;
        }
        # Something went wrong.
        catch
        {
            # Throw execption.
            Write-CustomLog -Message ("Something went wrong while removing PTR record '{0}' from zone '{1}'" -f $recordToCopy.SourceName, $recordToCopy.SourceZoneName) -Level Console -IndentLevel 1;
            Write-CustomLog -Message ($_) -Level Verbose;
        }
    }

    # If the record should be skipped.
    if ($recordToCopy.SkipRecord)
    {
        # Write to log.
        Write-CustomLog -Message ("Skipping record '{0}' from zone '{1}'" -f $recordToCopy.SourceName, $recordToCopy.SourceZoneName) -Level Verbose;

        # Continue to next record.
        continue;
    }

    # If the record already exist in the target zone.
    if ($recordToCopy.RecordExistInTargetZone)
    {
        # Write to log.
        Write-CustomLog -Message ("Skipping record '{0}' from zone '{1}', because it already exist in target zone '{2}'" -f $recordToCopy.SourceName, $recordToCopy.SourceZoneName, $recordToCopy.TargetZoneName) -Level Verbose;

        # Continue to next record.
        continue;
    }

    # Try to add the record to the target zone.
    try
    {
        # Add the record to the target zone.
        $null = Add-DnsServerResourceRecordPtr -Name $recordToCopy.TargetName -ZoneName $recordToCopy.TargetZoneName -PtrDomainName $recordToCopy.PtrDomainName -ErrorAction Stop;

        # Write to log.
        Write-CustomLog -Message ("Added record '{0}' from zone '{1}' to the target zone '{2}'" -f $recordToCopy.SourceName, $recordToCopy.SourceZoneName, $recordToCopy.TargetZoneName) -Level Verbose;
    }
    # Something went wrong.
    catch
    {
        # Write to log.
        Write-CustomLog -Message ("Something went wrong while adding PTR record '{0}' to zone '{1}'" -f $recordToCopy.PtrDomainName, $recordToCopy.TargetZoneName, $_) -Level Console -IndentLevel 1;
        Write-CustomLog -Message ($_) -Level Verbose;
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-CustomLog -Message ('Finished script') -Level Console;
Write-CustomLog -Message ('{0}' -f (Get-Date).ToString('dd-MM-yyyy HH:mm:ss')) -Level Console -IndentLevel 1;
Write-CustomLog -Message ("Log file available at '{0}'" -f $script:logFilePath) -Level Console -IndentLevel 1;

############### Finalize - End ###############
#endregion
