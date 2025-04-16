#Requires -Module 'PnP.PowerShell';
#Requires -Version 7.4.4;

# Variables.
$spoAdminUrl = 'https://contoso-admin.sharepoint.com';
$tenantId = '<Entra tenant ID>';
$pnpOnlineApplicationName = ('PnpOnline_{0}' -f (Get-Random));
$exportFilePath = ('{0}\sharepointReport.csv' -f [Environment]::GetFolderPath('Desktop'));

# Register the PnP Online as an application in Entra.
$entraIdApp = Register-PnPEntraIDAppForInteractiveLogin `
    -Tenant $tenantId `
    -ApplicationName $pnpOnlineApplicationName `
    -SharePointDelegatePermissions 'AllSites.FullControl' `
    -Interactive `
    -WarningAction SilentlyContinue `
    -ErrorAction Stop;

# Get the application ID.
$applicationId = $entraIdApp.'AzureAppId/ClientId';

# If the application ID is not null, then we can proceed.
if ($null -eq $applicationId)
{
    # Write to log and exit.
    Write-Warning ('Unable to register the PnP Online application in Entra');

    # Throw an error.
    throw ('Unable to register the PnP Online application in Entra, aborting script');
}

# Connect to SharePoint Online.
$pnpConnection = Connect-PnPOnline `
    -Url $spoAdminUrl `
    -ReturnConnection `
    -Interactive `
    -ApplicationId $applicationId `
    -WarningAction SilentlyContinue;

# Get all sites in the tenant.
$sites = Get-PnPTenantSite `
    -Connection $pnpConnection `
    -Detailed `
    -WarningAction SilentlyContinue;

# Results object.
$results = @();

# Foreach site.
foreach ($site in $sites)
{
    # Create a new object to store the site information.
    $result = [PSCustomObject]@{
        Title                        = $site.Title;
        Url                          = $site.Url;
        Owner                        = $site.OwnerEmail;
        StorageMB                    = $site.StorageUsageCurrent;
        Template                     = $site.Template;
        IsTeamsConnected             = $site.IsTeamsConnected;
        IsTeamsChannelConnected      = $site.IsTeamsChannelConnected;
        IsHubSite                    = $site.IsHubSite;
        IsMicrosoft365GroupConnected = $false;
        TeamsChannelType             = $site.TeamsChannelType;
        SharingCapability            = $site.SharingCapability;
        GroupId                      = $site.GroupId;
        NumberOfSubsites             = $site.WebsCount;
        LockState                    = $site.LockState;
    };

    # If the site is connected to a Microsoft 365 group.
    if (
        $null -ne $site.GroupId -and
        $site.GroupId -ne '00000000-0000-0000-0000-000000000000')
    {
        # Set group connected to true.
        $result.IsMicrosoft365GroupConnected = $true;
    }

    # Add to results.
    $results += $result;
}

# Count expressions.
$teamsConnected = $results | Where-Object { $_.IsTeamsConnected -eq $true };
$teamsChannelConnected = $results | Where-Object { $_.IsTeamsChannelConnected -eq $true };
$m365GroupConnected = $results | Where-Object { $_.IsMicrosoft365GroupConnected -eq $true };
$totalUsedStorageInMB = ($results | Measure-Object -Property StorageMB -Sum).Sum;
$totalUsedStorageInGB = [math]::Round(($totalUsedStorageInMB / 1024), 0);
$totalUsedStorageInTB = [math]::Round(($totalUsedStorageInMB / 1024 / 1024), 2);
$numberOfHubSites = $results | Where-Object { $_.IsHubSite -eq $true };

# Write to log.
Write-Information -MessageData ('Number of sites: {0}' -f $results.Count) -InformationAction Continue;
Write-Information -MessageData ('Number of sites that is Microsoft Teams connected: {0}' -f $teamsConnected.Count) -InformationAction Continue;
Write-Information -MessageData ('Number of sites that is Microsoft Teams Channel connected: {0}' -f $teamsChannelConnected.Count) -InformationAction Continue;
Write-Information -MessageData ('Number of sites that is Microsoft 365 group connected: {0}' -f $m365GroupConnected.Count) -InformationAction Continue;
Write-Information -MessageData ('Number of sites that is a hub site: {0}' -f $numberOfHubSites.Count) -InformationAction Continue;
Write-Information -MessageData ('Total used spaces across all sites: {0} MB / {1} GB / {2} TB' -f $totalUsedStorageInMB, $totalUsedStorageInGB, $totalUsedStorageInTB) -InformationAction Continue;
Write-Information -MessageData ('') -InformationAction Continue;
Write-Information -MessageData ("Exporting result to '{0}'" -f $exportFilePath) -InformationAction Continue;

# Export to CSV.
$null = $results | Export-Csv `
    -Path $exportFilePath `
    -NoTypeInformation `
    -Delimiter ';' `
    -UseQuotes Always `
    -Force `
    -Encoding UTF8;
