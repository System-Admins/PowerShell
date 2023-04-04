# Cheat Sheet for PowerShell

This page shows a examples and simple commands that can help you on the way with PowerShell scripts and modules.


## Version

### Convert string to type System.Version

This converts an string like "1.0.0" into the type [System.Version] and converts all other chars to an dot.

```powershell
# Replace all other chars than numbers into a dot.
$Data = '4.3.0_3' -replace "([^0-9])", ".";

# Convert string to System.Version.
$Version = [System.Version]::Parse($Data);

# Print result.
$Version;

# Gives the following output.
Major  Minor  Build  Revision
-----  -----  -----  --------
4      3      0      3       
```



## Paths

### Get script path

This returns the executed script path. Takes into account if the scripts runs in PowerShell ISE IDE.

```powershell
# If script running in PowerSHell ISE.
If($psise)
{
    # Set script path.
    $ScriptPath = Split-Path $psise.CurrentFile.FullPath;
}
# Normal PowerShell session.
Else
{
    # Set script path.
    $ScriptPath = $global:PSScriptRoot;
}   
```

### Get desktop path

This returns the desktop path for the current user.

```powershell
[Environment]::GetFolderPath("Desktop");
```

## Network Policy Server (NPS)

### Get NPS log with headers

The following will convert an NPS log (C:\Windows\System32\LogFiles\\<filename>.log) into a readable table.

```powershell
$Log = Import-Csv -Path "C:\Windows\system32\LogFiles\<filename>.log" -Encoding UTF8 -Delimiter "," -Header "NPSServer","NPSService","Date","Hour","PacketType","ClientName","FQDNUserName","CallerIDStationTo","CallerIDStationFrom","CallBackNumber","FramedIP","NASSource","NASIPSource","NASPortSource","NASVendor","RadiusClientIP","RadiusClientName","TimestampEvent","NASPortLimit","NASPortType","ConnectInfo","Protocol","TypeUserOfService","AuthenticationType","NPSPolicyName","ReasonCode","Class","SessionTimeout","IdleTimeout","TerminationAction","EAPName","AcctStatusType","AcctDelayTime","AcctInputOctets","AcctOutputOctets","AcctSessionID","AcctAuth","AcctSessionTime","AcctInputPackets","AcctOutputPackets","AcctTerminateCause","AcctMultiSsnID","AcctLinkCount","AcctInterimInterval","TunnelType","TunnelMediumType","TunnelClientIP","TunnelServerIP","TunnelIdentifier","TunnelGroupID","TunnelAssignementID","TunnelPreference","MSAcctAuthType","MSAcctEAPType","MSRASVersion","MSRASVendor","MSCHAPError","MSCHAPDomain","MSMPPEEncryptionTypes","MSMPPEEncryptionPolicy","ProxyPolicyName","ProviderType","ProviderName","RemoteRadiusAuthenticationIP","MSRASClientName","MSRASClientVersion";
```



## Objects

### Print each object property with value to screen

The following prints out every PowerShell object property with the corresponding value to screen.

```powershell
# Foreach property.
Foreach($Property in $TheObject | Get-Member)
{
    # Get only properties.
    If ($Property.MemberType -eq "Property" -or $Property.MemberType -eq "NoteProperty" -and $Property.Name -notlike "__*")
    {
        # Print out key and value.
        "'{0}' => '{1}'" -f $Property.Name, $TheObject.$($Property.Name);
    }
}
```



## Processor

### Check if process is 32 or 64-bit

Return 32 or 64 depending on the running process arcitechture.

```powershell
# Get if process is x86 or x64.
Function Get-ProcessArchType
{
    if([IntPtr]::Size -eq 4)
    {
        # Return x86.
        return 32;
    }
    else
    {
        # Return x64.
        return 64;
    }
}

# Get processor architecture.
Get-ProcessArchType;
```



## File Handling

### Find and replace text in a file

The following loads a file and finds a specific text and replaces it.

```powershell
# Function to replace text in a file.
Function Replace-TextInFile
{
    [cmdletbinding()]
    
    Param
    (
        [string]$FilePath,
        [string]$Find,
        [string]$Replace
    )

    # Read file and replace content.
    $Content = [System.IO.File]::ReadAllText($FilePath).Replace($Find,$Replace);
    [System.IO.File]::WriteAllText($FilePath, $Content);
} 
```

## Session

### Check if current session is interactive

Check if the process is running in interactive (by user) or non-interactive (ex. a schedule task) mode.

```powershell
# Function to check if process is interactive.
Function Test-InteractiveSession
{
    # Test each argument for match of abbreviated '-NonInteractive' command.
    $NonInteractive = [Environment]::GetCommandLineArgs() | Where-Object{ $_ -like '-NonInteractive' };

    # If environment is interactive and the argument -NonInteractive is not set.
    If(([Environment]::UserInteractive) -and (-not $NonInteractive))
    {
        # Return false.
        Return $false;
    }
    # Else if the session is non-interactive.
    Else
    {
        # Return true.
        Return $true;
    }
}
```

## Network

### Get subnet information from IP-address CIDR

Get subnet mask, start/end IP and network ID from IP-address CIDR.

```powershell
# Get IP range from CIDR.
function Get-IpRangeFromCidr
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)][ValidatePattern('^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$')][string]$CIDR
    )

    # Split IP and subnet.
    $IP = ($CIDR -split '\/')[0];

    # Get subnet bits.
    [int]$SubnetBits = ($CIDR -split '\/')[1];

    # If subnet bits is less than 7 or higher than 30.
    if ($SubnetBits -lt 7 -or $SubnetBits -gt 30)
    {
        # Throw execption.
        throw ('The number following the / must be between 7 and 30');
    }

    # Split IP into different octects and for each one, figure out the binary with leading zeros and add to the total.
    $Octets = $IP -split '\.';

    # Create array for IP.
    $IPInBinary = @();

    # Foreach octet.
    foreach ($Octet in $Octets)
    {
        # Convert to binary.
        $OctetInBinary = [convert]::ToString($Octet, 2);

        # Get length of binary string add leading zeros to make octet.
        $OctetInBinary = ('0' * (8 - ($OctetInBinary).Length) + $OctetInBinary);

        # Add to array .
        $IPInBinary = $IPInBinary + $OctetInBinary;
    }

    # Join binary IP.
    $IPInBinary = $IPInBinary -join '';

    # Get network ID by subtracting subnet mask;
    $HostBits = 32 - $SubnetBits;

    # Get network ID in binary format.
    $NetworkIDInBinary = $IPInBinary.Substring(0, $SubnetBits);

    # Get host ID and get the first host ID by converting all 1s into 0s.
    $HostIDInBinary = $IPInBinary.Substring($SubnetBits, $HostBits);
    $HostIDInBinary = $HostIDInBinary -replace '1', '0';

    # Work out all the host IDs in that subnet by cycling through $i from 1 up to max $HostIDInBinary (i.e. 1s stringed up to $HostBits).
    $imax = [convert]::ToInt32(('1' * $HostBits), 2) - 1;

    # Create array for all IP in subnet.
    $IPs = @();
    
    # Next ID is first network ID converted to decimal plus $i then converted to binary.
    for ($i = 1 ; $i -le $imax ; $i++)
    {
        # Convert to decimal and add $i.
        $NextHostIDInDecimal = ([convert]::ToInt32($HostIDInBinary, 2) + $i);

        # Convert back to binary.
        $NextHostIDInBinary = [convert]::ToString($NextHostIDInDecimal, 2);

        # Number of zeros to add.
        $NoOfZerosToAdd = $HostIDInBinary.Length - $NextHostIDInBinary.Length;
        $NextHostIDInBinary = ('0' * $NoOfZerosToAdd) + $NextHostIDInBinary;

        # Work out next IP.
        $NextIPInBinary = $NetworkIDInBinary + $NextHostIDInBinary;

        # Array for the single IP in subnet.
        $IP = @();

        # Split into octets and separate by "." then join.
        for ($x = 1 ; $x -le 4 ; $x++)
        {
            # Work out start character position.
            $StartCharNumber = ($x - 1) * 8;

            # Get octet in binary.
            $IPOctetInBinary = $NextIPInBinary.Substring($StartCharNumber, 8);

            # Convert octet into decimal.
            $IPOctetInDecimal = [convert]::ToInt32($IPOctetInBinary, 2);

            # Add octet to IP
            $IP += $IPOctetInDecimal;
        }

        # Separate by "."
        $IP = $IP -join '.';

        # Add single IP to array.
        $IPs += $IP;
    }

    # Parse IP address.
    $ParsedIpAddress = [System.Net.IPAddress]::Parse(($CIDR -split '\/')[0]);

    # Shit CIDR.
    $Shift = 64 - ($CIDR -split '\/')[1];
    
    # Create empty subnet.
    [System.Net.IpAddress]$Subnet = 0;

    # If CIDR is not zero.
    if (($CIDR -split '\/') -ne 0)
    {
        # Parse shift to subnet.
        $Subnet = [System.Net.IpAddress]::HostToNetworkOrder([int64]::MaxValue -shl $Shift);
    }

    # Get subnet info.
    [System.Net.IpAddress]$Network = $ParsedIpAddress.Address -band $Subnet.Address;

    # Create object.
    $Result = [PSCustomObject]@{
        IpAddressCidr = $CIDR;
        StartIp = $IPs[0];
        EndIp = $IPs[-1];
        NetworkId = $Network;
        SubnetMask = $Subnet;
        IpAvailable = $IPs;
        HostAvailable = $IPs.count;
    };

    # Return result.
    return $Result;
}
```
