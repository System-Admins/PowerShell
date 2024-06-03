#Requires -Version 5.1;

<#
.SYNOPSIS
  This script will get all DNS records in the domain and export them to a CSV file.

.DESCRIPTION
  Search for all DNS records in the domain and export them to a CSV file.

.Parameter OutputFilePath
  (Optional) Path to output file. Default will create a CSV on the user desktop.

.Example
  .\Export-AdDnsRecords.ps1 -OutputFilePath "C:\Temp\dnsRecords.csv";

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  03-06-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

Param
(
    # Path to output file.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf -IsValid })]
    [string]$OutputFilePath = ('{0}\{1}_dnsRecords.csv' -f ([Environment]::GetFolderPath('Desktop')), (Get-Date).ToString('yyyyMMdd'))
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

function Write-Console
{
    <#
    .SYNOPSIS
        Write to the console (host) with different levels.
    .DESCRIPTION
        Write to console using [+] and [-] different levels with colour.
    .PARAMETER Message
        Message to write to the console.
    .PARAMETER IndentLevel
        (Optional) Indent level.
    .PARAMETER Color
        (Optional) Color of the message.
    .EXAMPLE
        Write-Console -Message 'This is a message' -IndentLevel 2 -Color 'Green';
    #>
    [cmdletbinding()]
    param
    (

        # Message to write to log.
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        # Indent level.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]$IndentLevel = 0,

        # Color.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Green', 'Red', 'Yellow', 'White')]
        [string]$Color = 'White'
    )

    BEGIN
    {
        # Prefix meessage.
        [string]$prefixMessage = '';
    }
    PROCESS
    {
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
    }
    END
    {
        # Write to console.
        Write-Host -Object $prefixMessage -NoNewline;
        Write-Host -Object $Message -ForegroundColor $Color;
    }
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
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level Error -NoConsole
    .EXAMPLE
        # Write an information message to a log file but not to the console and do not append to the log file.
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level 'Information' -NoConsole -NoAppend
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
        [ValidateSet('Error', 'Warning', 'Information', 'Debug', 'Verbose')]
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

    # Record data.
    [PSCustomObject]$dnsObject = New-Object -TypeName PSCustomObject;

    # Add properties to the object.
    $dnsObject | Add-Member -MemberType NoteProperty -Name 'DistinguishedName' -Value $DistinguishedName;
    $dnsObject | Add-Member -MemberType NoteProperty -Name 'Name' -Value $recordName;
    $dnsObject | Add-Member -MemberType NoteProperty -Name 'TTL' -Value $recordTtl;
    $dnsObject | Add-Member -MemberType NoteProperty -Name 'Timestamp' -Value $timestamp;

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

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to console.
Write-Console -Message ("Starting script at '{0}'" -f (Get-Date).ToString('dd-MM-yyyy HH:mm:ss'));

# Get all DNS zones.
$dnsZones = Get-DnsZone;

# Write to console.
Write-Console -Message ('Found {0} zones in the Active Directory' -f $dnsZones.Count) -IndentLevel 0;

# Object array to store all DNS records.
$dnsRecordsResult = @();

# Foreach DNS zone.
foreach ($dnsZone in $dnsZones)
{
    # Get all DNS records in the zone.
    $dnsRecords = Get-DnsRecord -DnsZone $dnsZone.DistinguishedName;

    # Write to console.
    Write-Console -Message ("Found {0} DNS records from the zone '{1}'" -f @($dnsRecords).Count, $dnsZone.Name) -IndentLevel 1;

    # Add to result.
    $dnsRecordsResult += ($dnsRecords);
}

# Write to console.
Write-Console -Message ('Total DNS records is {0}' -f @($dnsRecordsResult).Count);

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to console.
Write-Console -Message ("Exporting results to '{0}'" -f $OutputFilePath);

# Export to CSV.
$null = New-Item -Path ([System.IO.Path]::GetDirectoryName($OutputFilePath)) -ItemType Directory -Force;
$dnsRecordsResult | Export-Csv -Path $OutputFilePath -Encoding UTF8 -Delimiter ';' -Force -NoTypeInformation;

# Write to console.
Write-Console -Message ("Finished script at '{0}'" -f (Get-Date).ToString('dd-MM-yyyy HH:mm:ss'));

############### Finalize - End ###############
#endregion
