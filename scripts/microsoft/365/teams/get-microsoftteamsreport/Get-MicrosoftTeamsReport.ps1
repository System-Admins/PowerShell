#Requires -Module MicrosoftTeams, Microsoft.Graph.Reports, Microsoft.Graph.Identity.DirectoryManagement;
#Requires -Version 7.4.4;

<#
.SYNOPSIS
    Generate Microsoft Teams report.

.DESCRIPTION
    This script generates a report of Microsoft Teams and SharePoint Online activity in the tenant.
    It connects to Microsoft Graph and retrieves activity data for Microsoft Teams and SharePoint Online.
    The report includes information about Microsoft Teams, channels, members, and SharePoint sites.
    The report is exported to a CSV file.
    The script requires the following Graph API permissions:
    Reports.Read.All, Sites.Read.All, DeviceManagementServiceConfig.Read.All.
    The script also registers a PnP Online application in Entra ID for interactive login.
    The application is registered with the following permissions:
    AllSites.FullControl.

.PARAMETER ExportFilePath
    The file path to export the results to.
    Default is the desktop with a timestamp.

.EXAMPLE
    .\Get-MicrosoftTeamsReport.ps1;

.EXAMPLE
    .\Get-MicrosoftTeamsReport.ps1 -ExportFilePath 'C:\Temp\MicrosoftTeamsReport.csv';

.NOTES
    Version:        1.0
    Author:         Alex Hansen (ath@systemadmins.com)
    Creation Date:  01-05-2025
    Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]
