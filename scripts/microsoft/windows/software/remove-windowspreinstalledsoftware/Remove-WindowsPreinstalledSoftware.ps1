#requires -version 5.1

<#
.SYNOPSIS
  Removes blotware packages from Windows such as Disney, Minecraft, Facebook and much more.
  Run this script as administrator for better experience.
    
.DESCRIPTION
  Uninstall AppX packages, removes registry and scheduled tasks associated.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  18-08-2022
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

# AppX packages to uninstall.
$AppxPackages = @(
    "Microsoft.BingNews",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.Messaging",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.NetworkSpeedTest",
    "Microsoft.MixedReality.Portal",
    "Microsoft.News",
    "Microsoft.Office.Lens",
    "Microsoft.Office.OneNote",
    "Microsoft.Office.Sway",
    "Microsoft.OneConnect",
    "Microsoft.People",
    "Microsoft.Print3D",
    "Microsoft.RemoteDesktop",
    "Microsoft.SkypeApp",
    "Microsoft.StorePurchaseApp",
    "Microsoft.Office.Todo.List",
    "Microsoft.Whiteboard",
    "Microsoft.WindowsAlarms",
    "microsoft.windowscommunicationsapps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxGameCallableUI,"
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "MicrosoftTeams",
    "Microsoft.YourPhone",
    "Microsoft.XboxGamingOverlay_5.721.10202.0_neutral_~_8wekyb3d8bbwe",
    "Microsoft.GamingApp",
    "Microsoft.MicrosoftStickyNotes"
    "SpotifyAB.SpotifyMusic",
    "Disney.37853FC22B2CE",
    "*EclipseManager*",
    "*ActiproSoftwareLLC*",
    "*AdobeSystemsIncorporated.AdobePhotoshopExpress*",
    "*Duolingo-LearnLanguagesforFree*",
    "*PandoraMediaInc*",
    "*CandyCrush*",
    "*BubbleWitch3Saga*",
    "*Wunderlist*",
    "*Flipboard*",
    "*Twitter*",
    "*Facebook*",
    "*Spotify*",
    "*Minecraft*",
    "*Royal Revolt*",
    "*Sway*",
    "*Speed Test*",
    "*Dolby*",
    "*Office*",
    "*Disney*",
    "*getstarted*"
    "Microsoft.549981C3F5F10",
    "Microsoft.Todos"
);

# Registry to remove.
$Registries = @(
    "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y",
    "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0",
    "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.MicrosoftOfficeHub_17.7909.7600.0_x64__8wekyb3d8bbwe",
    "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy",
    "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy",
    "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy",
    "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y",
    "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0",
    "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy",
    "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy",
    "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy",
    "HKCR:\Extensions\ContractId\Windows.PreInstalledConfigTask\PackageId\Microsoft.MicrosoftOfficeHub_17.7909.7600.0_x64__8wekyb3d8bbwe",
    "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0",
    "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy",
    "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy",
    "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy",
    "HKCR:\Extensions\ContractId\Windows.ShareTarget\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
);

# Schedule tasks to disable.
$ScheduleTasks = @(
    "XblGameSaveTaskLogon",
    "XblGameSaveTask",
    "Consolidator",
    "UsbCeip",
    "DmClient",
    "DmClientOnScenarioDownload"
);

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

# Get if running context is administrator.
Function Get-IsAdministrator
{
    # Get username.
    $Username = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).Identity.Name;

    # If context have the administrator role.
    If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator'))
    {        
        # Set global variable.
        $Global:IsAdministrator = $false;

        # Return false.
        Return $false;
        
    }
    # Else not an administrator.
    Else
    {
        # Set global variable.
        $Global:IsAdministrator = $true;
        
        # Return true.
        Return $true;
    }
}

