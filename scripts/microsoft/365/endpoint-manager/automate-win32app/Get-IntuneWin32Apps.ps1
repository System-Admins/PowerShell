#requires -version 5.1

<#
.SYNOPSIS
  Get all Win32 applications from Microsoft Intune.

.DESCRIPTION
  Get all Win32 application through the Graph API. It uses an custom service principal which need to have the API permissions "User.Read" (delegated) and "DeviceManagementApps.Read.All" (delegated).
  Input are Azure AD tenant ID, Client ID of the service principal and a client secret. For more information see "https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal".

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
    [Parameter(Mandatory=$true)][string]$AzureAdTenantId,

    # Application/Client ID of the Azure AD app (service principal).
    [Parameter(Mandatory=$true)][string]$AzureAdClientId,

    # Secret of the Azure AD app (service principal).
    [Parameter(Mandatory=$false)][string]$AzureAdClientSecret
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

        # Write to log.
        Write-Log ("Successfully got token from Microsoft Graph");
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while connecting to the Microsoft Graph API");
        Write-Log ($Error[0]) -NoDateTime;
    }
}

# Get all Intune apps.
Function Get-IntuneMobileApps
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken
    )
    
    # Headers.
    $Headers = @{
        'Authorization' = $ApiToken;
    }
    
    # Microsoft Graph API endpoint.
    $Uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps";
    
    # Try
    Try
    {
        # Write to log.
        Write-Log ("Getting all Intune Win32 apps");

        # Invoke endpoint.
        $Result = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get;

        # If result is not empty.
        If($Result.value)
        {
            # Return result.
            Return $Result.value;
        }
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong getting all Intune Win32 apps");
        Write-Log ($Error[0]) -NoDateTime;
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get graph token.
$ApiToken = Get-ApiToken -TenantId $AzureAdTenantId -ClientId $AzureAdClientId -ClientSecret $AzureAdClientSecret;

# Get all Win32 apps.
$Win32Apps = Get-IntuneMobileApps -ApiToken $ApiToken | Where-Object {$_."@odata.type" -like "*win32*"};

# Return Win32 apps.
Return $Win32Apps;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion