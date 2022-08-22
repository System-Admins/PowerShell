#requires -version 5.1

<#
.SYNOPSIS
  Customize the taskbar in Windows 11.
    
.DESCRIPTION
  Remove/add icons from the taskbar.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  18-08-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]	
		
Param
(
    [Parameter(Mandatory=$false)][bool]$ShowTaskbarSearchIcon = $false,
    [Parameter(Mandatory=$false)][bool]$ShowTaskbarTaskviewIcon = $false,
    [Parameter(Mandatory=$false)][bool]$ShowTaskbarWidgetsIcon = $false,
    [Parameter(Mandatory=$false)][bool]$ShowTaskbarChatIcon = $false
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
        [Parameter(Mandatory=$false)][string]$Text,
        [Parameter(Mandatory=$false)][switch]$NoDateTime
    )
 
    # If the input is empty.
    If([string]::IsNullOrEmpty($Text))
    {
        $Text = " ";
    }
    # No date time.
    ElseIf($NoDateTime)
    {
        Write-Host $Text;
    }
    Else
    {
        # Write to the console.
        Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
}

# Enable or disable search icon in taskbar.
Function Set-TaskbarSearchIcon
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][bool]$Enable
    )

    # If true.
    If($Enable)
    {
        # Write to log.
        Write-Log ("Enable search icon in taskbar");

        # Set value.
        $Value = 1;
    }
    # Else false.
    Else
    {
        # Write to log.
        Write-Log ("Disable search icon in taskbar");

        # Set value.
        $Value = 0;
    }

    # Set registry value.
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchBoxTaskbarMode' -PropertyType 'DWORD' -Value $Value -Force | Out-Null;
}

# Enable or disable task view icon in taskbar.
Function Set-TaskbarTaskviewIcon
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][bool]$Enable
    )

    # If true.
    If($Enable)
    {
        # Write to log.
        Write-Log ("Enable task view icon in taskbar");

        # Set value.
        $Value = 1;
    }
    # Else false.
    Else
    {
        # Write to log.
        Write-Log ("Disable task view icon in taskbar");

        # Set value.
        $Value = 0;
    }

    # Set registry value.
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -PropertyType 'DWORD' -Value $Value -Force | Out-Null;
}

# Enable or disable widgets icon in taskbar.
Function Set-TaskbarWidgetsIcon
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][bool]$Enable
    )

    # If true.
    If($Enable)
    {
        # Write to log.
        Write-Log ("Enable widgets icon in taskbar");

        # Set value.
        $Value = 1;
    }
    # Else false.
    Else
    {
        # Write to log.
        Write-Log ("Disable widgets icon in taskbar");

        # Set value.
        $Value = 0;
    }

    # Set registry value.
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -PropertyType 'DWORD' -Value $Value -Force | Out-Null;
}

# Enable or disable chat icon in taskbar.
Function Set-TaskbarChatIcon
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][bool]$Enable
    )

    # If true.
    If($Enable)
    {
        # Write to log.
        Write-Log ("Enable chat icon in taskbar");

        # Set value.
        $Value = 1;
    }
    # Else false.
    Else
    {
        # Write to log.
        Write-Log ("Disable chat icon in taskbar");

        # Set value.
        $Value = 0;
    }

    # Set registry value.
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -PropertyType 'DWORD' -Value $Value -Force | Out-Null;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Enable or disable search icon in taskbar.
Set-TaskbarSearchIcon -Enable $ShowTaskbarSearchIcon;

# Enable or disable task view icon in taskbar.
Set-TaskbarTaskviewIcon -Enable $ShowTaskbarTaskviewIcon;

# Enable or disable widgets icon in taskbar.
Set-TaskbarWidgetsIcon -Enable $ShowTaskbarWidgetsIcon;

# Enable or disable chat icon in taskbar.
Set-TaskbarChatIcon -Enable $ShowTaskbarChatIcon;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion