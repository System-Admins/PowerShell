# Cheat Sheet for PowerShell

This page shows a examples and simple commands that can help you on the way with PowerShell scripts and modules.



**Table of content**:

[TOC]

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

