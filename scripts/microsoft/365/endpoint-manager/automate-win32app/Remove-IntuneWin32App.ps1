#requires -version 5.1

<#
.SYNOPSIS
  Add or update an Win32 application in Microsoft Intune.
.DESCRIPTION
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
    # Azure AD Tenant ID.
    [Parameter(Mandatory=$false)][string]$AzureAdTenantId,

    # Application/Client ID of the Azure AD app (service principal).
    [Parameter(Mandatory=$false)][string]$AzureAdClientId,

    # Secret of the Azure AD app (service principal).
    [Parameter(Mandatory=$false)][string]$AzureAdClientSecret,

    # Graph API Token.
    [Parameter(Mandatory=$false)][string]$ApiToken,
    
    # Intune - App ID of existing app.
    [Parameter(Mandatory=$true)][string]$IntuneAppId
)

# Clear screen.
#Clear-Host;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Application to update.
$Application = @{
    "Name" = $Name;
    "Version" = $Version;
    "Publisher" = $Publisher;
    "Description" = $Description;
    "Developer" = $Publisher;
    "Path" = $IntuneWinPath;
    "DetectionScript" = $DetectionScriptPath;
    "RequirementScript" = $RequirementScriptPath;
    "EnforceSignatureCheck" = $false;
    "InstallCmd" = $InstallCmd;
    "UninstallCmd" = $InstallCmd;
    "InstallExperience" = $InstallExperience; #or user.
    "InformationUrl" = $ProjectUrl;
    "IsFeatured" = $false; #or $true.
    "MinimumOs" = @{"v10_1607" = $true};
    "Notes" = "Automated by System Admins";
    "Owner" = $Publisher;
    "PrivacyUrl" = $ProjectUrl;
    "RunAs32Bit" = $false; #or true;
};

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

# Commit Win32 app to Intune.
Function Remove-IntuneWin32App
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken,
        [Parameter(Mandatory=$true)][string]$AppId
    )

    # Write to log.
    Write-Log ("Deleting application in Intune");

    # Construct URI.
    $Uri = ("https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}" -f $AppId);

    # Create request headers.
    $Headers = @{
        'Authorization' = $ApiToken;
        'content-type' = 'application/json';
    };

    # Make a request.
    $Response = Invoke-WebRequest $Uri -Method Delete -Headers $Headers -ContentType "application/json";

    # Return reponse.
    Return $Response;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# If API token is empty.
If([string]::IsNullOrEmpty($ApiToken))
{
    # Get graph token.
    $ApiToken = Get-ApiToken -TenantId $AzureAdTenantId -ClientId $AzureAdClientId -ClientSecret $AzureAdClientSecret;
}

# Add new Win32 app.
Remove-IntuneWin32App -ApiToken $ApiToken -AppId $IntuneAppId | Out-Null;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
