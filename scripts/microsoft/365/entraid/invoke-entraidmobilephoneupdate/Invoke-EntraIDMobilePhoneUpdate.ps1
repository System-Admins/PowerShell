#Require -Module MSOnline;
#Require -Module ActiveDirectory;
#Require -Version 5.1;

<#
.SYNOPSIS
  Get phone numbers that are not syncronized from on-premises Active Directory and optionally update mobile number in Microsoft 365.

.DESCRIPTION
  If you are running Entra Connect Sync and have the flag "BypassDirSyncOverridesEnabled" set to true.
  Users are allowed to change their mobile phone numbers in Microsoft 365.
  This script updates the mobile phone numbers in Microsoft 365, if the user has changed them without setting the flag "".
  See "https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-bypassdirsyncoverrides" for more information.
  MSOnline (deprecated) is the only PowerShell module that can update the mobile phone numbers in Microsoft 365.

.PARAMETER UpdateMobilePhoneNumber
  If the script should update the numbers in Microsoft 365.

.PARAMETER OutputFilePath
  Path to output the results.

.EXAMPLE
  # Get all users and export to JSON file.
   .\Invoke-EntraIDMobilePhoneUpdate.ps1 -OutputFilePath 'C:\Temp\userPhones.json';

.EXAMPLE
  # Get all users and export to JSON file and update phone numbers in Microsoft 365.
   .\Invoke-EntraIDMobilePhoneUpdate.ps1 -OutputFilePath 'C:\Temp\userPhones.json' -UpdateMobilePhoneNumber;

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  02-04-2025
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

Param
(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'If the script should update the phone numbers in Microsoft 365.')]
    [switch]$UpdateMobilePhoneNumber,

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Path to output the results.')]
    [string]$OutputFilePath = ('{0}\{1}_userPhones.json' -f [Environment]::GetFolderPath('Desktop'), (Get-Date).ToString('yyyyMMddHHmmss'))
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

# Import module(s).
Import-Module MSOnline -ErrorAction Stop;
Import-Module ActiveDirectory -ErrorAction Stop;

# Set TLS 1.2 as default security protocol.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

# If the PowerShell version is higher than 5.1.
if ($PSVersionTable.PSVersion.Major -gt 5)
{
    # Throw exception.
    throw ('This script can only run in PowerShell 5.1');
}

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Verbose -Message ("Connecting to Microsoft 365, please note that the module 'MSOnline' is deprecated") -Verbose;

# Connect to MSOnline service.
$null = Connect-MsolService -ErrorAction Stop;

# Write to log.
Write-Verbose -Message ('Get all (on-premises) Active Directory users') -Verbose;

# Get all users from Active Directory with the specified attributes.
$adUsers = Get-ADUser -Filter * -Properties 'ObjectGUID', 'userPrincipalName', 'samAccountName', 'mail', 'mobile', 'otherMobile';

# Write to log.
Write-Verbose -Message ('Get all Entra ID users') -Verbose;

# Get all users from Entra ID with the specified attributes.
$msolUsers = Get-MsolUser -All;

# Object array to store users with attribute mismatch.
$results = @();

