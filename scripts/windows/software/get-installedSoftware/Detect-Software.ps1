#requires -version 3

<#
.SYNOPSIS
  Get software installed in Windows.
.DESCRIPTION
  Goes through the registries (machine & user), files and APPX packages to return a list.
.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  15-11-2021
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Clear screen.
#Clear-Host;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Package name.
$Name = "Sublime";

# Package version.
$Version = "";

# If the script is used for detection or requirement for Intune apps.
$IntnueMethod = "Detection";

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Write to the console.
Function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Text
    )
 
    # If the input is empty.
    If([string]::IsNullOrEmpty($Text))
    {
        $Text = " ";
    }
    Else
    {
        # Write to the console.
        Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
}

# Get installed software (x64).
Function Get-InstalledSoftware64Bit
{
    # Registry paths.
    $MachineRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";
    $UserRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";

    # Object array.
    $SoftwareInstalled = @();

    # If the process is 64-bit.
    If([Environment]::Is64BitProcess)
    {
        # Get registry keys for machine.
        $RegistryKeys = Get-ChildItem -Path $MachineRegistryPath;

        # Foreach registry key.
        Foreach($RegistryKey in $RegistryKeys)
        {
            # If the display name isnt empty.
            If($RegistryKey.GetValue("DisplayName"))
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $RegistryKey.GetValue("DisplayName");
                    Version = $RegistryKey.GetValue("DisplayVersion");
                    Architecture = "x64";
                    Scope = "machine";
                    Source = "registry";
                    Path = $RegistryKey;
                };
            }
        }

        # Get registry keys for user.
        $RegistryKeys = Get-ChildItem -Path $UserRegistryPath -ErrorAction SilentlyContinue;

        # Foreach registry key.
        Foreach($RegistryKey in $RegistryKeys)
        {
            # If the display name isnt empty.
            If($RegistryKey.GetValue("DisplayName"))
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $RegistryKey.GetValue("DisplayName");
                    Version = $RegistryKey.GetValue("DisplayVersion");
                    Architecture = "x64";
                    Scope = "user";
                    Source = "registry";
                    Path = $RegistryKey;
                };
            }
        }
    }

    # Return installed software.
    Return $SoftwareInstalled;
}

# Get installed software (x86).
Function Get-InstalledSoftware32Bit
{
    # Object array.
    $SoftwareInstalled = @();

    # If the process is 64-bit.
    If([Environment]::Is64BitProcess -eq $true)
    {
        $MachineRegistryPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall";
        $UserRegistryPath = "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall";

        # Get registry keys for machine.
        $RegistryKeys = Get-ChildItem -Path $MachineRegistryPath;

        # Foreach registry key.
        Foreach($RegistryKey in $RegistryKeys)
        {
            # If the display name isnt empty.
            If($RegistryKey.GetValue("DisplayName"))
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $RegistryKey.GetValue("DisplayName");
                    Version = $RegistryKey.GetValue("DisplayVersion");
                    Architecture = "x86";
                    Scope = "machine";
                    Source = "registry";
                    Path = $RegistryKey;
                };
            }
        }

        # Get registry keys for user.
        $RegistryKeys = Get-ChildItem -Path $UserRegistryPath -ErrorAction SilentlyContinue;

        # Foreach registry key.
        Foreach($RegistryKey in $RegistryKeys)
        {
            # If the display name isnt empty.
            If($RegistryKey.GetValue("DisplayName"))
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $RegistryKey.GetValue("DisplayName");
                    Version = $RegistryKey.GetValue("DisplayVersion");
                    Architecture = "x86";
                    Scope = "user";
                    Source = "registry";
                    Path = $RegistryKey;
                };
            }
        }
    }

    # If the process is 32-bit.
    If([Environment]::Is64BitProcess -eq $false)
    {
        $MachineRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";
        $UserRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";

        # Get registry keys for machine.
        $RegistryKeys = Get-ChildItem -Path $MachineRegistryPath;

        # Foreach registry key.
        Foreach($RegistryKey in $RegistryKeys)
        {
            # If the display name isnt empty.
            If($RegistryKey.GetValue("DisplayName"))
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $RegistryKey.GetValue("DisplayName");
                    Version = $RegistryKey.GetValue("DisplayVersion");
                    Architecture = "x86";
                    Scope = "machine";
                    Source = "registry";
                    Path = $RegistryKey;
                };
            }
        }

        # Get registry keys for user.
        $RegistryKeys = Get-ChildItem -Path $UserRegistryPath -ErrorAction SilentlyContinue;

        # Foreach registry key.
        Foreach($RegistryKey in $RegistryKeys)
        {
            # If the display name isnt empty.
            If($RegistryKey.GetValue("DisplayName"))
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $RegistryKey.GetValue("DisplayName");
                    Version = $RegistryKey.GetValue("DisplayVersion");
                    Architecture = "x86";
                    Scope = "user";
                    Source = "registry";
                    Path = $RegistryKey;
                };
            }
        }
    }

    # Return installed software.
    Return $SoftwareInstalled;
}

# Get installed software (AppX).
Function Get-InstalledSoftwareAppx
{
    # Object array.
    $SoftwareInstalled = @();

    # Get APPX packages
    $AppxPackages = Get-AppxPackage;

    # Foreach package.
    Foreach($AppxPackage in $AppxPackages)
    {
        # Add to object array.
        $SoftwareInstalled += [PSCustomObject]@{
            Name = $AppxPackage.Name;
            Version = $AppxPackage.Version;
            Architecture = $AppxPackage.Architecture;
            Scope = "user";
            Source = "Appx";
            Path = $AppxPackage.InstallLocation;
        };
    }

    # Return installed software.
    Return $SoftwareInstalled;
}

# Get installed software (64-bit) by searching in program files.
Function Get-InstalledSoftwareProgramFiles64bit
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Name
    )

    # Object array.
    $SoftwareInstalled = @();

    # If the process is 64-bit.
    If([Environment]::Is64BitProcess -eq $true)
    {
        # Search after files in 64-bit program files.
        $SearchResults = Get-ChildItem -Path $env:ProgramFiles -Filter ("*{0}*.exe" -f $Name) -Recurse -ErrorAction SilentlyContinue;

        # Foreach search result.
        Foreach($SearchResult in $SearchResults)
        {
            # If the display name isnt empty.
            If($SearchResult.VersionInfo.ProductName)
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $SearchResult.VersionInfo.ProductName;
                    Version = $SearchResult.VersionInfo.ProductVersion;
                    Architecture = "x64";
                    Scope = "machine";
                    Source = "Files";
                    Path = $SearchResult.FullName;
                };
            }
        }
    }

    # Return installed software.
    Return $SoftwareInstalled;
}

# Get installed software (32-bit) by searching in program files.
Function Get-InstalledSoftwareProgramFiles32bit
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Name
    )

    # Object array.
    $SoftwareInstalled = @();

    # If the process is 64-bit.
    If([Environment]::Is64BitProcess -eq $true)
    {
        # Search after files in 64-bit program files.
        $SearchResults = Get-ChildItem -Path ${env:ProgramFiles(x86)} -Filter ("*.exe") -Recurse -ErrorAction SilentlyContinue;

        # Foreach search result.
        Foreach($SearchResult in $SearchResults)
        {
            # If the display name isnt empty.
            If($SearchResult.VersionInfo.ProductName)
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $SearchResult.VersionInfo.ProductName;
                    Version = $SearchResult.VersionInfo.ProductVersion;
                    Architecture = "x86";
                    Scope = "machine";
                    Source = "Files";
                    Path = $SearchResult.FullName;
                };
            }
        }
    }

    # If the process is 32-bit.
    If([Environment]::Is64BitProcess -eq $false)
    {
        # Search after files in 64-bit program files.
        $SearchResults = Get-ChildItem -Path $env:ProgramFiles -Filter ("*.exe") -Recurse -ErrorAction SilentlyContinue;

        # Foreach search result.
        Foreach($SearchResult in $SearchResults)
        {
            # If the display name isnt empty.
            If($SearchResult.VersionInfo.ProductName)
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $SearchResult.VersionInfo.InternalName;
                    Version = $SearchResult.VersionInfo.ProductVersion;
                    Architecture = "x86";
                    Scope = "machine";
                    Source = "Files";
                    Path = $SearchResult.FullName;
                };
            }
        }
    }

    # Return installed software.
    Return $SoftwareInstalled;
}

# Get installed software by searching in app data.
Function Get-InstalledSoftwareAppData
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Name
    )

    # Object array.
    $SoftwareInstalled = @();

    # If the process is 64-bit.
    If([Environment]::Is64BitProcess -eq $true)
    {
        # Search after files in 64-bit program files.
        $SearchResults = Get-ChildItem -Path $env:APPDATA -Filter ("*.exe") -Recurse -ErrorAction SilentlyContinue;

        # Foreach search result.
        Foreach($SearchResult in $SearchResults)
        {
            # If the display name isnt empty.
            If($SearchResult.VersionInfo.ProductName)
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $SearchResult.VersionInfo.ProductName;
                    Version = $SearchResult.VersionInfo.ProductVersion;
                    Architecture = "x64";
                    Scope = "machine";
                    Source = "Files";
                    Path = $SearchResult.FullName;
                };
            }
        }
    }

    # Return installed software.
    Return $SoftwareInstalled;
}

# Get installed software by searching in console user hive.
Function Get-InstalledSoftwareLoggedConsoleUser
{
    # Object array.
    $SoftwareInstalled = @();

    # Get current logged console user.
    [string]$LoggedOnConsoleUser = ((Get-WMIObject -class Win32_ComputerSystem | Select-Object Username)[0].Username -Split "\\")[-1];

    # Get logged console user SID.
    [string]$LoggedOnConsoleUserSID = (Get-ItemProperty -Path  "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" | Where-Object {$_.ProfileImagePath -match $LoggedOnConsoleUser}).PSChildName;

    # Set user registry
    $RegistryPath = ('HKU:\{0}\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' -f $LoggedOnConsoleUserSID);

    # Remove HKU drive.
    Remove-PSDrive -Name "HKU" -Force -Confirm:$false  -ErrorAction SilentlyContinue;

    # Create new HKU drive.
    New-PSDrive -PSProvider Registry -Root HKEY_USERS -Name "HKU" -Confirm:$false;

    # Check if registry path exist.
    If(Test-Path -Path $RegistryPath)
    {
        # Get registry keys for machine.
        $RegistryKeys = Get-ChildItem -Path $RegistryPath;

        # Foreach registry key.
        Foreach($RegistryKey in $RegistryKeys)
        {
            # If the display name isnt empty.
            If($RegistryKey.GetValue("DisplayName"))
            {
                # Add to object array.
                $SoftwareInstalled += [PSCustomObject]@{
                    Name = $RegistryKey.GetValue("DisplayName");
                    Version = $RegistryKey.GetValue("DisplayVersion");
                    Architecture = "x64";
                    Scope = "machine";
                    Source = "registry";
                    Path = $RegistryKey;
                };
            }
        }
    }

    # Return installed software.
    Return $SoftwareInstalled;
}

# Check install version against criteria.
Function Check-InstalledSoftware
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)]$Version,
        [Parameter(Mandatory=$true)]$InstalledSoftware
    )

    # Set status.
    $Status = "N/A";

    # Check if software is installed already.
    If($Installed = $InstalledSoftware | Where-Object {$_.Name -like "*$($Name)*"} | Sort-Object -Property Version -Descending)
    {
        # If multiple entries exist.
        If($Installed.Count -gt 1)
        {
            # Check if exact version is installed
            $Installed = $Installed | Where-Object {$_.Version -eq $Version} | Select-Object -First 1;
        }

        # Convert version.
        If($Installed.Version)
        {
            # Convert to version type.
            $InstalledVersion = [System.Version]::Parse(($Installed.Version -replace "([^0-9])", "."));
        }
        Else
        {
            # No version.
            $InstalledVersion = "";
        }

        # If version is the same.
        If($InstalledVersion -eq $Version)
        {
            # Set status.
            $Status = "SameVersion";
        }
        # If the installed version is newer.
        ElseIf($InstalledVersion -gt $Version)
        {
            # Set status.
            $Status = "Downgrade";
        }
        # If the installed version is older.
        ElseIf($InstalledVersion -lt $Version)
        {
            # Set status.
            $Status = "Upgrade";
        }
        Else
        {
            # Set status.
            $Status = "N/A";
        }
    }
    Else
    {
        # Set status.
        $Status = "NotInstalled";
    }

    # Return
    Return $Status;
}

# Check if running as SYSTEM.
Function Check-SystemContext
{
    # Get current process.
    [Security.Principal.WindowsIdentity]$CurrentProcessToken = [Security.Principal.WindowsIdentity]::GetCurrent();
    [Security.Principal.SecurityIdentifier]$CurrentProcessSID = $CurrentProcessToken.User;

    # True or false if running in SYSTEM context.
    [boolean]$IsLocalSystemAccount = $CurrentProcessSID.IsWellKnown([Security.Principal.WellKnownSidType]'LocalSystemSid');

    # Return.
    Return $IsLocalSystemAccount;
}

#endregion

#region begin main
############### Main - Start ###############

# Get installed software.
$InstalledSoftware = @();
$InstalledSoftware += (Get-InstalledSoftware32Bit);
$InstalledSoftware += (Get-InstalledSoftware64Bit);
$InstalledSoftware += (Get-InstalledSoftwareAppx);
$InstalledSoftware += (Get-InstalledSoftwareProgramFiles64bit -Name $Name);
$InstalledSoftware += (Get-InstalledSoftwareProgramFiles32bit -Name $Name);
$InstalledSoftware += (Get-InstalledSoftwareAppData -Name $Name);

# If running in system context.
If(Check-SystemContext)
{
    # Add console user hive software.
    $InstalledSoftware += (Get-InstalledSoftwareLoggedConsoleUser);
}

# If version is set.
If($Version)
{
    # Convert to System.Version type.
    $Version = [System.Version]::Parse(($Version -replace "([^0-9])", "."));
}

# Chek installed software for criteria.
$Response = Check-InstalledSoftware -Name $Name -Version $Version -InstalledSoftware $InstalledSoftware;

# If installed.
If($Response -eq "SameVersion" -or $Response -eq "Downgrade")
{
    # Write to STDOUT.
    Write-Host ("{0}: Is already installed." -f $Name)

    # Exit.
    Return 0;
}
# If needs to be updated.
ElseIf($Response -eq "Upgrade")
{
    # If Intune method is "Requirement".
    If($IntnueMethod -eq "Requirement")
    {
        # Exit.
        Return $Response;
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