param
(
    # Export file path for results.
    [Parameter(Mandatory = $false, Position = 5)]
    [string]$ExportFilePath = ('{0}\MicrosoftTeams-Report-{1:yyyyMMdd-HHmmss}.csv' -f ([Environment]::GetFolderPath('Desktop')), (Get-Date))
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
    -Name MicrosoftTeams, Microsoft.Graph.Reports, Microsoft.Graph.Identity.DirectoryManagement `
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

# Connect to Microsoft Graph.
$null = Connect-MgGraph `
    -Scopes @('Reports.Read.All', 'Sites.Read.All') `
    -ErrorAction Stop `
    -NoWelcome;

# Write to log.
Write-Information -MessageData ('Getting all activity data for the Microsoft Teams and SharePoint Online in the tenant') -InformationAction Continue;

# Temporary file path to store the activity data.
$msTeamsActivityFilePath = ('{0}\{1}_msTeamsActivity.csv' -f $env:temp, (New-Guid).Guid);
$spoActivityFilePath = ('{0}\{1}_spoActivity.csv' -f $env:temp, (New-Guid).Guid);

# Get all activity data for the Microsoft Teams and SharePoint Online in the tenant.
$null = Get-MgReportTeamActivityDetail -Period 'D90' -OutFile $msTeamsActivityFilePath;
$null = Get-MgReportSharePointSiteUsageDetail -Period 'D90' -OutFile $spoActivityFilePath;

# Import the activity data from the temporary files.
$msTeamActivityDetails = Import-Csv -Path $msTeamsActivityFilePath -Delimiter ',' -Encoding utf8 -ErrorAction Stop;
$spoActivityDetails = Import-Csv -Path $spoActivityFilePath -Delimiter ',' -Encoding utf8 -ErrorAction Stop;

# Get tenant id.
$organization = Get-MgOrganization;

# Write to log.
Write-Information -MessageData ('Connecting to Microsoft Teams');

# Connect to Microsoft Teams.
$null = Connect-MicrosoftTeams -Confirm:$false -ErrorAction Stop;

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

# Write to log.
Write-Information -MessageData ('Getting all Microsoft Teams in the tenant') -InformationAction Continue;

# Get all Microsoft Teams in the tenant.
$msTeams = Get-Team;

# Write to log.
Write-Information -MessageData ('Found {0} created Microsoft Teams' -f $msTeams.Count) -InformationAction Continue;
Write-Information -MessageData ('Getting all SharePoint Online sites in the tenant') -InformationAction Continue;

# Get all SharePoint Online sites in the tenant.
$spoSites = Get-PnPTenantSite `
    -Connection $pnpConnection `
    -Detailed `
    -ErrorAction Stop;

# Result object.
$results = @();

# Write to log.
Write-Information -MessageData ('Enumerating all Microsoft Teams in the tenant') -InformationAction Continue;

# Forach Microsoft Team.
foreach ($msTeam in $msTeams)
{
    # Write to log.
    Write-Information -MessageData ('[+] Team: {0}' -f $msTeam.MailNickName) -InformationAction Continue;

    # Create a new object.
    $result = [PSCustomObject]@{
        Id                         = $msTeam.InternalId;
        Microsoft365GroupId        = $msTeam.GroupId;
        MailNickName               = $msTeam.MailNickName;
        DisplayName                = $msTeam.DisplayName;
        Visibility                 = $msTeam.Visibility;
        Classification             = $msTeam.Classification;
        Archived                   = $msTeam.Archived;
        ChannelsCount              = 0;
        ChannelsActive             = $null;
        ChannelsMessageCount       = $null;
        UniqueMembersCount         = 0;
        MembersActive              = 0;
        GuestsCount                = $null;
        ExternalActiveCount        = $null;
        LastActivityDate           = $null;
        SharePointUrl              = $null;
        SharePointFilesCount       = $null;
        SharePointActiveFilesCount = $null;
        SharePointStorageUsageGB   = $null;
        SharePointLastActivityDate = $null;
        SharePointPageViewCount    = $null;
        SharePointTemplate         = $null;
    };

    # Match the Microsoft Team with the activity data.
    $msTeamActivityDetail = $msTeamActivityDetails | Where-Object { $_.'Team Id' -eq $msTeam.GroupId };

    # If the Microsoft Team activity data is not empty.
    if ($null -ne $msTeamActivityDetail)
    {
        # Update result object.
        $result.ChannelsActive = $msTeamActivityDetail.'Active Channels';
        $result.MembersActive = $msTeamActivityDetail.'Active Users';
        $result.ChannelsMessageCount = $msTeamActivityDetail.'Channel Messages';
        $result.GuestsCount = $msTeamActivityDetail.'Guests';
        $result.ExternalActiveCount = $msTeamActivityDetail.'Active External Users';

        # If last activity date is not empty.
        if (-not [string]::IsNullOrEmpty($msTeamActivityDetail.'Last Activity Date') )
        {
            # Convert to datetime.
            $result.LastActivityDate = [datetime]::ParseExact(($msTeamActivityDetail.'Last Activity Date'), 'yyyy-MM-dd', $null);
        }
    }

    # Match the SharePoint sites.
    $spoSite = $spoSites | Where-Object { $_.GroupId -eq $msTeam.GroupId };

    # If the Microsoft 365 group is not empty.
    if ($null -ne $spoSite)
    {
        # Get SharePoint activity detail for site.
        $spoActivityDetail = $spoActivityDetails | Where-Object { $_.'Site Id' -eq $spoSite.SiteId.Guid };

        # Update result properties.
        $result.SharePointUrl = $spoSite.Url;
        $result.SharePointFilesCount = $spoActivityDetail.'File Count';
        $result.SharePointActiveFilesCount = $spoActivityDetail.'Active File Count';
        $result.SharePointStorageUsageGB = $spoActivityDetail.'Storage Used (Byte)' / 1GB;
        $result.SharePointPageViewCount = $spoActivityDetail.'Page View Count';
        $result.SharePointTemplate = $spoActivityDetail.'Root Web Template';

        # If last activity date is not empty.
        if (-not [string]::IsNullOrEmpty($spoActivityDetail.'Last Activity Date') )
        {
            # Convert to datetime.
            $result.SharePointLastActivityDate = [datetime]::ParseExact(($spoActivityDetail.'Last Activity Date'), 'yyyy-MM-dd', $null);
        }
    }

    # Get all channels in the Microsoft Team.
    $channels = Get-TeamAllChannel -GroupId $msTeam.GroupId;

    # Get number of channels in the Microsoft Team.
    $result.ChannelsCount = $channels.Count;

    # Members of the Microsoft Team.
    $members = @();

    # Foreach channel in the Microsoft Team.
    foreach ($channel in $channels)
    {
        # Get all users in the Microsoft Team channel.
        $channelUsers = Get-TeamChannelUser `
            -GroupId $msTeam.GroupId `
            -DisplayName $channel.DisplayName;

        # Foreach user in the channel.
        foreach ($channelUser in $channelUsers)
        {
            # If the user is not already in the list, add it.
            if ($members -notcontains $channelUser.UserId)
            {
                # Add the user to the list of members.
                $members += $channelUser.UserId;
            }
        }
    }

    # Update the number of members in the Microsoft Team.
    $result.UniqueMembersCount = $members.Count;

    # Add the result to the results array.
    $results += $result;
}

# Write to log.
Write-Information -MessageData ('Disconnecting from Sharepoint Online') -InformationAction Continue;

# Disconnect from SharePoint Online.
$pnpConnection = $null;

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
