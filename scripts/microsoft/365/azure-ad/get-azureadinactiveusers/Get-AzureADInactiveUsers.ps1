# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Requires module.
#requires -Module Microsoft.Graph.Authentication
#requires -Module Microsoft.Graph.Users

<#
.SYNOPSIS
  Get all users that are have not logged in recently.

.DESCRIPTION
  Uses the Graph API and you will need a service principal (tenant id, client id and a client secret) with the following permissions:
  - AuditLog.Read.All
  - User.Read.All

  Remember to change line 54, 55 and 56

.EXAMPLE
  .\Get-AzureADInactiveUsers.ps1 -UserInactiveDaysThreshold 90 -CsvExportFilePath "C:\Path\To\Export\Csv\File.csv";

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  26-10-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]	
		
Param
(
    [Parameter(Mandatory=$false)][int]$UserInactiveDaysThreshold = 2,
    [Parameter(Mandatory=$false)][string]$CsvExportFilePath = ("{0}\{1}_AzureADInactiveUsers.csv" -f [Environment]::GetFolderPath("Desktop"), (Get-Date).ToString("yyyyMMdd"))
)

# Import module(s).
Import-Module -Name 'Microsoft.Graph.Authentication' -DisableNameChecking -Force;
Import-Module -Name 'Microsoft.Graph.Users' -DisableNameChecking -Force;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Variables - Start ###############

# Configuration.
$Config = @{
    # Azure AD.
    'AzureAD' = @{
        'TenantId' = 'insert tenant id here';
        'ClientId' = 'insert client id here';
        'ClientSecret' = 'insert client secret here';
    };
};

############### Variables - End ###############
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
  
    # If text is not present.
    If([string]::IsNullOrEmpty($Text))
    {
        # Write to the console.
        Write-Host("");
    }
    Else
    {
        # Write to the console.
        Write-Host("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text);
    }
}

# Get Microsoft Graph API token.
Function Get-MsGraphApiToken
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
        Return [string]($Response.access_token);
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while connecting to the Microsoft Graph API");
        Write-Log ($Error[0]);
    }
}

# Get inactive users from Azure AD.
Function Get-AzureADInactiveUsers
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$TenantId,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$true)][string]$ClientSecret,
        [Parameter(Mandatory=$true)][int]$UserInactiveDaysThreshold
    )

    # Get graph token.
    $AccessToken = Get-MsGraphApiToken -TenantId $TenantId `
                                       -ClientId $ClientId `
                                       -ClientSecret $ClientSecret;

    # Try
    Try
    {
        # Write to log.
        Write-Log ("Connecting to Graph with access token");

        # Connect to graph.
        Connect-MgGraph -AccessToken $AccessToken | Out-Null;

        # Select beta version.
        Select-MgProfile beta;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while connecting to the Graph API");
        Write-Log ($Error[0]);
    }

    # Write to log.
    Write-Log ("Getting all users from Azure AD");

    # Get details.
    $AzureADUsers = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, SignInActivity, usageLocation | Select-Object Id, DisplayName, UserPrincipalName, @{n='LastSignInDateTime'; e={[datetime]$_.SignInActivity.LastSignInDateTime}}, usageLocation;

    # Object array.
    $Result = @();

    # Foreach Azure AD user.
    Foreach($AzureADUser in $AzureADUsers)
    {        
        # If last sign-in date is never.
        If([string]::IsNullOrEmpty($AzureADUser.LastSignInDateTime))
        {
            # Set last sign in to never.
            $LastSignInDateTime = -1;

            # Write to log.
            Write-Log ("User '{0}' never logged in" -f $AzureADUser.UserPrincipalName);
        }
        # Else sign in date is valid.
        Else
        {
            # Get timespan.
            $TimeSpan = New-TimeSpan -Start $AzureADUser.LastSignInDateTime -End (Get-Date);

            # Set last sign in to days.
            $LastSignInDateTime = $TimeSpan.Days;

            # Write to log.
            Write-Log ("User '{0}' last login was {1} days ago" -f $AzureADUser.UserPrincipalName, $LastSignInDateTime);
        }

        # Add to object.
        $AzureADUser | Add-Member -MemberType NoteProperty -Name "DaysSinceLastLogin" -Value $LastSignInDateTime -Force;

        # Add to object array.
        $Result += $AzureADUser;
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get all users that are have not logged in recently.
$AzureADUsers = Get-AzureADInactiveUsers -TenantId $Config.AzureAD.TenantId `
                                         -ClientId $Config.AzureAD.ClientId `
                                         -ClientSecret $Config.AzureAD.ClientSecret `
                                         -UserInactiveDaysThreshold $UserInactiveDaysThreshold;

# Get directory path for export file.
$DirectoryPath = Split-Path -Path $CsvExportFilePath;

# If path dont exist.
If(!(Test-Path -Path $DirectoryPath))
{
    # Write to log.
    Write-Log ("Creating directory '{0}'" -f $DirectoryPath);

    # Create directory.
    New-Item -Path $CsvExportFilePath -ItemType Directory -Force | Out-Null;
}

# Write to log.
Write-Log ("Exporting user report to '{0}'" -f $CsvExportFilePath);
                         
# Export results to an CSV.
$AzureADUsers | Export-Csv -Path $CsvExportFilePath -Encoding UTF8 -Delimiter ";" -NoTypeInformation -Force;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