# Remove bloatware (AppX packages).
Function Remove-BloatAppxPackages
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string[]]$AppxPackages
    )

    # Counter.
    $AppxPackagesCount = $AppxPackages.Count;
    $AppxPackagesCounter = 0;

    # If the running context is admin.
    If(Get-IsAdministrator)
    {
            # Get information about app packages (.appx) in an image that are set to install for each new user.
            $AppxProvisionedPackages = Get-AppxProvisionedPackage -Online;
    }

    # Foreach package to uninstall.
    Foreach($AppxPackage in $AppxPackages)
    {
        # Add to counter.
        $AppxPackagesCounter++;

        # Write to log.
        Write-Log -NoDateTime -Text (" ");
        Write-Log ("Enumerating app '{2}' ({0}/{1}):" -f $AppxPackagesCounter, $AppxPackagesCount, ($AppxPackage -replace "\*",""));
        Write-Log ("Searching after '{0}' package on the system" -f $AppxPackage);

        # If the running context is admin.
        If(Get-IsAdministrator)
        {
            # Get all packages package matching for all users.
            $InstalledPackages = Get-AppxPackage -AllUsers -Name $AppxPackage -ErrorAction SilentlyContinue;
        }
        # Else running context is not admin.
        Else
        {
            # If the package is found.
            $InstalledPackages = Get-AppxPackage -Name $AppxPackage -ErrorAction SilentlyContinue;   
        }

        # Write to log.
        Write-Log ("Found {0} that matches '{1}' package" -f $InstalledPackages.Count, $AppxPackage);

        # Foreach installed package.
        Foreach($InstalledPackage in $InstalledPackages)
        {
            # Write to log.
            Write-Log ("Trying to remove installed package '{0}'" -f $InstalledPackage.Name);

            # Try to remove.
            Try
            {
                # If the running context is admin.
                If(Get-IsAdministrator)
                {
                    # Remove provisioned package.
                    Remove-AppxPackage -Package $InstalledPackage.PackageFullName -AllUsers -ErrorAction Stop;
                }
                # Else running context is not admin.
                Else
                {
                    # If the app is controlled by system.
                    If($InstalledPackage.SignatureKind -eq 'System')
                    {
                        # Write to log.
                        Write-Log ("Package '{0}' is controlled by system, skipping" -f $InstalledPackage.Name);
                    }
                    # Else not controlled by system.
                    Else
                    {
                        # Remove provisioned package.
                        Remove-AppxPackage -Package $InstalledPackage.PackageFullName -ErrorAction Stop;
                    }
                }

                 # Write to log.
                Write-Log ("Removed installed package '{0}'" -f $InstalledPackage.Name);
            }
            # Something went wrong while removing.
            Catch
            {
                # Write to log.
                Write-Log ("Something went wrong while removing installed package '{0}', here is the error" -f $InstalledPackage.Name);
                #Write-Log -NoDateTime -Text ($Error[0]);
            }
        }
    }

    # If the running context is admin.
    If(Get-IsAdministrator)
    {
        # Search after package.
        $ProvisionedPackages = $AppxProvisionedPackages | Where-Object {$_.DisplayName -like $AppxPackage};
            
        # Write to log.
        Write-Log ("Found {0} that matches '{1}' provisioned package" -f $ProvisionedPackages.Count, $AppxPackage);

        # If packaged is found.
        If($ProvisionedPackages)
        {
            # Foreach provisioned package.
            Foreach($ProvisionedPackage in $ProvisionedPackages)
            {
                # Write to log.
                Write-Log ("Found {0} provisioned packages that matches '{1}'" -f $AppxProvisionedPackages.Count, $AppxPackage);

                # Foreach package that is provisioned for each user on the device.
                Foreach($AppxProvisionedPackage in $AppxProvisionedPackages)
                {
                    # Write to log.
                    Write-Log ("Trying to remove provisioned package '{0}'" -f $AppxProvisionedPackage.PackageName);

                    # Try to remove.
                    Try
                    {
                        # Remove provisioned package.
                        Remove-AppxProvisionedPackage -Online -PackageName $AppxProvisionedPackage.PackageName -ErrorAction Stop | Out-Null;
                    
                        # Write to log.
                        Write-Log ("Removed provisioned package '{0}'" -f $AppxProvisionedPackage.PackageName);   
                    }
                    # Something went wrong while removing.
                    Catch
                    {
                        # Write to log.
                        Write-Log ("Something went wrong while removing provisioned package '{0}', here is the error" -f $AppxProvisionedPackage.PackageName);
                    }
                }
            }
                
        }
    }
}

# Remove bloatware (registry).
Function Remove-BloatRegistry
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string[]]$Registries
    )

    # If HKCR already exist.
    If(Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)
    {
        # Remove PS drive.
        Remove-PSDrive -Name HKCR -Force;
    }

    # Create HKCR as a PSDrive.
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null;

    # Counter.
    $AppxRegistriesCount = $AppxRegistries.Count;
    $AppxRegistriesCounter = 0;

    # Foreach registry.
    Foreach($AppxRegistry in $AppxRegistries)
    {
        # Add to counter.
        $AppxRegistriesCounter++;

        # Write to log.
        Write-Log -NoDateTime -Text (" ");
        Write-Log ("Enumerating registry ({0}/{1}):" -f $AppxRegistriesCounter, $AppxRegistriesCount);
        Write-Log ("Path is '{0}'" -f $AppxRegistry);

        # If path exist.
        If(Test-Path -Path $AppxRegistry)
        {
            # If path is registry.
            If((Get-Item -Path $AppxRegistry).PSProvider.Name -eq 'Registry')
            {
                # Write to log.
                Write-Log ("Found registry path '{0}'" -f $AppxRegistry);

                # If context is not admin.
                If(Get-IsAdministrator -eq $false)
                {
                    # If registry path is in restricted area.
                    If($AppxRegistry.StartsWith("HKCR:") -or $AppxRegistry.StartsWith("HKLM:"))
                    {
                        # Write to log.
                        Write-Log ("Cant delete path '{0}', administrator permissions is needed" -f $AppxRegistry);
                    }
                    # Else not in restricted area.
                    {
                        # Try to remove.
                        Try
                        {
                            # Remove provisioned package.
                            Remove-Item -Path $AppxRegistry -Recurse -Force;
                    
                            # Write to log.
                            Write-Log ("Removed registry path '{0}'" -f $AppxRegistry);   
                        }
                        # Something went wrong while removing.
                        Catch
                        {
                            # Write to log.
                            Write-Log ("Something went wrong while removing registry path '{0}', here is the error" -f $AppxRegistry);
                            Write-Log -NoDateTime -Text ($Error[0]);
                        }
                    }
                }
                # Else context is admin.
                Else
                {
                    # Try to remove.
                    Try
                    {
                        # Remove provisioned package.
                        Remove-Item -Path $AppxRegistry -Recurse -Force;
                    
                        # Write to log.
                        Write-Log ("Removed registry path '{0}'" -f $AppxRegistry);   
                    }
                    # Something went wrong while removing.
                    Catch
                    {
                        # Write to log.
                        Write-Log ("Something went wrong while removing registry path '{0}', here is the error" -f $AppxRegistry);
                        Write-Log -NoDateTime -Text ($Error[0]);
                    }
                }
            }
            # Else path is not registry.
            Else
            {
                # Write to log.
                Write-Log ("Path '{0}' is not a valid registry location" -f $AppxRegistry);
            }
        }
        # Else path dont exist.
        Else
        {
            # Write to log.
            Write-Log ("Registry path '{0}' dont exist (or no permission)" -f $AppxRegistry);
        }
    }
}

