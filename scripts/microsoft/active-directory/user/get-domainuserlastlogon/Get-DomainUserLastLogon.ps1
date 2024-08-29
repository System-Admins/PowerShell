#Requires -version 5.1;

<#
.SYNOPSIS
  Process all domain controllers to get the last logon of all users in the domain.

.DESCRIPTION
    This script will process all domain controllers to get the last logon of all users in the domain. The script will export the information to a CSV file. Please make sure that you can contact all domain controllers to get the most precise information.

.Parameter ExportFilePath
  File path to export the information to. Default is the desktop with the filename 'yyyy-MM-dd_UserLastLogon.csv'.

.Example
   .\Get-DomainUserLastLogon.ps1 -ExportFilePath "C:\temp\UserLastLogon.csv";

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  29-08-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

param
(
    [Parameter(Mandatory = $false)]
    [string]$ExportFilePath = ('{0}\{1}_UserLastLogon.csv' -f [Environment]::GetFolderPath('Desktop'), (Get-Date).ToString('yyyy-MM-dd'))
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

# Get todays date.
$today = Get-Date;

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

function Get-DomainController
{
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
    )

    # Get domain controllers.
    $domainControllers = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers;

    # Object array for working domain controllers.
    $workingDomainControllers = New-Object System.Collections.ArrayList;

    # Foreach domain controller.
    foreach ($domainController in $domainControllers)
    {
        # Try to get krbtgt account.
        try
        {
            # Write to log.
            Write-Log ("Trying to communicate with domain controller '{0}'" -f $domainController.Name);

            # Construct ADSI path.
            $adsiPath = "LDAP://$($domainController.Name)";

            # Create directory searcher.
            $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher;

            # Set directory searcher properties.
            $directorySearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($adsiPath);

            # Search after krbtgt account.
            $directorySearcher.Filter = '(&(objectCategory=person)(objectClass=user)(samaccountname=krbtgt))';

            # Perform search.
            $searchResult = $directorySearcher.FindOne();

            # Get path (invoke search).
            $null = $searchResult.Properties.adspath;

            # Write to log.
            Write-Log ("Successfully communicated with domain controller '{0}'" -f $domainController.Name);

            # Add domain controller to working domain controllers.
            $null = $workingDomainControllers.Add($domainController.Name);
        }
        catch
        {
            # Write to log.
            Write-Log ("Domain controller '{0}' is not operational, skipping" -f $domainController.Name);
        }

    }

    # Write to log.
    Write-Log ('Found {0} operational domain controller' -f $workingDomainControllers.Count);

    # Return domain controller names.
    return $workingDomainControllers;
}

function Get-DomainName
{
    [CmdletBinding()]
    param
    (
    )

    # Get domain name.
    $domainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name;

    # Return domain name.
    return $domainName;
}

function Write-Log
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$message
    )

    # Write to information.
    Write-Information -MessageData ('[{0}] {1}' -f (Get-Date -Format 'dd-MM-yyyy HH:mm:ss'), $message) -InformationAction Continue;
}

function Get-DomainUser
{
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
    )

    # Get domain name.
    $domainName = Get-DomainName;

    # Contruct ADSI path.
    $adsiPath = "LDAP://$domainName";

    # Create directory searcher.
    $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher;

    # Set directory searcher properties.
    $directorySearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($adsiPath);
    $directorySearcher.Filter = '(&(objectCategory=person)(objectClass=user)(!userAccountControl:1.2.840.113556.1.4.803:=2))';
    $directorySearcher.PageSize = 1000;
    $null = $directorySearcher.PropertiesToLoad.Add('sAMAccountName');
    $null = $directorySearcher.PropertiesToLoad.Add('DisplayName');
    $null = $directorySearcher.PropertiesToLoad.Add('UserPrincipalName');

    # Write to log.
    Write-Log ("Getting all enabled users in the domain '{0}', this might take a while" -f $domainName);

    # Perform search.
    $searchResults = $directorySearcher.FindAll();

    # User object array.
    $users = New-Object System.Collections.ArrayList;

    # Foreach search result.
    foreach ($searchResult in $searchResults)
    {
        # Get user properties.
        $sAMAccountName = $searchResult.Properties['samaccountname'][0];
        $displayName = $searchResult.Properties['displayname'][0];
        $userPrincipalName = $searchResult.Properties['userprincipalname'][0];

        # Create user object.
        $user = [PSCustomObject]@{
            'sAMAccountName'     = $sAMAccountName;
            'DisplayName'        = $displayName;
            'UserPrincipalName'  = $userPrincipalName;
            'LastLogon'          = $null;
            'DaysSinceLastLogon' = $null;
        };

        # Add user to array.
        $null = $users.Add($user);
    }

    # Write to log.
    Write-Log ("Found {0} users in the domain '{0}'" -f $users.Count, $domainName);

    # Return users.
    return $users;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log ('Script started');

