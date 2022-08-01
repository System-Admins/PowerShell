#requires -version 5.1

<#
.SYNOPSIS
  This script runs multiple script for automating package updates in Microsoft Intune (Endpoint Manager).
  It uses REST methods for all interactions and does the following:
  - Downloads package info from WinGet repository.
  - Uses package info for downloading the installation binary.
  - Convert the package to IntuneWin format.
  - Check if version already is deployed in Microsoft Intune.
  - Creates and upload an "update" version for users that have old version or is not required (available only) in Intune.

.DESCRIPTION
  Check the scripts for further description of each step.
  Download-WinGetPackage.ps1
  Get-IntuneWin32Apps.ps1
  Run-IntuneWinAppUtil.ps1
  Copy-File.ps1
  Replace-IntuneWin32App.ps1
  Add-IntuneWin32App.ps1
  Remove-IntuneWin32App.ps1

.Parameter AzureAdTenantId
  Azure Tenant ID.

.Parameter AzureAdClientId
  Application/Client ID of the Azure AD app (service principal).

.Parameter AzureAdClientSecret
  Secret of the Azure AD app (service principal).

.Parameter PackageId
  The package id from WinGet. You can find an ID through WinGet utility or https://winget.run

.Parameter PackageArchitecture
  If the program should be 64 (x64) or 32-bit (x86).

.Example
   .\Automate-Win32App.ps1 -AzureAdTenantId "<Tenant ID>" -AzureAdClientId "<Client ID> -AzureAdClientSecret "<Secret>" -PackageId "SlackTechnologies.Slack" -Architecture "x86";

.NOTES
  Version:        0.1
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  14-07-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]	
		
Param
(
    # Azure AD Tenant ID.
    [Parameter(Mandatory=$true)][string]$AzureAdTenantId,

    # Application/Client ID of the Azure AD app (service principal).
    [Parameter(Mandatory=$true)][string]$AzureAdClientId,

    # Secret of the Azure AD app (service principal).
    [Parameter(Mandatory=$true)][string]$AzureAdClientSecret,

    # The package id from WinGet. You can find an ID through WinGet utility or https://winget.run.
    [Parameter(Mandatory=$true)][string]$PackageId,

    # If the program should be 64 (x64) or 32-bit (x86).
    [Parameter(Mandatory=$true)][ValidateSet("x64", "x86")][string]$PackageArchitecture
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

# Write to log.
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
        Write-Host "";
    }
    Else
    {
        # Write to the console.
        Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
}

# Get Microsoft Graph API token.
Function Get-ApiToken
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$TenantId,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$true)][string]$ClientSecret
    )

    # Construct body.
    $Body = @{    
        Grant_Type    = "client_credentials";
        Scope         = "https://graph.microsoft.com/.default";
        client_Id     = $ClientId;
        Client_Secret = $ClientSecret;
    };

    # Write to log.
    Write-Log ("Getting API token for Microsoft Graph");

    # Try to call the API.
    Try
    {
        # Invoke REST against Graph API.
        $Response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $Body;

        # Return
        Return [string]("Bearer {0}" -f $Response.access_token);
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while connecting to the Microsoft Graph API");
        Write-Log ($Error[0]) -NoDateTime;
    }
}

# Get script location.
Function Get-ScriptLocation
{
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

    # Return path.
    Return $ScriptPath;
}