# Disable bloatware (schedule tasks).
Function Disable-BloatScheduleTasks
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string[]]$Names
    )

    # If context is not admin.
    If(Get-IsAdministrator)
    {
        # Counter.
        $ScheduleTasksCount = $Names.Count;
        $ScheduleTasksCounter = 0;

        # Foreach schedule tasks.
        Foreach($Name in $Names)
        {
            # Add to counter.
            $ScheduleTasksCounter++;

            # Write to log.
            Write-Log -NoDateTime -Text (" ");
            Write-Log ("Enumerating schedule tasks ({0}/{1}):" -f $ScheduleTasksCounter, $ScheduleTasksCount);
            Write-Log ("Searching after schedule task '{0}'" -f $Name);

            # If schedule task exist.
            If($ScheduledTasks = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue)
            {
                # Write to log.
                Write-Log ("Found schedule task with the name '{0}'" -f $Name);

                # Foreach task.
                Foreach($ScheduledTask in $ScheduledTasks)
                {
                    # Try to disable schedule.
                    Try
                    {
                        # If not disabled.
                        If($ScheduledTask.State -ne "Disabled")
                        {
                            # Write to log.
                            Write-Log ("Trying to disable schedule task '{0}'" -f $ScheduledTask.TaskName);

                            # Disable schedule task.
                            $ScheduledTask | Disable-ScheduledTask -ErrorAction Stop | Out-Null;

                            # Write to log.
                            Write-Log ("Disabled schedule task '{0}'" -f $ScheduledTask.TaskName);
                        }
                        # Else already disabled.
                        Else
                        {
                            # Write to log.
                            Write-Log ("TSchedule task '{0}' already disabled" -f $ScheduledTask.TaskName);
                        }
                    }
                    # Something went wrong disabling schedule task.
                    Catch
                    {
                        # Write to log.
                        Write-Log ("Something went wrong while disabling schedule task '{0}', here is the error" -f $Name);
                        Write-Log -NoDateTime -Text ($Error[0]);
                    }
                }
            }
            # Else didn't find schedule task.
            Else
            {
                # Write to log.
                Write-Log -NoDateTime -Text (" ");
                Write-Log ("Cant find schedule task with the name '{0}'" -f $Name);
            }
        }
    }
    # Else context is admin.
    Else
    {
        # Write to log.
        Write-Log ("Schedule tasks can only be modified/disabled by running this script as an administrator");
    }
}

# Main function.
Function Remove-WindowsPreinstalledSoftware
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string[]]$AppxPackages,
        [Parameter(Mandatory=$true)][string[]]$Registries,
        [Parameter(Mandatory=$true)][string[]]$ScheduleTasks
    )

    # Transcript log file.
    $TranscriptFile = ("{0}\RemoveWindowsPreinstalledSoftware.log" -f $env:TEMP);

    # Start transcript.
    Start-Transcript -Path $TranscriptFile -Force -Append -Confirm:$false -IncludeInvocationHeader;

    # Get if context is administrator (sets global variable).
    $IsAdmin = Get-IsAdministrator;

    # Remove packages.
    Remove-BloatAppxPackages -AppxPackages $AppxPackages;

    # Remove registry keys.
    Remove-BloatRegistry -Registries $Registries;

    # Disable schedule tasks.
    Disable-BloatScheduleTasks -Names $ScheduleTasks;

    # Stop transcript.
    Stop-Transcript;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Initiate removal.
Remove-WindowsPreinstalledSoftware -AppxPackages $AppxPackages -Registries $Registries -ScheduleTasks $ScheduleTasks;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
