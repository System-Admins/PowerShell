#Requires -Module Microsoft.Graph.Users, Microsoft.Graph.Authentication -Version 5.1;

<#
.SYNOPSIS
  Get external users in Microsoft Entra ID and their last login information.

.DESCRIPTION
  Requires the Microsoft.Graph.Users and Microsoft.Graph.Authentication modules.
  Connects to Microsoft Entra ID (Azure AD) and retrieves all guest/external users along with their last login date, account status, and creation date. The results are exported to a CSV file.

.PARAMETER OutputFilePath
  (Optional) Path to output the results, defaults to desktop.

.EXAMPLE
  # Get all guest users and export last login to a CSV file.
  .\Get-EntraGuestLastLogin.ps1 -OutputFilePath 'C:\Temp\externalUsers.csv';

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  09-01-2026
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

param
(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Path to output the results.')]
    [string]$OutputFilePath = ('{0}/{1}_entraIdExternalUserLastLogin.csv' -f [Environment]::GetFolderPath('Desktop'), (Get-Date).ToString('yyyyMMdd'))
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

# Import module(s).
Import-Module `
    -Name 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Users' `
    -ErrorAction Stop;

# Set TLS 1.2 as default security protocol.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

# Microsoft Graph connection scopes.
$graphScopes = @(
    'User.Read.All',
    'Directory.Read.All',
    'AuditLog.Read.All'
);

# Properties to retrieve for each user.
$mgUserProperties = @(
    'DisplayName',
    'UserPrincipalName',
    'Mail',
    'SignInActivity',
    'AccountEnabled',
    'CreatedDateTime'
);

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Verbose -Message ("Script started at '{0}'" -f (Get-Date)) -Verbose;
Write-Verbose -Message ('Connecting to Microsoft 365') -Verbose;

# Connect to Microsoft Graph with the required scopes.
$null = Connect-MgGraph `
    -Scopes $graphScopes `
    -ContextScope Process `
    -NoWelcome `
    -ErrorAction Stop;

# Write to log.
Write-Verbose -Message ('Getting all Microsoft 365 users') -Verbose;

# Retrieve all users with the specified properties.
$users = Get-MgUser `
    -All `
    -Property $mgUserProperties;

# Object array to store results.
$results = @();

# Foreach user.
foreach ($user in $users)
{
    # If the identity is not a guest or external.
    if ($user.UserPrincipalName -notlike '*#EXT#@*')
    {
        # Write to log.
        Write-Verbose -Message ('{0}: User is not external or guest, skipping' -f $user.UserPrincipalName) -Verbose;

        # Skip user.
        continue;
    }

    # Last login date.
    [DateTime]$lastLoginDateTime = [DateTime]::MinValue;

    # Status of last login.
    [bool]$haveLoggedIn = $false;

    # If the last successfull sign in date is empty.
    if (-not [string]::IsNullOrEmpty($user.SignInActivity.LastSuccessfulSignInDateTime))
    {
        # Write to log.
        Write-Verbose -Message ('{0}: User has last successful sign-in date is {1}' -f $user.UserPrincipalName, $user.SignInActivity.LastSuccessfulSignInDateTime) -Verbose;

        # Set to actual value for user.
        $lastLoginDateTime = $user.SignInActivity.LastSuccessfulSignInDateTime;

        # Set status.
        $haveLoggedIn = $true;
    }
    # Else, if the last sign in date is empty.
    else
    {
        # Write to log.
        Write-Verbose -Message ('{0}: User has never logged in' -f $user.UserPrincipalName) -Verbose;
    }

    # Calculate last login in days.
    $daysSinceLastLogin = (Get-Date) - $lastLoginDateTime;

    # Add the user information to the results array.
    $results += [PSCustomObject]@{
        DisplayName        = $user.DisplayName;
        UserPrincipalName  = $user.UserPrincipalName;
        Mail               = $user.Mail;
        LastLoginDateTime  = $lastLoginDateTime;
        DaysSinceLastLogin = $daysSinceLastLogin.Days;
        AccountEnabled     = $user.AccountEnabled;
        HaveLoggedIn       = $haveLoggedIn;
        CreatedDateTime    = $user.CreatedDateTime;
        DaysSinceCreation  = ((Get-Date) - $user.CreatedDateTime).Days;
    };
}

# Write to log.
Write-Verbose -Message ('Found {0} guest users' -f $results.Count) -Verbose;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Verbose -Message ("Exporting results to CSV at '{0}'" -f $OutputFilePath) -Verbose;

# Export results to CSV.
$null = $results | Export-Csv `
    -Path $OutputFilePath `
    -NoTypeInformation `
    -Encoding UTF8 `
    -Force `
    -Delimiter ';';

# Return results.
return $results;

# Write to log.
Write-Verbose -Message ("Script ended at '{0}'" -f (Get-Date)) -Verbose;

############### Finalize - End ###############
#endregion
