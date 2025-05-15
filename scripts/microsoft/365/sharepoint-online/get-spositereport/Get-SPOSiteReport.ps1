#Requires -Module Microsoft.Graph.Reports, Microsoft.Graph.Identity.DirectoryManagement;
#Requires -Version 7.4.4;

<#
.SYNOPSIS
    Generate Microsoft SharePoint report.

.DESCRIPTION
    This script generates a report for Microsoft SharePoint Online sites in the tenant.
    It retrieves activity data from Microsoft Graph and connects to SharePoint Online using PnP PowerShell.
    The report includes information about each site, such as URL, title, owner, template, status, and activity data.

.PARAMETER ExportFilePath
    The file path to export the results to.
    Default is the desktop with a timestamp.

.EXAMPLE
    .\Get-SharePointOnlineReport.ps1;

.EXAMPLE
    .\Get-SharePointOnlineReport -ExportFilePath 'C:\Temp\MicrosoftTeamsReport.csv';

.NOTES
    Version:        1.0
    Author:         Alex Hansen (ath@systemadmins.com)
    Creation Date:  02-05-2025
    Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]
param
(
    # Export file path for results.
    [Parameter(Mandatory = $false, Position = 5)]
    [string]$ExportFilePath = ('{0}\SharePointOnline-Report-{1:yyyyMMdd-HHmmss}.csv' -f ([Environment]::GetFolderPath('Desktop')), (Get-Date))
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

# Check if Pnp.PowerShell module is installed.
if (-not (Get-Module -Name PnP.PowerShell -ListAvailable))
{
    # Throw exeption.
    throw ('PnP PowerShell module is not installed');
}

# Import modules.
Import-Module `
    -Name Microsoft.Graph.Reports, Microsoft.Graph.Identity.DirectoryManagement `
    -DisableNameChecking `
    -Force `
    -ErrorAction Stop `
    -WarningAction SilentlyContinue;

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
Write-Information -MessageData ('Connecting to Microsoft Graph') -InformationAction Continue;

# Disconnect from Microsoft Graph.
$null = Disconnect-MgGraph -ErrorAction SilentlyContinue;

# Connect to Microsoft Graph.
$null = Connect-MgGraph `
    -Scopes @('Reports.Read.All', 'Sites.Read.All', 'User.Read.All') `
    -ErrorAction Stop `
    -NoWelcome;

# Write to log.
Write-Information -MessageData ('Getting all activity data for the SharePoint Online in the tenant') -InformationAction Continue;

# Temporary file path to store the activity data.
$spoActivityFilePath = ('{0}\{1}_spoActivity.csv' -f $env:temp, (New-Guid).Guid);

# Get all activity data for the SharePoint Online in the tenant.
$null = Get-MgReportSharePointSiteUsageDetail -Period 'D90' -OutFile $spoActivityFilePath;

# Import the activity data from the temporary files.
$spoActivityDetails = Import-Csv -Path $spoActivityFilePath -Delimiter ',' -Encoding utf8 -ErrorAction Stop;

# Get tenant id.
$organization = Get-MgOrganization;

# Import the PnP PowerShell module (https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/2285).
Import-Module `
    -Name PnP.PowerShell `
    -DisableNameChecking `
    -Force `
    -ErrorAction Stop `
    -WarningAction SilentlyContinue;

# Write to log.
Write-Information -MessageData ('Trying to register app in Entra ID for PnP Online') -InformationAction Continue;
Write-Information -MessageData ('Please login with a global admin account, the login prompt may be hidden') -InformationAction Continue;
Write-Information -MessageData ('Login prompt will appear twice, and a consent is needed for the application') -InformationAction Continue;

# Register the PnP Online as an application in Entra.
$entraIdApp = Register-PnPEntraIDAppForInteractiveLogin `
    -Tenant $organization.Id `
    -ApplicationName $pnpOnlineApplicationName `
    -SharePointDelegatePermissions 'AllSites.FullControl'`
    -WarningAction SilentlyContinue `
    -ErrorAction Stop;

# Get the application ID.
$pnpApplicationId = $entraIdApp.'AzureAppId/ClientId';

# If the Pnp.PowerShell application ID is null.
if ($null -eq $pnpApplicationId)
{
    # Throw an error.
    throw ('Unable to register the PnP Online application in Entra, aborting script');
}

# Get the tenant SharePoint Online site URL.
$spoSiteRoot = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/sites/root' -Method GET -OutputType PSObject;

# Add -admin before .sharepoint.com to get the admin site URL.
$spoAdminUrl = $spoSiteRoot.webUrl -replace '\.sharepoint\.com', '-admin.sharepoint.com';

# Connect to SharePoint Online using PnP PowerShell.
$pnpConnection = Connect-PnPOnline `
    -Url $spoAdminUrl `
    -ClientId $pnpApplicationId `
    -Tenant $organization.Id `
    -Interactive `
    -ReturnConnection `
    -ErrorAction Stop;

# Get current user.
$ctx = Get-PnPContext -Connection $pnpConnection;
$ctx.Load($ctx.Web.CurrentUser);
$ctx.ExecuteQuery();
$currentUser = $ctx.Web.CurrentUser;

# Write to log.
Write-Information -MessageData ('Getting all SharePoint Online sites in the tenant') -InformationAction Continue;

# Get all SharePoint Online sites in the tenant.
$spoSites = Get-PnPTenantSite `
    -Connection $pnpConnection `
    -Detailed `
    -ErrorAction Stop;

# Get the site collection web application.
$spoWebApp = Get-PnPWeb `
    -Connection $pnpConnection `
    -Includes 'RegionalSettings.InstalledLanguages';

# Result object.
$results = @();

# Write to log.
Write-Information -MessageData ('Enumerating all SharePoint sites in the tenant') -InformationAction Continue;

# Forach SharePoint site.
foreach ($spoSite in $spoSites)
{
    # If the site template is redirect.
    if ($spoSite.Template -in 'RedirectSite#0', 'EHS#1', 'SRCHCEN#0', 'APPCATALOG#0', 'POINTPUBLISHINGTOPIC#0', 'POINTPUBLISHINGHUB#0')
    {
        # Continue to next site. 
        continue; 
    }

    # Write to log.
    Write-Information -MessageData ('[+] Site: {0}' -f $spoSite.Url) -InformationAction Continue;

    # Create a new object.
    $result = [PSCustomObject]@{
        Id                      = $spoSite.SiteId.Guid;
        Url                     = $spoSite.Url;
        Title                   = $spoSite.Title;
        Owner                   = '';
        Template                = $spoSite.Template;
        LocaleId                = $spoSite.LocaleId;
        LanguageName            = '';
        LanguageTag             = '';
        TimeZoneId              = '';
        TimeZoneDescription     = '';
        Status                  = $spoSite.Status;
        ArchiveStatus           = $spoSite.ArchiveStatus;
        SubsiteCount            = $spoSite.WebsCount;
        IsHubSite               = $spoSite.IsHubSite;
        IsTeamsChannelConnected = $spoSite.IsTeamsChannelConnected;
        IsTeamsConnected        = $spoSite.IsTeamsConnected;
        IsUsedInTeams           = $false;
        IsConnectedToM365Group  = $false;
        TeamsChannelType        = $spoSite.TeamsChannelType;
        GroupId                 = $spoSite.GroupId.Guid;
        InformationBarrierMode  = $spoSite.InformationBarrierMode;
        LastActivityDate        = [datetime]::MinValue;
        FileCount               = 0;
        ActiveFileCount         = 0;
        VisitedPageCount        = 0;
        PageViewCount           = 0;
        StorageUsedinGB         = 0;
        StorageUsedinMB         = 0;
    };

    # If either IsTeamsChannelConnected or IsTeamsConnected is true.
    if ($spoSite.IsTeamsChannelConnected -or $spoSite.IsTeamsConnected)
    {
        # Set IsUsedInTeams to true.
        $result.IsUsedInTeams = $true;
    }

    # If the site is connected to a Microsoft 365 group.
    if ($spoSite.GroupId -ne [Guid]::Empty -or $spoSite.RelatedGroupId -ne [Guid]::Empty)
    {
        # Set IsConnectedToM365Group to true.
        $result.IsConnectedToM365Group = $true;
    }

    # Match the site with the activity data.
    $spoActivityDetail = $spoActivityDetails | Where-Object { $_.'Site Id' -eq $spoSite.SiteId };

    # Update the result object with the activity data.
    $result.FileCount = $spoActivityDetail.'File Count';
    $result.ActiveFileCount = $spoActivityDetail.'Active File Count';
    $result.PageViewCount = $spoActivityDetail.'Page View Count';
    $result.VisitedPageCount = $spoActivityDetail.'Visited Page Count';
    $result.StorageUsedinGB = [math]::Round($spoActivityDetail.'Storage Used (Byte)' / 1GB, 0);
    $result.StorageUsedinMB = [math]::Round($spoActivityDetail.'Storage Used (Byte)' / 1MB, 0);
    $result.Owner = $spoActivityDetail.'Owner Principal Name';

    # If the activity data is not null.
    if (-not [string]::IsNullOrEmpty($spoActivityDetail.'Last Activity Date'))
    {
        # Convert to datetime.
        $result.LastActivityDate = [datetime]::ParseExact($spoActivityDetail.'Last Activity Date', 'yyyy-MM-dd', $null);
    }
    # If the activity data is null.
    else
    {
        # Convert to datetime.
        $result.LastActivityDate = [datetime]::MinValue;
    }

    # Get language.
    $language = ($spoWebApp.RegionalSettings.InstalledLanguages | Where-Object { $_.LCID -eq $spoSite.LocaleId });

    # Update result object with language data.
    $result.LanguageName = $language.DisplayName;
    $result.LanguageTag = $language.LanguageTag;

    # Add current user as a site collection administrator.
    $null = Set-PnPTenantSite `
        -Identity $spoSite.Url `
        -Owners $currentUser.UserPrincipalName `
        -Connection $pnpConnection `
        -WarningAction SilentlyContinue `
        -ErrorAction SilentlyContinue;

    # Connect to the site.
    $pnpSiteConnection = Connect-PnPOnline `
        -Url $spoSite.Url `
        -Connection $pnpConnection `
        -Interactive `
        -ClientId $pnpConnection.ClientId `
        -ReturnConnection `
        -WarningAction SilentlyContinue;

    # Get the site collection web application for the site.
    $spoWebAppSite = Get-PnPWeb `
        -Connection $pnpSiteConnection `
        -Includes @('RegionalSettings', 'RegionalSettings.TimeZone');

    # Update result object with time zone data.
    $result.TimeZoneId = $spoWebAppSite.RegionalSettings.TimeZone.Id;
    $result.TimeZoneDescription = $spoWebAppSite.RegionalSettings.TimeZone.Description;

    # Add the result to the results array.
    $results += $result;

    # Remove the current user as a site collection administrator.
    Remove-PnPSiteCollectionAdmin `
        -Owners $currentUser.UserPrincipalName `
        -Connection $pnpSiteConnection `
        -WarningAction SilentlyContinue `
        -ErrorAction SilentlyContinue;
}

# Write to log.
Write-Information -MessageData ('Disconnecting from Sharepoint Online') -InformationAction Continue;

# Disconnect from SharePoint Online and Graph.
$pnpConnection, $pnpSiteConnection = $null;
$null = Disconnect-MgGraph -ErrorAction SilentlyContinue;

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