# Foreach user in Active Directory.
foreach ($adUser in $adUsers)
{
    # If user principal name is empty.
    if ([string]::IsNullOrWhiteSpace($adUser.UserPrincipalName))
    {
        # Write to log.
        Write-Verbose -Message ('[{0}] Does not have a UPN, skipping account' -f $adUser.SamAccountName) -Verbose;

        # Continue to next user.
        continue;
    }

    # Get user from Entra ID.
    $msolUser = $msolUsers | Where-Object { $_.UserPrincipalName -eq $adUser.UserPrincipalName };

    # If user dont exist in Entra ID.
    if ($null -eq $msolUser)
    {
        # Write to log.
        Write-Verbose -Message ('[{0}] User was not found in Entra ID, skipping account' -f $adUser.UserPrincipalName) -Verbose;

        # Continue to next user.
        continue;
    }

    # If the user is not sync from on-premises AD.
    if ([string]::IsNullOrEmpty($msolUser.LastDirSyncTime))
    {
        # Write to log.
        Write-Verbose -Message ('[{0}] User is not synced from Active Directory, skipping account' -f $adUser.UserPrincipalName) -Verbose;

        # Continue to next user.
        continue;
    }

    # Create a object to store the results.
    $result = [PSCustomObject]@{
        'UserPrincipalName'    = $adUser.UserPrincipalName;
        'SamAccountName'       = $adUser.SamAccountName;
        'DisplayName'          = $adUser.DisplayName;
        'LastDirSyncTime'      = $msolUser.LastDirSyncTime;
        'OnPremObjectGuid'     = $adUser.ObjectGUID;
        'CloudObjectId'        = $msolUser.ObjectId;
        'OnPremMobile'         = @();
        'OnPremOtherMobile'    = @();
        'CloudMobile'          = @();
        'CloudOtherMobile'     = @();
        'MobileSyncValid'      = $false;
        'OtherMobileSyncValid' = $false;
        'UserSyncValid'        = $false;
    };

    # Foreach mobile phone number in AD.
    foreach ($onPremMobile in $adUser.mobile)
    {
        # Add to object.
        $result.OnPremMobile += $onPremMobile;
    }

    # Foreach other mobile phone number in AD.
    foreach ($onPremOtherMobile in $adUser.otherMobile)
    {
        # Add to object.
        $result.OnPremMobile += $OnPremOtherMobile;
    }

    # Foreach mobile phone number in Entra ID.
    foreach ($cloudMobile in $msolUser.MobilePhone)
    {
        # Add to object.
        $result.CloudMobile += $cloudMobile;
    }

    # Foreach other mobile phone number in Entra ID.
    foreach ($cloudOtherMobile in $msolUser.AlternateMobilePhones)
    {
        # Add to object.
        $result.CloudOtherMobile += $cloudOtherMobile;
    }

    # Compare objects.
    $compareMobile = Compare-Object -ReferenceObject $result.OnPremMobile -DifferenceObject $result.CloudMobile;
    $compareOtherMobile = Compare-Object -ReferenceObject $result.OnPremOtherMobile -DifferenceObject $result.CloudOtherMobile;

    # If mobile is equal.
    if ($compareMobile.Count -eq 0)
    {
        # Set mobile to true.
        $result.MobileSyncValid = $true;
    }

    # If other mobile is equal.
    if ($compareOtherMobile.Count -eq 0)
    {
        # Set other mobile to true.
        $result.OtherMobileSyncValid = $true;
    }

    # If mobile and other mobile is in sync.
    if ($true -eq $result.MobileSyncValid -AND
        $true -eq $result.OtherMobileSyncValid)
    {
        # Set sync valid to true.
        $result.UserSyncValid = $true;
    }

    # Add the result to the results array.
    $results += $result;
}

# Export results.
$results | ConvertTo-Json | Out-File -FilePath $OutputFilePath -Encoding utf8 -Force;

# If we should NOT fix the mobile phone and other mobile phone numbers.
if ($false -eq $UpdateMobilePhoneNumber)
{
    # Write to log.
    Write-Verbose -Message ('Some user mobile phone numbers are not updated in Microsoft 365') -Verbose;

    # Return results.
    return $results;
}

# Foreach user in the result.
foreach ($result in $results)
{
    # If user have a valid phone number sync.
    if ($true -eq $result.UserSyncValid)
    {
        # Write to log.
        Write-Verbose -Message ('[{0}] User mobile phone is already in sync, skipping account' -f $result.UserPrincipalName) -Verbose;

        # Continue to next user.
        continue;
    }

    # If user mobile phone is not in sync.
    if ($false -eq $result.MobileSyncValid)
    {
        # Write to log.
        Write-Verbose -Message ("[{0}] Setting mobile phone to '{1}' in Microsoft 365" -f $result.UserPrincipalName, ($result.OnPremMobile | Select-Object -First 1)) -Verbose;

        # Set mobile phone number in Microsoft 365.
        $null = Set-MsolUser -ObjectId $result.CloudObjectId -MobilePhone ($result.OnPremMobile | Select-Object -First 1);
    }

    # If user other mobile phone is not in sync.
    if ($false -eq $result.OtherMobileSyncValid)
    {
        # Write to log.
        Write-Verbose -Message ("[{0}] Setting other mobile phone to '{1}' in Microsoft 365" -f $result.UserPrincipalName, ($result.OnPremOtherMobile -join ', ')) -Verbose;

        # Set other mobile phone number in Microsoft 365.
        $null = Set-MsolUser -ObjectId $result.CloudObjectId -AlternateMobilePhones $result.OnPremOtherMobile;
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Return results.
return $results;

############### Finalize - End ###############
#endregion
