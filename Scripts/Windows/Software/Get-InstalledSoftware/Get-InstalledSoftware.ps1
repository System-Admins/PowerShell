#requires -version 3

<#
.SYNOPSIS
  Get software installed in Windows.

.DESCRIPTION
  Goes through the registries (machine & user) and APPX packages to return a list.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  15-11-2021
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Clear screen.
Clear-Host;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############



############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Get installed software through registry and APPX.
Function Get-InstalledSoftware
{
    # Registry paths.
    $MachineRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";
    $UserRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";
    $MachineRegistryPath32Bit = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall";
    $UserRegistryPath32Bit = "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall";

    # Object array.
    $SoftwareInstalled = @();

    # If the process is 64-bit.
    If([Environment]::Is64BitProcess)
    {
        # Set architecture.
        $Architecture = "x64";

        # Get registry keys.
        $RegistryKeys = Get-ChildItem -Path $MachineRegistryPath32Bit;

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
                };
            }
        }

        # Get registry keys.
        $RegistryKeys = Get-ChildItem -Path $UserRegistryPath32Bit -ErrorAction SilentlyContinue;

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
                };
            }
        }
    }
    Else
    {
        # Set architecture.
        $Architecture = "x86";
    }

    # Get registry keys.
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
                Architecture = $Architecture;
                Scope = "machine";
            };
        }
    }    
    
    # Get registry keys.
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
                Architecture = $Architecture;
                Scope = "user";
            };
        }
    }

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
        };
    }

    # Return results.
    Return $SoftwareInstalled;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Return all installed software.
$InstalledSoftware = Get-InstalledSoftware;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
