#Requires -version 7;

<#
.SYNOPSIS
  Get latest restore timestamp for all containers in a Cosmos DB account.

.DESCRIPTION
  Uses the Cosmos DB SQL API to get the latest restore timestamp for all containers in a Cosmos DB account.

.Parameter AccountName
  The name of the Cosmos DB account.

.Example
   .\Get-CosmosDbAccountLastestRestoreTimestamp.ps1 -AccountName "myCosmosDbAccount";

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  17-11-2023
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

param
(
    [Parameter(Mandatory = $true)][string]$AccountName
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

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

# Get Azure resource.
$azureResource = Get-AzResource -ResourceName $AccountName -ResourceType "Microsoft.DocumentDB/databaseAccounts";

# If the resource dont exist.
if ($null -eq $azureResource)
{
    # Throw execption.
    throw ("[{0}] The Cosmos DB account does not exist" -f $AccountName)
}

# Get Azure context.
$azureContext = Get-AzContext;

# Get Azure token (to pass on in the parallel task).
$accessToken = (Get-AzAccessToken -ResourceUrl "https://management.core.windows.net/");

# Get Cosmos DB backup policy.
$cosmosDbBackupPolicy = (Get-AzCosmosDBAccount -ResourceGroupName $azureResource.ResourceGroupName  `
        -Name $azureResource.Name).BackupPolicy;

# If the backup policy is not continuous.
if ($cosmosDbBackupPolicy.BackupType -ne "Continuous")
{
    # Throw execption.
    throw ("[{0}] The Cosmos DB account does not have continuous backup" -f $AccountName)
}

# Check if Cosmos DB account have enabled backup (point-in-time).
if ($azureResource.Properties.enableBackup -eq $false)
{
    # Throw execption.
    throw ("[{0}] The Cosmos DB account does not have enabled backup (point-in-time)" -f $AccountName)
}

# Object array with restore timestamp.
$restoreTimestamps = New-Object System.Collections.ArrayList;

# Write to log.
Write-Host ("[{0}] Getting all databases" -f $AccountName);

# Get Cosmos DB SQL API database.
$cosmosDbSqlApiDatabases = Get-AzCosmosDBSqlDatabase -ResourceGroupName $azureResource.ResourceGroupName  `
    -AccountName $azureResource.Name;

# Foreach database.
foreach ($cosmosDbSqlApiDatabase in $cosmosDbSqlApiDatabases)
{
    # Write to log.
    Write-Host ("[{0}][{1}] Getting all containers" -f $AccountName, $cosmosDbSqlApiDatabase.Name);

    # Get all containers.
    $cosmosDbSqlApiContainers = Get-AzCosmosDBSqlContainer -ResourceGroupName $azureResource.ResourceGroupName  `
        -AccountName $azureResource.Name  `
        -DatabaseName $cosmosDbSqlApiDatabase.Name;

    # Foreach container in parallel.
    $restoreTimestamps += $cosmosDbSqlApiContainers | ForEach-Object -ThrottleLimit 20 -Parallel {
        # Connect to Azure.
        Connect-AzAccount -AccessToken $Using:accessToken.Token -AccountId $Using:accessToken.UserId -Tenant $Using:accessToken.TenantId -Subscription $Using:azureContext.Subscription.Name -WarningAction SilentlyContinue | Out-Null;
        
        # Write to log.
        Write-Host ("[{0}][{1}][{2}] Trying to get latest restore timestamp" -f $Using:azureResource.Name, $Using:cosmosDbSqlApiDatabase.Name, $PSItem.Name);

        # Get latest restore timestamp.
        $restoreTimeStamp = Get-AzCosmosDBSqlContainerBackupInformation -ResourceGroupName $Using:azureResource.ResourceGroupName `
            -Location $Using:azureResource.Location `
            -AccountName $Using:azureResource.Name `
            -DatabaseName $Using:cosmosDbSqlApiDatabase.Name `
            -Name $PSItem.Name;

        # Write to log.
        Write-Host ("[{0}][{1}][{2}] Latest time stamp is '{3}'" -f $Using:azureResource.Name, $Using:cosmosDbSqlApiDatabase.Name, $PSItem.Name, $latestRestoreTimeStamp.LatestRestorableTimestamp);

        # Create object.
        $containerRestore = New-Object PSObject -Property @{
            AccountName            = $Using:azureResource.Name;
            DatabaseName           = $Using:cosmosDbSqlApiDatabase.Name;
            ContainerName          = $PSItem.Name;
            LatestRestoreTimestamp = $restoreTimeStamp.LatestRestorableTimestamp;
        };

        # Return object.
        return $containerRestore;
    };
}

# Sort latest restore timestamp.
$restoreTimestamps = $restoreTimestamps | Sort-Object -Property LatestRestoreTimestamp -Descending;

# Get latest restore timestamp.
$latestRestoreTimestamp = $restoreTimestamps[0];

# Write to log.
Write-Host ("[{0}] Latest restore timestamp is '{1}' (UTC)" -f $AccountName, $latestRestoreTimestamp.LatestRestoreTimestamp.ToUniversalTime());

# Return timestamp.
return $latestRestoreTimestamp.LatestRestoreTimestamp.ToUniversalTime();

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
