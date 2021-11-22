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
$Name = "Typora";

# Package version.
$Version = "0.11.17";

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

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get installed software.
$InstalledSoftware = @();
$InstalledSoftware += (Get-InstalledSoftware32Bit);
$InstalledSoftware += (Get-InstalledSoftware64Bit);
$InstalledSoftware += (Get-InstalledSoftwareAppx);
$InstalledSoftware += (Get-InstalledSoftwareProgramFiles64bit);
$InstalledSoftware += (Get-InstalledSoftwareProgramFiles32bit);
$InstalledSoftware += (Get-InstalledSoftwareAppData);

# Return results.
Return $InstalledSoftware;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
