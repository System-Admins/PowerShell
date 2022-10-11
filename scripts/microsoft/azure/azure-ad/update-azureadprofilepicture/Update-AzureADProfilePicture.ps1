#requires -version 5.1

<#
.SYNOPSIS
  Update Azure AD User profile photo.
.DESCRIPTION
  This scripts updates a users Azure AD profile picture through Graph API.
  Requires a service pincipal with the permissions 'User.ReadWrite' (application).
.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  11-10-2022
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

    # UserPrincipalName of the user.
    [Parameter(Mandatory=$true)][string]$UserPrincipalName,

    # Path of the image.
    [Parameter(Mandatory=$true)][string]$ImagePath

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
Function Get-GraphApiToken
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

# Update Azure AD user profile photo.
Function Update-UserPhoto
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$GraphApiToken,
        [Parameter(Mandatory=$true)][string]$UserPrincipalName,
        [Parameter(Mandatory=$true)][string]$ImagePath
    )

    # Construct header.
    $Headers = @{
        Authorization = $GraphApiToken;
        'Content-type'  = "application/json";
    };

    # Try to call the API.
    Try
    {
        # Write to log.
        Write-Log ("Updating Azure AD photo for '{0}'" -f $UserPrincipalName);

        # Invoke REST against Graph API.
        $Response = Invoke-RestMethod -Uri ('https://graph.microsoft.com/v1.0/users/{0}/photo/$value' -f $UserPrincipalName) -Headers $Headers -Method Put -InFile $ImagePath -ErrorAction Stop;

        # Write to log.
        Write-Log ("Successfully updated profile image for '{0}'" -f $UserPrincipalName);
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while updating the Azure AD photo for '{0}'" -f $UserPrincipalName);
        Throw ($Error[0]);
    }
}

# Update Azure AD user profile photo.
Function Update-AzureADUserPhoto
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

        # UserPrincipalName of the user.
        [Parameter(Mandatory=$true)][string]$UserPrincipalName,

        # Path of the image.
        [Parameter(Mandatory=$true)][string]$ImagePath
    )

    # Get Graph API token.
    $GraphApiToken = Get-GraphApiToken -TenantId $AzureAdTenantId -ClientId $AzureAdClientId -ClientSecret $AzureAdClientSecret;

    # Update Azure AD photo.
    Update-UserPhoto -GraphApiToken $GraphApiToken -UserPrincipalName $UserPrincipalName -ImagePath $ImagePath;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Update Azure AD user photo.
Update-AzureADUserPhoto -AzureAdTenantId $AzureAdTenantId `
                        -AzureAdClientId $AzureAdClientId `
                        -AzureAdClientSecret $AzureAdClientSecret `
                        -UserPrincipalName $UserPrincipalName `
                        -ImagePath $ImagePath;


############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
