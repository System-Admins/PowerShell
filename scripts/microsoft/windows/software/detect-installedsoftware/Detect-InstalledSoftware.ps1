#requires -version 5.1

<#
.SYNOPSIS
  Get software installed on the PC.

.DESCRIPTION
  Goes through the registries (machine & user), files and APPX packages and tries to find software based on parameter input.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  14-07-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]

Param
(
    # Package id.
    [Parameter(Mandatory=$true)][string]$Name = "Microsoft Teams",

    # Version.
    [Parameter(Mandatory=$true)][string]$Version = "1.5.00.17656",

    # Method detection or requirement.
    [Parameter(Mandatory=$false)][ValidateSet("Detection", "Requirement")][string]$Method = "Detection"
)

# Clear screen.
#Clear-Host;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

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
            # If exact match is found.
            $Installed = $InstalledSoftware | Where-Object {$_.Name -like "$($Name)"} | Sort-Object -Property Version -Descending;
            
            # If multiple entries exist.
            If($Installed.Count -gt 1)
            {
                # Check if exact version is installed
                $Installed = $Installed | Where-Object {$_.Version -eq $Version} | Select-Object -First 1;
            }
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
    Return [PSCustomObject]@{
        InstalledApp = $Installed;
        Status = $Status;
    };
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

# Get latest version if multiple versions are installed of the same software.
Function Get-LatestInstalledSoftware
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$InstalledSoftware
    )
 
    # Object array.
    $Results = @();

    # Foreach installed software.
    Foreach($Software in $InstalledSoftware)
    {
        # If software is already in the list.
        If($Result = $Results | Where-Object {$_.Name -eq $Software.Name})
        {
            # If software version is lower.
            If($Result.Version -lt $Software.Version)
            {
                # Update software version.
                $Result.Version = $Software.Version;
            }
        }
        # Else software is not in the list.
        Else
        {
            # Add to list.
            $Results += $Software;
        }
    }

    # Return results.
    Return $Results;
}

# Detect installed software.
Function Detect-InstalledSoftware
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Version,
        [Parameter(Mandatory=$true)][string]$Method
    )

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

    # Get latest version if multiple versions are installed of the same software.
    $InstalledSoftware = Get-LatestInstalledSoftware -InstalledSoftware $InstalledSoftware;

    # If version is set.
    If(!([string]::IsNullOrEmpty($Version)))
    {
        # Convert to System.Version type.
        $Version = [System.Version]::Parse(($Version -replace "([^0-9])", "."));
    }

    # Chek installed software for criteria.
    $Response = Check-InstalledSoftware -Name $Name -Version $Version -InstalledSoftware $InstalledSoftware;

    # If installed.
    If($Response.Status -eq "SameVersion")
    {
        # If Intune method is "Detection".
        If($Method -eq "Detection")
        {
            # Write to STDOUT.
            Write-Host ("[{0}][{1}]: Already installed" -f $Name, $Version)

            # Exit.
            Exit 0;
        }
    }
    # Else if newer version is installed.
    ElseIf($Response.Status -eq "Downgrade")
    {
        # If Intune method is "Detection".
        If($Method -eq "Detection")
        {
            # Write to STDOUT.
            Write-Host ("[{0}][{1}]: Downgrade required, installed version is newer {2}" -f $Name, $Version, $Response.InstalledApp.Version)

            # Exit.
            Exit 0;
        }
    }
    # Else if needs to be updated.
    ElseIf($Response.Status -eq "Upgrade")
    {
        # If Intune method is "Requirement".
        If($Method -eq "Requirement")
        {
            # Return "Upgrade".
            Return $Response.Status;
        }
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Detect installed software.
Detect-InstalledSoftware -Name $Name -Version $Version -Method $Method;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