# Automate Win32 app to Intune including update app.
Function Automate-Win32App
{
    [cmdletbinding()]	
		
    Param
    (
        # Azure AD Tenant ID.
        [Parameter(Mandatory=$true)][string]$AzureAdTenantId,

        # Application/Client ID of the Azure AD app (service principal).
        [Parameter(Mandatory=$true)][string]$AzureAdClientId,

        # Secret of the Azure AD app (service principal).
        [Parameter(Mandatory=$true)][string]$AzureAdClientSecret,

        # Package id.
        [Parameter(Mandatory=$true)][string]$PackageId,

        # Architecture (x86 or x64).
        [Parameter(Mandatory=$true)][ValidateSet("x64", "x86")][string]$PackageArchitecture
    )

    # Get graph token.
    $ApiToken = Get-ApiToken -TenantId $AzureAdTenantId -ClientId $AzureAdClientId -ClientSecret $AzureAdClientSecret;

    # Get script path.
    $ScriptPath = Get-ScriptLocation;

    # Write to log.
    Write-Log ("Setting working directory to '{0}'" -f $ScriptPath);

    # Set location to script path.
    Set-Location -Path $ScriptPath;

    # Download package.
    $Package = .\Download-WinGetPackage.ps1 -PackageId $PackageId `
                                            -Architecture $PackageArchitecture;

    # Get all Win32 apps.
    $Win32Apps = .\Get-IntuneWin32Apps.ps1 -AzureAdTenantId $AzureAdTenantId `
                                           -AzureAdClientId $AzureAdClientId `
                                           -AzureAdClientSecret $AzureAdClientSecret;

    # Convert app to IntuneWin.
    $IntuneWinFilePath = .\Run-IntuneWinAppUtil.ps1 -SourcePath $Package.SourceDirectoryPath `
                                -SetupFile $Package.Installer.InstallerFileName;
    
    # Filename detection and requirement script.
    $PackageDetectionScript = ('Detect-InstalledSoftware.ps1');

    # Copy detection script.
    $DetectionScriptPath = .\Copy-File.ps1 -SourceFile $PackageDetectionScript -DestinationFile ("{0}\{1}" -f $Package.SourceDirectoryPath, "Detect-Software.ps1") -FindReplace -ReplaceTable @{'[NAME]' = $Package.Name; '[VERSION]' = $Package.Version; '[METHOD]' = 'Detection'};

    # Copy requirement script.
    $RequirementScriptPath = .\Copy-File.ps1 -SourceFile $PackageDetectionScript -DestinationFile ("{0}\{1}" -f $Package.SourceDirectoryPath, "Detect-Upgrade.ps1") -FindReplace -ReplaceTable @{'[NAME]' = $Package.Name; '[VERSION]' = $Package.Version; '[METHOD]' = 'Requirement'}

    # If the app is already added.
    If($Win32App = $Win32Apps | Where-Object {$_.DisplayName -eq $Package.DisplayName} | Select-Object -First 1)
    {
        # Write to log.
        Write-Log ("Program '{0}' already present in Intune" -f $Package.DisplayName);

        # If version is the same.
        If($Win32App.displayVersion -eq $Package.Version)
        {
            # Write to log.
            Write-Log ("Program version '{0}' is the same, skipping upload" -f $Package.Version);
        }
        # Else the version is not the same.
        Else
        {
            # Write to log.
            Write-Log ("Program version '{0}' is not the same, will update package" -f $Package.Version);

            # Replace Win32 app.
            $IntuneApp = .\Replace-IntuneWin32App.ps1 -ApiToken $ApiToken `
                                                      -IntuneAppId $Win32App.Id `
                                                      -Name ($Package.DisplayName) `
                                                      -Version $Package.Version `
                                                      -Publisher $Package.Publisher `
                                                      -Description $Package.Description `
                                                      -IntuneWinPath $IntuneWinFilePath `
                                                      -DetectionScriptPath $DetectionScriptPath `
                                                      -InstallCmd $Package.Installer.InstallerCmdLine `
                                                      -InstallExperience $Package.Installer.Scope `
                                                      -ProjectUrl $Package.ProjectUrl;
        }
    }
    # Else app is not added.
    Else
    {
        # Write to log.
        Write-Log ("Program '{0}' version '{1}' is not present in Intune, will upload the application" -f $Package.DisplayName, $Package.Version);

        # Add new Win32 app.
        $IntuneApp = .\Add-IntuneWin32App.ps1 -ApiToken $ApiToken `
                                              -Name ($Package.DisplayName) `
                                              -Version $Package.Version `
                                              -Publisher $Package.Publisher `
                                              -Description $Package.Description `
                                              -IntuneWinPath $IntuneWinFilePath `
                                              -DetectionScriptPath $DetectionScriptPath `
                                              -InstallCmd $Package.Installer.InstallerCmdLine `
                                              -InstallExperience $Package.Installer.Scope `
                                              -ProjectUrl $Package.ProjectUrl;
    }

    # Write to log.
    Write-Log ("Waiting 5 seconds for Azure Blob storage to be ready");   

    # Start sleep for upload issues regarding Azure Blob storage.
    Start-Sleep -Seconds 5;

    # Construct update app for the same app.
    $UpdateAppName = ("{0} - Update" -f $Package.DisplayName);

    # If the update app is already added.
    If($Win32UpdateApp = $Win32Apps | Where-Object {$_.DisplayName -eq $UpdateAppName} | Select-Object -First 1)
    {
        # Write to log.
        Write-Log ("Removing existing '{0}' program in Intune" -f $UpdateAppName);

        # Remove app.
        .\Remove-IntuneWin32App.ps1 -ApiToken $ApiToken -IntuneAppId $Win32UpdateApp.Id;
    }

    # Write to log.
    Write-Log ("Update program '{0}' version '{1}' is not present in Intune, will upload the application" -f $Package.DisplayName, $Package.Version);    

    # Add new Win32 app.
    $IntuneUpdateApp = .\Add-IntuneWin32App.ps1 -ApiToken $ApiToken `
                                                -Name $UpdateAppName `
                                                -Version $Package.Version `
                                                -Publisher $Package.Publisher `
                                                -Description $Package.Description `
                                                -IntuneWinPath $IntuneWinFilePath `
                                                -DetectionScriptPath $DetectionScriptPath `
                                                -RequirementScriptPath $RequirementScriptPath `
                                                -InstallCmd $Package.Installer.InstallerCmdLine `
                                                -InstallExperience $Package.Installer.Scope `
                                                -ProjectUrl $Package.ProjectUrl;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Automate Win32 app to Intune including update app.
Automate-Win32App -AzureAdTenantId $AzureAdTenantId `
                  -AzureAdClientId $AzureAdClientId `
                  -AzureAdClientSecret $AzureAdClientSecret `
                  -PackageId $PackageId `
                  -PackageArchitecture $PackageArchitecture;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion