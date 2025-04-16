#Requires -Version 7.4;
#Requires -Modules PnP.PowerShell;

<#
.SYNOPSIS
  Get recoverable items from one or more SharePoint sites.

.DESCRIPTION
  This script retrieves recoverable items from one or more sites in SharePoint Online.
  It allows filtering based on a specified date range.

.PARAMETER Url
  The URL(s) to retrieve recoverable items from.
  If not specified, all sites in the organization will be used.
  Specify the SharePoint site URL(s) to filter.

.PARAMETER FilterStartTime
  The start time for the filter. Default is 14 days ago.

.PARAMETER FilterEndTime
  The end time for the filter. Default is now.

.PARAMETER ExportFilePath
  The file path to export the results to.
  Default is the desktop with a timestamp.

.EXAMPLE
  # Get recoverable items from the last 14 days.
   .\Get-SharePointRecycleBinItem.ps1;

.EXAMPLE
  # Get recoverable items from the last 30 days.
   .\Get-SharePointRecycleBinItem.ps1 -FilterStartTime (Get-Date).AddDays(-30) -FilterEndTime (Get-Date).AddDays(-1) -ExportFilePath "C:\Temp\RecoverableItems.csv";

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  16-04-2025
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]
param
(
  # SharePoint sites to get recoverable items from.
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$AdminUrl,

  # Entra tenant ID.
  [Parameter(Mandatory = $true, Position = 1)]
  [string]$TenantId,

  # SharePoint sites to get recoverable items from.
  [Parameter(Mandatory = $false, Position = 2)]
  [string[]]$Url,

  # Start time for the filter.
  [Parameter(Mandatory = $false, Position = 3)]
  [datetime]$FilterStartTime = (Get-Date).AddDays(-14),

  # End time for the filter.
  [Parameter(Mandatory = $false, Position = 4)]
  [datetime]$FilterEndTime = (Get-Date),

  # Export file path for results.
  [Parameter(Mandatory = $false, Position = 5)]
  [string]$ExportFilePath = ('{0}\SharePoint-RecoverableItem-{1:yyyyMMdd-HHmmss}.csv' -f ([Environment]::GetFolderPath('Desktop')), (Get-Date))
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

# Write to log.
Write-Information -MessageData ('Script started - {0}' -f (Get-Date)) -InformationAction Continue;

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

# PnP Online application name.
$pnpOnlineApplicationName = ('PnpOnline_{0}' -f (Get-Random));

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Information -MessageData ("Trying to register app in Entra ID for PnP Online called '{0}'" -f $pnpOnlineApplicationName) -InformationAction Continue;
Write-Information -MessageData ('Please login with a global admin account, the login prompt may be hidden') -InformationAction Continue;
Write-Information -MessageData ('Login prompt will appear twice, and a consent is needed for the application') -InformationAction Continue;

# Register the PnP Online as an application in Entra.
$entraIdApp = Register-PnPEntraIDAppForInteractiveLogin `
  -Tenant $TenantId `
  -ApplicationName $pnpOnlineApplicationName `
  -SharePointDelegatePermissions 'AllSites.FullControl'`
  -Interactive `
  -WarningAction SilentlyContinue `
  -ErrorAction Stop;

# Get the application ID.
$applicationId = $entraIdApp.'AzureAppId/ClientId';

# If the application ID is not null, then we can proceed.
if ($null -eq $applicationId)
{
  # Throw an error.
  throw ('Unable to register the PnP Online application in Entra, aborting script');
}

# Write to log.
Write-Information -MessageData ("App ID is '{0}' for PnP Online" -f $applicationId) -InformationAction Continue;
Write-Information -MessageData ('Connecting from Sharepoint Online, please login with a SharePoint Administrator account') -InformationAction Continue;

# Connect to SharePoint Online.
$pnpConnection = Connect-PnPOnline `
  -Url $AdminUrl `
  -Interactive `
  -ApplicationId $applicationId `
  -ReturnConnection `
  -ForceAuthentication `
  -WarningAction SilentlyContinue;

# Get current user.
$ctx = Get-PnPContext -Connection $pnpConnection;
$ctx.Load($ctx.Web.CurrentUser);
$ctx.ExecuteQuery();
$currentUser = $ctx.Web.CurrentUser;

# Write to log.
Write-Information -MessageData ("Logged in admin account is '{0}'" -f $currentUser.UserPrincipalName) -InformationAction Continue;
Write-Information -MessageData ('Getting all sites from SharePoint Online, this might take a while') -InformationAction Continue;

# Get all sites in the tenant.
$sites = Get-PnPTenantSite `
  -Connection $pnpConnection `
  -Detailed `
  -WarningAction SilentlyContinue;

# Results object.
$results = @();

# Foreach site.
foreach ($site in $sites[-1])
{
  # If the URL is specified.
  if ($Url.Count -gt 0)
  {
    # Check if the site URL is in the list of URLs.
    if ($Url -notcontains $site.Url)
    {
      # Skip this site.
      continue;
    }
  }

  # Get root site URL.
  [string]$sharePointTenantUrl = ($site.Url -split '\/sites')[0];

  # Write to log.
  Write-Information -MessageData ("[{0}] Adding '{1}' as site collection administrator" -f $site.Url, $currentUser.Email) -InformationAction Continue;

  # Add the current user as a site collection administrator.
  $null = Set-PnPTenantSite `
    -Identity $site.Url `
    -Owners $currentUser.UserPrincipalName `
    -Connection $pnpConnection `
    -WarningAction SilentlyContinue;

  # Connect to the site.
  $pnpSiteConnection = Connect-PnPOnline `
    -Url $site.Url `
    -Connection $pnpConnection `
    -Interactive `
    -ClientId $pnpConnection.ClientId `
    -ReturnConnection `
    -WarningAction SilentlyContinue;

  # Write to log.
  Write-Information -MessageData ('[{0}] Getting items in recycle bins' -f $site.Url) -InformationAction Continue;

  # Get recycle bin items.
  $recycleBinItems = Get-PnPRecycleBinItem `
    -WarningAction SilentlyContinue `
    -RowLimit ([int]::MaxValue) `
    -Connection $pnpSiteConnection;

  # Write to log.
  Write-Information -MessageData ('[{0}] Found {1} item(s) in the recycle bins' -f $site.Url, $recycleBinItems.Count) -InformationAction Continue;

  # Foreach recycle bin item.
  foreach ($recycleBinItem in $recycleBinItems)
  {
    # Create a new object to store the item information.
    $result = [PSCustomObject]@{
      SiteUrl        = $site.Url;
      ItemTitle      = $recycleBinItem.Title;
      ItemType       = $recycleBinItem.ItemType;
      DeletedByEmail = $recycleBinItem.DeletedByEmail;
      DeletedByName  = $recycleBinItem.DeletedByName;
      DeletedDate    = $recycleBinItem.DeletedDate;
      DeletedFrom    = $recycleBinItem.DirName;
      LeafName       = $recycleBinItem.LeafName;
      FullPath       = ('{0}/{1}/{2}' -f $sharePointTenantUrl, $recycleBinItem.DirName, $recycleBinItem.LeafName);
      RecycleBin     = $recycleBinItem.ItemState;
    };

    # Add to results.
    $results += $result;
  }

  # Write to log.
  Write-Information -MessageData ("[{0}] Removing '{1}' as site collection administrator" -f $site.Url, $currentUser.Email) -InformationAction Continue;

  # Remove the current user as a site collection administrator.
  Remove-PnPSiteCollectionAdmin `
    -Owners $currentUser.UserPrincipalName `
    -Connection $pnpSiteConnection `
    -WarningAction SilentlyContinue;
}

# Write to log.
Write-Information -MessageData ('Disconnecting from Sharepoint Online') -InformationAction Continue;

# Disconnect from SharePoint Online.
$pnpConnection, $pnpSiteConnection = $null;

# Write to log.
Write-Information -MessageData ("Exporting results to '{0}'" -f $ExportFilePath) -InformationAction Continue;

# Export results to CSV.
$null = $results | Export-Csv `
  -Path $ExportFilePath `
  -NoTypeInformation `
  -Force `
  -Encoding UTF8;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Information -MessageData ("Remember to remove the Entra ID application with ID '{1}' called '{1}'" -f $applicationId, $pnpOnlineApplicationName) -InformationAction Continue;
Write-Information -MessageData ('Script finished - {0}' -f (Get-Date)) -InformationAction Continue;

############### Finalize - End ###############
#endregion
