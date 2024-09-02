#Requires -version 5.1;

<#
.SYNOPSIS
  Find orphaned DNS records (A and PTR) from Active Directory DNS.

.DESCRIPTION
  This script will search for orphaned DNS records (A and PTR).
  Orphaned meaning no corresponding record in the other zone.
  It will export the orphaned records to CSV files on the desktop.

.Example
   .\Get-DnsOrphanedRecord.ps1;

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  02-09-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]
[OutputType([void])]
param
(
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

# Get datetime.
$today = Get-Date;

# Export path.
$ExportPtrRecordFilePath = ('{0}\{1}_orphanedPtrRecords.csv' -f [Environment]::GetFolderPath('Desktop'), $today.ToString('yyyy-MM-dd'));
$ExportARecordFilePath = ('{0}\{1}_orphanedARecords.csv' -f [Environment]::GetFolderPath('Desktop'), $today.ToString('yyyy-MM-dd'));

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

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
    .PARAMETER IndentLevel
        (Optional) Indent level (only works when the level is console).
    .PARAMETER Color
        (Optional) Color of the message (only works when the level is console).
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
    .EXAMPLE
        # Write an information message to the console with indentlevel 1 and the color green.
        Write-CustomLog -Message 'Some output here' -Level 'Console' -IndentLevel 1 -Color 'Green'
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
        [bool]$NoLogLevel = $false,

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

function Get-DnsZone
{
    <#
    .SYNOPSIS
        Get all DNS zones in the domain.
    .DESCRIPTION
        Returns object array with all DNS zones in the domain.
    .EXAMPLE
        Get-DnsZone;
    #>
    [cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
    )

    BEGIN
    {
        # Write to log.
        Write-CustomLog -Message ("Starting processing '{0}'" -f $MyInvocation.MyCommand.Name) -Level Verbose;

        # Get random for write progress function.
        $writeProgressId = Get-Random;

        # Write progress.
        Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Getting all DNS zones';

        # Get Active Directory forest.
        $adForest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest();

        # Get DomainDnsZones application partitions.
        $dnsApplicationPartitions = ($adForest.ApplicationPartitions | Where-Object { $_ -like '*DnsZones*' }).Name;

        # Object array for DNS zones.
        $dnsZones = New-Object System.Collections.ArrayList;
    }
    PROCESS
    {
        # Foreach DNS application partition.
        foreach ($dnsApplicationPartition in $dnsApplicationPartitions)
        {
            # Construct search base.
            [string]$searchBase = ('{0}' -f $dnsApplicationPartition);

            # Try to get objects.
            try
            {
                # Write to log.
                Write-CustomLog -Message ("Trying to get zones from '{0}'" -f $searchBase) -Level Verbose;

                # Create ADSI searcher.
                $adsiSearcher = New-Object System.DirectoryServices.DirectorySearcher;

                # Set the filter.
                $adsiSearcher.Filter = '(objectClass=dnsZone)';

                # Set search size.
                $adsiSearcher.PageSize = 2000;

                # Set search base.
                $adsiSearcher.SearchRoot = [ADSI]"LDAP://$searchBase";

                # Write to log.
                Write-CustomLog -Message ('Searching in forest, this could take some time depending on the data') -Level Verbose;

                # Find all DNS nodes.
                $adObjects = $adsiSearcher.FindAll();

                # Write to log.
                Write-CustomLog -Message ("Successfully got zones from '{0}'" -f $searchBase) -Level Verbose;
            }
            # Something went wrong.
            catch
            {
                # If error is not found.
                if ($_ -notlike '*The supplied distinguishedName must belong to one of the following partition(s)*')
                {
                    # Write to log.
                    Write-CustomLog -Message ("Something went wrong getting zones from '{0}'. {1}" -f $searchBase, $_) -Level Verbose;
                }

                # Write to log.
                Write-CustomLog -Message ("Not able to get zones from '{0}', skipping" -f $searchBase) -Level Verbose;

                # Continue with next DNS application partition.
                continue;
            }

            # Foreach object.
            foreach ($adObject in $adObjects)
            {
                # Type of zone.
                [string]$zone = '';

                # If object have ".in-addr.arpa", then it is a reverse zone.
                if ($adObject.Properties.name -like '*.in-addr.arpa')
                {
                    # Reverse zone.
                    $zone = 'Reverse';
                }
                # Else forward zone.
                else
                {
                    # Forward zone.
                    $zone = 'Forward';
                }

                # Add zone to array.
                $null = $dnsZones.Add(
                    [PSCustomObject]@{
                        DistinguishedName = [string]($adObject.Properties).distinguishedname;
                        Name              = [string]($adObject.Properties).name;
                        Type              = $zone;
                    }
                );
            }
        }

        # Write to log.
        Write-CustomLog -Message ('Found {0} DNS zones' -f $dnsZones.Count) -Level Verbose;
    }
    END
    {
        # Write progress.
        Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Getting all DNS zones' -Completed;

        # Write to log.
        Write-CustomLog -Message ("Ending process '{0}'" -f $MyInvocation.MyCommand.Name) -Level Verbose;

        # Return DNS zones.
        return $dnsZones;
    }
}

function Get-DnsRecord
{
    <#
    .SYNOPSIS
        Get all DNS records in the domain.
    .DESCRIPTION
        Returns object array with all DNS records in the domain.
    .EXAMPLE
        Get-DnsRecord;
    #>
    [cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
        # DNS zone (specify as DistinguishedName) to search in.
        [Parameter(Mandatory = $false)]
        [string]$DnsZone
    )

    BEGIN
    {
        # Write to log.
        Write-CustomLog -Message ("Starting processing '{0}'" -f $MyInvocation.MyCommand.Name) -Level Verbose;

        # Get random for write progress function.
        $writeProgressId = Get-Random;

        # Write progress.
        Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Getting all DNS records';

        # Create ADSI searcher.
        $adsiSearcher = New-Object System.DirectoryServices.DirectorySearcher;

        # Set the filter.
        $adsiSearcher.Filter = '(objectClass=dnsNode)';

        # Set search size.
        $adsiSearcher.PageSize = 2000;

        # If DNS zone is specified.
        if (!([string]::IsNullOrEmpty($DnsZone)))
        {
            # Set search base.
            $adsiSearcher.SearchRoot = [ADSI]"LDAP://$DnsZone";

            # Write to log.
            Write-CustomLog -Message ('Searching in zone "{0}"' -f $DnsZone) -Level Verbose;
        }

        # Write to log.
        Write-CustomLog -Message ('Searching in forest, this could take some time depending on the data') -Level Verbose;

        # Find all DNS nodes.
        $dnsNodes = $adsiSearcher.FindAll();

        # Object array for DNS records.
        [System.Collections.ArrayList]$dnsRecords = New-Object System.Collections.ArrayList;
    }
    PROCESS
    {
        # Foreach dnsNode.
        foreach ($dnsNode in $dnsNodes)
        {
            # Get the DNS record.
            $dnsRecord = $dnsNode.Properties['dnsRecord'];

            # Get distinguished name.
            [string]$distinguishedName = $dnsNode.Properties['distinguishedName'];

            # Try to get the DNS record data.
            try
            {
                # Write to log.
                Write-CustomLog -Message ("Trying to get DNS record from '{0}'" -f $distinguishedName) -Level Verbose;

                # Add object to array.
                $dnsRecords += Get-DnsRecordData -dnsRecord $dnsRecord -DistinguishedName $distinguishedName;

                # Write to log.
                Write-CustomLog -Message ("Successfully converted DNS record from '{0}'" -f $distinguishedName) -Level Verbose;
            }
            # Something went wrong.
            catch
            {
                # Write to log.
                Write-CustomLog -Message ("Something went wrong while converting DNS record from '{0}'. {1}" -f $distinguishedName, $_) -Level Verbose;
            }
        }
    }
    END
    {
        # Dispose searcher.
        $adsiSearcher.Dispose();

        # Write to log.
        Write-CustomLog -Message ('Found {0} DNS records in the forest' -f $dnsRecords.Count) -Level Verbose;

        # Write progress.
        Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Getting all DNS records' -Completed;

        # Write to log.
        Write-CustomLog -Message ("Ending process '{0}'" -f $MyInvocation.MyCommand.Name) -Level Verbose;

        # Return DNS records.
        return $dnsRecords;
    }
}

function Get-DnsRecordData
{
    <#
    .SYNOPSIS
        Convert the DNSRecord from byte array.
    .DESCRIPTION
        Returns DNS object.
    .PARAMETER DnsRecord
        Input DNS record (from ADSI search).
    .PARAMETER DistinguishedName
        Distinguished name.
    .EXAMPLE
        Get-DnsRecordData -DnsRecord $dnsRecord -DistinguishedName $distinguishedName;
    #>
    param
    (
        # Input DNS record (from ADSI search).
        [Parameter(Mandatory = $true)]
        $DnsRecord,

        # Distinguished name.
        [Parameter(Mandatory = $true)]
        [string]$DistinguishedName
    )

    # Record name.
    $recordName = (($DistinguishedName -split ',CN=MicrosoftDNS')[0]).Replace(',', '').Replace('DC=', '.').Substring(1);

    # If DNS record is not a byte array.
    if ($dnsRecord -isnot [byte[]])
    {
        # Convert DNS record to byte array.
        [byte[]]$dnsRecordByteArray = $dnsRecord | Out-String -Stream;
    }
    else
    {
        # Set DNS record byte array.
        [byte[]]$dnsRecordByteArray = $dnsRecord;
    }

    # Get record type (type of DNS record).
    $recordDataType = Convert-TwoBytesToLittleEndian -InputArray $dnsRecordByteArray -StartIndex 2;

    # Get TTL (Time To Live).
    $recordTtl = Convert-FourBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 12;

    # Get timestamp of when the record expires.
    $recordAge = Convert-FourBytesToLittleEndian -InputArray $dnsRecordByteArray -StartIndex 20;

    # Set time stamp.
    [string]$timestamp = '[static]';

    # If age is not zero (static).
    if ($recordAge -gt 0 -and $recordAge -lt 9999999)
    {
        # Get timestamp.
        $timestamp = ((Get-Date -Year 1601 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0).AddHours($recordAge)).ToString('dd-MM-yyyy HH:mm:ss');
    }

    # Get the DNS zone.
    $dnsZoneName = (($DistinguishedName -split ',CN=MicrosoftDNS') -split ',')[1] -replace 'DC=', '';

    # Record data.
    [PSCustomObject]$dnsObject = New-Object -TypeName PSCustomObject;

    # Add properties to the object.
    $dnsObject | Add-Member -MemberType NoteProperty -Name 'DistinguishedName' -Value $DistinguishedName;
    $dnsObject | Add-Member -MemberType NoteProperty -Name 'Name' -Value $recordName;
    $dnsObject | Add-Member -MemberType NoteProperty -Name 'TTL' -Value $recordTtl;
    $dnsObject | Add-Member -MemberType NoteProperty -Name 'Timestamp' -Value $timestamp;
    $dnsObject | Add-Member -MemberType NoteProperty -Name 'ZoneName' -Value $dnsZoneName;

    # Switch on record type.
    switch ($recordDataType)
    {
        # A record.
        1
        {
            # Get ip address.
            $ipAddress = ('{0}.{1}.{2}.{3}' -f $dnsRecordByteArray[24], $dnsRecordByteArray[25], $dnsRecordByteArray[26], $dnsRecordByteArray[27]);

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'A';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value $ipAddress;
        }
        # NS record.
        2
        {
            # Get encoded name.
            $nsName = ConvertFrom-EncodedDnsName -InputArray $dnsRecordByteArray -StartIndex 24;

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'NS';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value $nsName;
        }
        # CNAME record.
        5
        {
            # Get encoded name.
            $cnameName = ConvertFrom-EncodedDnsName -InputArray $dnsRecordByteArray -StartIndex 24;

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'CNAME';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value $cnameName;
        }
        # SOA record.
        6
        {
            # Get name server length.
            $nameServerLength = $dnsRecordByteArray[44];

            # Get primary name server.
            $primaryNameServer = ConvertFrom-EncodedDnsName -InputArray $dnsRecordByteArray -StartIndex 44;

            # Set index.
            $index = 46 + $nameServerLength + $nameServerLength;

            # Get responsible party.
            $responsibleParty = ConvertFrom-EncodedDnsName -InputArray $dnsRecordByteArray -StartIndex $index;

            # Get serial.
            $serial = Convert-FourBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 24;

            # Get refresh.
            $refresh = Convert-FourBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 28;

            # Get retry.
            $retry = Convert-FourBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 32;

            # Get expire.
            $expire = Convert-FourBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 36;

            # Get minimum TTL.
            $minimumTtl = Convert-FourBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 40;

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'SOA';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value ([PSCustomObject]@{
                    PrimaryServer    = $primaryNameServer;
                    ResponsibleParty = $responsibleParty;
                    Serial           = $serial;
                    Refresh          = $refresh;
                    Retry            = $retry;
                    Expire           = $expire;
                    MinimumTtl       = $minimumTtl;
                }
            );
        }
        # PTR record.
        12
        {
            # Get encoded name.
            $ptrName = ConvertFrom-EncodedDnsName -InputArray $dnsRecordByteArray -StartIndex 24;

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'PTR';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value $ptrName;
        }
        # HINFO record.
        13
        {
            # CPU type.
            [string]$cpuType = '';
            [string]$osType = '';

            # Get segment length.
            [int]$segmentLength = $dnsRecordByteArray[24];

            # Set index.
            [int]$index = 25;

            # While segment length is not zero.
            while ($segmentLength-- -ne 0)
            {
                # Add to CPU type.
                $cpuType += [char]$dnsRecordByteArray[$index++];
            }

            # Set index.
            $index = 24 + $dnsRecordByteArray[24] + 1;

            # Get segment length.
            $segmentLength = $index++;

            # While segment length is not zero.
            while ($segmentLength-- -ne 0)
            {
                # Add to OS type.
                $osType += [char]$dnsRecordByteArray[$index++];
            }

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'HINFO';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value ([PSCustomObject]@{
                    CpuType = $cpuType;
                    OsType  = $osType;
                }
            );
        }
        # MX record.
        15
        {
            # Get priority.
            $priority = Convert-TwoBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 24;

            # Get encoded name.
            $mxHost = ConvertFrom-EncodedDnsName -InputArray $dnsRecordByteArray -StartIndex 26;

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'MX';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value ([PSCustomObject]@{
                    Priority = $priority;
                    Host     = $mxhost;
                }
            );
        }
        # TXT record.
        16
        {
            # TXT data.
            $txtData = '';

            # Get segment length.
            [int]$segmentLength = $dnsRecordByteArray[24];

            # Set index.
            [int]$index = 25;

            # While segment length is not zero.
            while ($segmentLength-- -ne 0)
            {
                # Add to TXT data.
                $txtData += [char]$dnsRecordByteArray[$index++];
            }

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'TXT';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value $txtData;
        }
        # AAAA record.
        28
        {
            # IPv6 address.
            [string]$ipv6Address = '';

            # For each segment.
            for ($i = 24; $i -lt 40; $i += 2)
            {
                # Get segment.
                $segment = Convert-TwoBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex $i;

                # Add to IPv6 address.
                $ipv6Address += ($segment).ToString('x4')

                # If not last segment.
                if ($i -ne 38)
                {
                    # Add colon.
                    $ipv6Address += ':'
                }
            }

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'AAAA';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value $ipv6Address;
        }
        # SRV record.
        33
        {
            # Get priority.
            $priority = Convert-TwoBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 24;

            # Get weight.
            $weight = Convert-TwoBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 26;

            # Get port.
            $port = Convert-TwoBytesToBigEndian -InputArray $dnsRecordByteArray -StartIndex 28;

            # Get encoded name.
            $srvName = ConvertFrom-EncodedDnsName -InputArray $dnsRecordByteArray -StartIndex 30;

            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'SRV';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value ([PSCustomObject]@{
                    Priority = $priority;
                    Weight   = $weight;
                    Port     = $port;
                    Name     = $srvName;
                }
            );
        }
        # Unknown record.
        default
        {
            # Add to object.
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'Unknown';
            $dnsObject | Add-Member -MemberType NoteProperty -Name 'Data' -Value '';
        }
    }

    # Return the DNS object.
    return $dnsObject;
}

function Convert-FourBytesToBigEndian
{
    <#
    .SYNOPSIS
        Big endian - Convert four consecutive bytes into a 32-bit integer value.
    .DESCRIPTION
        Convert four consecutive bytes into a 32-bit integer value.
	.PARAMETER InputArray
		The input array of bytes.
	.PARAMETER StartIndex
		The index of the first byte in the four-byte sequence.
    .EXAMPLE
        Convert-FourBytesToBigEndian -InputArray $InputArray -StartIndex $StartIndex;
    #>
    [cmdletbinding()]
    [OutputType([int])]
    param
    (
        # The input array of bytes.
        [Parameter(Mandatory = $true)]
        [System.Byte[]]$InputArray,

        # The index of the first byte in the four-byte sequence.
        [Parameter(Mandatory = $true)]
        [int]$StartIndex
    )

    # Convert the four bytes into a 32-bit integer value.
    $result = $InputArray[$StartIndex + 0];
    $result = ($result * 256) + $InputArray[$StartIndex + 1];
    $result = ($result * 256) + $InputArray[$StartIndex + 2];
    $result = ($result * 256) + $InputArray[$StartIndex + 3];

    # Return the 32-bit integer value.
    return $result;
}

function Convert-FourBytesToLittleEndian
{
    <#
    .SYNOPSIS
        Little endian - Convert four consecutive bytes into a 32-bit integer value.
    .DESCRIPTION
        Convert four consecutive bytes into a 32-bit integer value.
	.PARAMETER InputArray
		The input array of bytes.
	.PARAMETER StartIndex
		The index of the first byte in the four-byte sequence.
    .EXAMPLE
        Convert-FourBytesToLittleEndian -InputArray $InputArray -StartIndex $StartIndex;
    #>
    [cmdletbinding()]
    [OutputType([int])]
    param
    (
        # The input array of bytes.
        [Parameter(Mandatory = $true)]
        [System.Byte[]]$InputArray,

        # The index of the first byte in the four-byte sequence.
        [Parameter(Mandatory = $true)]
        [int]$StartIndex
    )

    # Convert the four bytes into a 32-bit integer value.
    $result = $InputArray[$StartIndex + 3];
    $result = ($result * 256) + $InputArray[$StartIndex + 2];
    $result = ($result * 256) + $InputArray[$StartIndex + 1];
    $result = ($result * 256) + $InputArray[$StartIndex + 0];

    # Return the 32-bit integer value.
    return $result;
}

function Convert-TwoBytesToBigEndian
{
    <#
    .SYNOPSIS
        Big endian - Convert two consecutive bytes into a 16-bit integer value.
    .DESCRIPTION
        Convert two consecutive bytes into a 16-bit integer value.
	.PARAMETER InputArray
		The input array of bytes.
	.PARAMETER StartIndex
		The index of the first byte in the two-byte sequence.
    .EXAMPLE
        Convert-FourBytesToLittleEndian -InputArray $InputArray -StartIndex $StartIndex;
    #>
    [cmdletbinding()]
    [OutputType([int])]
    param
    (
        # The input array of bytes.
        [Parameter(Mandatory = $true)]
        [System.Byte[]]$InputArray,

        # The index of the first byte in the two-byte sequence.
        [Parameter(Mandatory = $true)]
        [int]$StartIndex
    )

    # Convert the two bytes into a 16-bit integer value.
    $result = $InputArray[$StartIndex + 0];
    $result = ($result * 256) + $InputArray[$StartIndex + 1];

    # Return the 16-bit integer value.
    return $result;
}

function Convert-TwoBytesToLittleEndian
{
    <#
	.SYNOPSIS
		Little endian - Convert two consecutive bytes into a 16-bit integer value.
	.DESCRIPTION
		Convert two consecutive bytes into a 16-bit integer value.
	.PARAMETER InputArray
		The input array of bytes.
	.PARAMETER StartIndex
		The index of the first byte in the two-byte sequence.
	.EXAMPLE
		Convert-TwoBytesToLittleEndian -InputArray $InputArray -StartIndex $StartIndex;
	#>
    [cmdletbinding()]
    [OutputType([int])]
    param
    (
        # The input array of bytes.
        [Parameter(Mandatory = $true)]
        [System.Byte[]]$InputArray,

        # The index of the first byte in the two-byte sequence.
        [Parameter(Mandatory = $true)]
        [int]$StartIndex
    )

    # Convert the two bytes into a 16-bit integer value.
    $result = $InputArray[$StartIndex + 1];
    $result = ($result * 256) + $InputArray[$StartIndex + 0];

    # Return the 16-bit integer value.
    return $result;
}

function ConvertFrom-EncodedDnsName
{
    <#
	.SYNOPSIS
		Decode DNS name from the input array of bytes.
	.DESCRIPTION
		Convert the input array of bytes into a DNS name.
	.PARAMETER InputArray
		The input array of bytes.
	.PARAMETER StartIndex
		The index of the first byte in the two-byte sequence.
	.EXAMPLE
		ConvertFrom-EncodedDnsName -InputArray $InputArray -StartIndex $StartIndex;
	#>
    [cmdletbinding()]
    [OutputType([string])]
    param
    (
        # The input array of bytes.
        [Parameter(Mandatory = $true)]
        [System.Byte[]]$InputArray,

        # The index of the first byte in the DNS name.
        [Parameter(Mandatory = $true)]
        [int]$StartIndex
    )

    # Get segments.
    [int]$segments = $InputArray[$StartIndex + 1];

    # Get index.
    [int]$index = $StartIndex + 2;

    # Initialize the DNS name.
    [string]$name = '';

    # Decode the DNS name.
    while ($segments-- -gt 0)
    {
        # Get segment length.
        [int]$segmentLength = $InputArray[$index++];

        # While the segment length is not zero.
        while ($segmentLength-- -gt 0)
        {
            # Get the character.
            $name += [char]$InputArray[$index++];
        }

        # Add a dot to separate segments.
        $name += '.';
    }

    # Return the decoded DNS name.
    return $name;
}

function Get-DnsOrphanedPtrRecord
{
    <#
    .SYNOPSIS
        Get all orphaned PTR records (missing or incorrect data).
    .DESCRIPTION
        Returns object array with all orphaned PTR DNS records in the domain.
    .EXAMPLE
        Get-DnsOrphanedPtrRecord;
    #>
    [cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
        # DNS records.
        [Parameter(Mandatory = $true)]
        $DnsRecord
    )

    BEGIN
    {
        # Write to log.
        Write-CustomLog -Message ("Starting processing '{0}'" -f $MyInvocation.MyCommand.Name) -Level Verbose;

        # Get random for write progress function.
        $writeProgressId = Get-Random;

        # Write progress.
        Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Getting all orphaned DNS PTR records';

        # Get only PTR records.
        $ptrRecords = $dnsRecords | Where-Object { $_.Type -eq 'PTR' };

        # Get only A records.
        $aRecords = $dnsRecords | Where-Object { $_.Type -eq 'A' };

        # Object array.
        $orphanedPtrRecords = New-Object System.Collections.ArrayList;
    }
    PROCESS
    {
        # Write to log.
        Write-CustomLog -Message ("Finding orphaned PTR records where A-record don't exist or have a wrong IP, this could take some time") -Level Verbose;

        # Foreach PTR record.
        foreach ($ptrRecord in $ptrRecords)
        {
            # Get the IP address from name.
            $ipAddress = (($ptrRecord.Name -split '\.in-addr.arpa') -split '\.')[3..0] -join '.';

            # Get the A-record name (remove . in the end of string).
            $aRecordName = ($ptrRecord.Data).Substring(0, ($ptrRecord.Data).Length - 1);

            # Boolean to check if PTR record is missing or incorrect.
            $aRecordExist = $false;

            # Foreach A record.
            foreach ($aRecord in $aRecords)
            {
                # If PTR record is found.
                if ($aRecord.Name -ne $aRecordName)
                {
                    # Continue to next A record.
                    continue;
                }

                # If there is a mismatch between PTR and A record data.
                if ($aRecord.Data -ne $ipAddress)
                {
                    # Continue to next A record.
                    continue;
                }

                # A record is found.
                $aRecordExist = $true;
            }

            # If A record is missing.
            if ($false -eq $aRecordExist)
            {
                # Write to log.
                Write-CustomLog -Message ("PTR record '{0}' in zone '{1}' is orphaned" -f $ptrRecord.Name, $ptrRecord.ZoneName) -Level Verbose;

                # Add to missing A records.
                $null = $orphanedPtrRecords.Add($ptrRecord);
            }
        }
    }
    END
    {
        # Write to log.
        Write-CustomLog -Message ('Found {0} orphaned PTRrecords in the forest' -f $orphanedPtrRecords.Count) -Level Verbose;

        # Write progress.
        Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Getting all orphaned DNS PTR records' -Completed;

        # Write to log.
        Write-CustomLog -Message ("Ending process '{0}'" -f $MyInvocation.MyCommand.Name) -Level Verbose;

        # Return DNS records.
        return $orphanedPtrRecords;
    }
}

function Get-DnsOrphanedARecord
{
    <#
    .SYNOPSIS
        Get all orphaned A records (not linked to a PTR record).
    .DESCRIPTION
        Returns object array with all orphaned A DNS records in the domain.
    .EXAMPLE
        Get-DnsOrphanedARecord;
    #>
    [cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
        # DNS records.
        [Parameter(Mandatory = $true)]
        $DnsRecord
    )

    BEGIN
    {
        # Write to log.
        Write-CustomLog -Message ("Starting processing '{0}'" -f $MyInvocation.MyCommand.Name) -Level Verbose;

        # Get random for write progress function.
        $writeProgressId = Get-Random;

        # Write progress.
        Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Getting all orphaned DNS A records';

        # Get only PTR records.
        $ptrRecords = $dnsRecords | Where-Object { $_.Type -eq 'PTR' };

        # Get only A records.
        $aRecords = $dnsRecords | Where-Object { $_.Type -eq 'A' };

        # Object array.
        $orphanedARecords = New-Object System.Collections.ArrayList;
    }
    PROCESS
    {
        # Write to log.
        Write-CustomLog -Message ("Finding orphaned A records where PTR-record don't exist or have a wrong IP, this could take some time") -Level Verbose;

        # Foreach A-record.
        foreach ($aRecord in $aRecords)
        {
            # Boolean to check if A record does not have a A-record or is incorrect.
            $ptrRecordExist = $false;

            # Foreach PTR-record.
            foreach ($ptrRecord in $ptrRecords)
            {
                # Get the IP address from name.
                $ipAddress = (($ptrRecord.Name -split '\.in-addr.arpa') -split '\.')[3..0] -join '.';

                # Get the A-record name (remove . in the end of string).
                $ptrData = ($ptrRecord.Data).Substring(0, ($ptrRecord.Data).Length - 1);

                # If the A-record name does not match the PTR.
                if ($aRecord.Name -ne $ptrData)
                {
                    # Continue to next PTR-record.
                    continue;
                }

                # If the A-record data does not match the PTR.
                if ($aRecord.Data -ne $ipAddress)
                {
                    # Continue to next PTR-record.
                    continue;
                }

                # PTR record is found.
                $ptrRecordExist = $true;
            }

            # If PTR record is missing or incorrect.
            if ($false -eq $ptrRecordExist)
            {
                # Write to log.
                Write-CustomLog -Message ("A record '{0}' in zone '{1}' with IP '{2}' do not have PTR-record associated" -f $aRecord.Name, $aRecord.ZoneName, $aRecord.Data) -Level Verbose;

                # Add to missing PTR records.
                $null = $orphanedARecords.Add($aRecord);
            }
        }
    }
    END
    {
        # Write to log.
        Write-CustomLog -Message ('Found {0} orphaned A-records in the forest' -f $orphanedARecords.Count) -Level Verbose;

        # Write progress.
        Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Getting all orphaned DNS A records' -Completed;

        # Write to log.
        Write-CustomLog -Message ("Ending process '{0}'" -f $MyInvocation.MyCommand.Name) -Level Verbose;

        # Return DNS records.
        return $orphanedARecords;
    }
}

function Test-DomainJoined
{
    <#
	.SYNOPSIS
		Test is computer is domain joined.
	.DESCRIPTION
		Return true or false based on the computer is domain joined.
	.EXAMPLE
		Test-DomainJoined;
	#>
    [cmdletbinding()]
    [OutputType([bool])]
    param
    (
    )

    # Get the device registration status.
    $dsRegStatus = Get-DsRegStatus;

    # If the device is domain joined.
    if ($dsRegStatus.DomainJoined -eq 'YES')
    {
        # Return true.
        return $true;
    }
    # Else the device is not domain joined.
    else
    {
        # Return false.
        return $false;
    }
}

function Get-DsRegStatus
{
    <#
    .SYNOPSIS
        Get the status of the device registration.
    .DESCRIPTION
        Return the status of the device registration.
    .EXAMPLE
        Get-DsRegStatus;
    #>
    [cmdletbinding()]
    [OutputType([PSObject])]
    param
    (
    )

    # Write to log.
    Write-CustomLog -Message ("Getting device registration status") -Level Verbose;

    # Execute the dsregcmd command and store the output
    $dsRegCmdOutput = dsregcmd /status;

    # Create a new PSObject to store the parsed output
    $dsRegStatus = New-Object -TypeName PSObject;

    # Define the pattern for the Select-String cmdlet
    $pattern = ' *[A-z]+ : [A-z]+ *'

    # Parse the dsregcmd output
    $matchedLines = $dsRegCmdOutput | Select-String -Pattern $pattern;

    # Iterate over each matched line
    foreach ($line in $matchedLines)
    {
        # If line is empty, skip it
        if ([String]::IsNullOrEmpty($line))
        {
            continue;
        }

        # Split the line into name and value parts
        $parts = ([String]$line).Trim() -split ' : ';

        # Extract the name and value
        $name = $parts[0];
        $value = $parts[1];

        # Add the name and value as a property to the PSObject
        Add-Member -InputObject $dsRegStatus -MemberType NoteProperty -Name $name -Value $value;
    }

    # Return the status of the device registration
    return $dsRegStatus;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# If the computer is not domain joined.
if (-not (Test-DomainJoined))
{
    # Write to log.
    Write-CustomLog -Message ('The computer is not domain joined, exiting script') -Level Warning;

    # Exit script.
    exit;
}

# Write to log.
Write-CustomLog -Message ('Starting script') -Level Console;
Write-CustomLog -Message ('Gathering data') -Level Console;
Write-CustomLog -Message ('Searching for DNS zones in Active Directory' -f $dnsZones.Count) -Level Console -IndentLevel 1;

# Get all DNS zones.
$dnsZones = Get-DnsZone;

# Write to log.
Write-CustomLog -Message ('Found {0} DNS zones' -f $dnsZones.Count) -Level Console -IndentLevel 2;
Write-CustomLog -Message ('Searching for DNS records, this might take a while' -f $dnsZones.Count) -Level Console -IndentLevel 1;

# Object array to store all DNS records.
$dnsRecords = @();

# Foreach DNS zone.
foreach ($dnsZone in $dnsZones)
{
    # Get DNS records.
    $dnsRecords += Get-DnsRecord -DnsZone $dnsZone.DistinguishedName;
}

# Write to log.
Write-CustomLog -Message ('Found {0} DNS records' -f $dnsRecords.Count) -Level Console -IndentLevel 2;
Write-CustomLog -Message ('Enumerating data') -Level Console;
Write-CustomLog -Message ('Searching for orphaned PTR-records, this might take a while') -Level Console -IndentLevel 1;

# Get orphaned PTR records (no A record linked).
$orphanedPtrRecords = Get-DnsOrphanedPtrRecord -DnsRecord $dnsRecords;

# Write to log.
Write-CustomLog -Message ('Found {0} orphaned PTR DNS records (no A-record associated)' -f $orphanedPtrRecords.Count) -Level Console -IndentLevel 2;
Write-CustomLog -Message ('Searching for orphaned A-records, this might take a while') -Level Console -IndentLevel 1;

# Get orphaned A records (no PTR record linked).
$orphanedARecords = Get-DnsOrphanedARecord -DnsRecord $dnsRecords;

# Write to log.
Write-CustomLog -Message ('Found {0} orphaned A DNS records (no PTR-record associated)' -f $orphanedARecords.Count) -Level Console -IndentLevel 2;
Write-CustomLog -Message ('Exporting data') -Level Console;
Write-CustomLog -Message ("Exporting orphaned PTR DNS records to file '{0}'" -f $ExportPtrRecordFilePath) -Level Console -IndentLevel 1;
Write-CustomLog -Message ("Exporting orphaned PTR A records to file '{0}'" -f $ExportARecordFilePath) -Level Console -IndentLevel 1;

# Export to CSV file.
$null = $orphanedPtrRecords | Export-Csv -Path $ExportPtrRecordFilePath -NoTypeInformation -Encoding UTF8 -Delimiter ';' -Force;
$null = $orphanedARecords | Export-Csv -Path $ExportARecordFilePath -NoTypeInformation -Encoding UTF8 -Delimiter ';' -Force;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-CustomLog -Message ('Ending script') -Level Console;

############### Finalize - End ###############
#endregion