# Get all domain users.
$domainUsers = Get-DomainUser;

# Get all domain controllers.
$domainControllers = Get-DomainController;

# Foreach user.
foreach ($domainUser in $domainUsers)
{
    # Write to log.
    Write-Log ('[{0}] Processing user' -f $domainUser.sAMAccountName);

    # Foreach domain controller.
    foreach ($domainController in $domainControllers)
    {
        # Try to get user info from domain controller.
        try
        {
            # Write to log.
            Write-Log ('[{0}] [{1}] Getting info from domain controller' -f $domainUser.sAMAccountName, $domainController);

            # Construct ADSI path.
            $adsiPath = "LDAP://$($domainController)";

            # Create directory searcher.
            $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher;

            # Set directory searcher properties.
            $directorySearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($adsiPath);
            $null = $directorySearcher.PropertiesToLoad.Add('lastLogon');
            $null = $directorySearcher.PropertiesToLoad.Add('lastLogonTimestamp');

            # Search after krbtgt account.
            $directorySearcher.Filter = ('(&(objectCategory=person)(objectClass=user)(samaccountname={0}))' -f $domainUser.sAMAccountName);

            # Perform search.
            $searchResult = $directorySearcher.FindOne();
        }
        catch
        {
            # Write to log.
            Write-Log ('[{0}] [{1}] Something went wrong while getting user from the domain controller' -f $domainUser.sAMAccountName, $domainController);

            # Continue to next domain controller.
            continue;
        }

        # Get last logon.
        $lastLogon = $searchResult.Properties['lastLogon'][0];

        # Get last logon timestamp.
        $lastLogonTimestamp = $searchResult.Properties['lastLogonTimestamp'][0];

        # Get newest logon of the lastLogon and lastLogonTimestamp.
        $newestLogon = $lastLogon, $lastlogontimestamp | Sort-Object -Descending | Select-Object -First 1;

        # If newest logon is not empty.
        if ($false -eq [string]::IsNullOrEmpty($newestLogon))
        {
            # Convert newest logon to DateTime.
            $newestLogonDateTime = [DateTime]::FromFileTime($newestLogon);

            # Write to log.
            Write-Log ("[{0}] [{1}] Last logon is '{2}' on the domain controller" -f $domainUser.sAMAccountName, $domainController, ($newestLogonDateTime).ToString('dd-MM-yyyy'));

            # If newest logon is greater than current last logon.
            if ($newestLogonDateTime -gt $domainUser.LastLogon)
            {
                # Write to log.
                Write-Log ("[{0}] Newest last logon is now '{1}'" -f $domainUser.sAMAccountName, ($newestLogonDateTime).ToString('dd-MM-yyyy'));

                # Update last logon.
                $domainUser.LastLogon = $newestLogonDateTime;
            }
        }
    }

    # If last logon is DateTime.MinValue.
    if ([string]::IsNullOrEmpty($domainUser.LastLogon))
    {
        # Write to log.
        Write-Log ('[{0}] User never logged on' -f $domainUser.sAMAccountName);

        $domainUser.LastLogon = 'Never';
    }

    # If the last logon is not set to 'Never'.
    if ('Never' -ne $domainUser.LastLogon)
    {
        # Add number of days since last logon.
        $domainUser.DaysSinceLastLogon = [int]([math]::Round((New-TimeSpan -Start $domainUser.LastLogon -End $today).TotalDays));
    }
}

# Get parent directory.
$parentDirectory = [System.IO.Path]::GetDirectoryName($ExportFilePath);

# Create directory.
$null = New-Item -Path $parentDirectory -ItemType Directory -Force;

# Write to log.
Write-Log ("Exporting info to CSV file to '{0}'" -f $ExportFilePath);

# Export to CSV.
$domainUsers | Export-Csv -Path $ExportFilePath -NoTypeInformation -Encoding UTF8 -Delimiter ';' -Force;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Log ('Script finished');

# Return domain users.
return $domainUsers;

############### Finalize - End ###############
#endregion
