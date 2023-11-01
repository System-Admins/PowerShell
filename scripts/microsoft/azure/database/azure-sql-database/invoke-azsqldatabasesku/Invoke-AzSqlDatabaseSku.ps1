#Requires -Version 5.1;
#Requires -Modules Az.Accounts, Az.Resources, Az.Sql;

<#
.SYNOPSIS
  This script will check if Azure SQL databases are using the correct SKU based on the size of the database.

.DESCRIPTION
  Finds the lowest valid SKU for a Azure SQL databases. Uses a combination of REST API and PowerShell cmdlets to find the lowest valid SKU.

.Parameter Location
  The Azure location to check for Azure SQL database capabilities (available SKUs), such as "westeurope".

.Parameter ServerName
  The Azure SQL server name to check.

.PARAMETER DatabaseName
  The Azure SQL database name to check.

.PARAMETER All
  If all Azure SQL databases should be checked.

.PARAMETER PriorityList
  The priority list of SKUs to use when checking for a new SKU.
  Currently the list is as follows:
    1. Basic
    2. Standard
    3. Premium
    4. GeneralPurpose
    5. Hyperscale
    6. BusinessCritical

.PARAMETER Update
  If the script should update the Azure SQL database to the suggested SKU.

.PARAMETER Update
  If the script should update the Azure SQL database to the suggested SKU.

.Example
  # Get specific Azure SQL database and check if it's using the correct SKU.
  .\Untitled-3.ps1 -Location "westeurope" -ServerName "<sqlserver>" -DatabaseName "<sqldatabase>";

.Example
  # Get all Azure SQL databases and check if it's using the correct SKU.
  .\Untitled-3.ps1 -Location "westeurope" -All;

.Example
  # Update Azure SQL database SKU based on findings.
  .\Untitled-3.ps1 -Location "westeurope" -All -Update;

.Example
  # Export findings to a CSV-file.
  .\Untitled-3.ps1 -Location "westeurope" -All -OutputFilePath "C:\temp\output.csv";

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  01-11-2023
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding(DefaultParameterSetName = 'All')]
param
(
    [Parameter(Mandatory = $false)][string]$Location = "westeurope",
    [Parameter(Mandatory = $true, ParameterSetName = 'Database')][string]$ServerName,
    [Parameter(Mandatory = $true, ParameterSetName = 'Database')][string]$DatabaseName,
    [Parameter(Mandatory = $false, ParameterSetName = 'All')][switch]$All,
    [Parameter(Mandatory = $false)][string[]]$PriorityList = @("Basic", "Standard", "Premium", "GeneralPurpose", "Hyperscale", "BusinessCritical"),
    [Parameter(Mandatory = $false)][switch]$Update = $false,
    [Parameter(Mandatory = $false)][string]$OutputFilePath = $null
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

# Write to log.
function Write-Log
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)][string]$Message
    )

    # Write to log.
    Write-Information -MessageData ("[{0}]: {1}" -f (Get-Date).ToString("dd-MM-yyyy HH:mm:ss"), $Message) -InformationAction Continue;
}

# Get the size of a Azure SQL database.
function Get-AzureSqlDatabaseSize
{
    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)][string]$ServerName,
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $false)][ValidateSet("Bytes", "Kilobytes", "Megabytes", "Gigabytes")][string]$SizeUnit = "Gigabytes"
    )

    # Get Azure resource.
    $resource = Get-AzResource -Name ("{0}/{1}" -f $ServerName, $DatabaseName);

    # If resource is not found, throw an error.
    if ($null -eq $resource)
    {
        throw "Resource not found";
    }

    # Try to get storage metric.
    try
    {
        # Get the storage metric.
        $metric = Get-AzMetric -ResourceId $resource.Id `
            -MetricName "storage" `
            -WarningAction SilentlyContinue -ErrorAction Stop;

        # Get size in bytes.
        $size = $metric.Data[$metric.Data.Count - 2].Maximum / 1024 / 1024;

        # Return object.
        return $size;
    }
    # Something went wrong while getting storage metric.
    catch
    {
        # Write to log.
        Write-Log ("Error getting storage usage data from Azure SQL database '{0}/{1}'" -f $ServerName, $DatabaseName);
    }
}

# Get the capabilities of a Azure SQL database.
function Get-AzureSqlDatabaseCapabilities
{
    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)][string]$AccessToken,
        [Parameter(Mandatory = $true)][string]$SubscriptionId,
        [Parameter(Mandatory = $true)][string]$Location
    )

    # Create the URI.
    $uri = ("https://management.azure.com/subscriptions/{0}/providers/Microsoft.Sql/locations/{1}/capabilities?api-version=2023-02-01-preview" -f $SubscriptionId, $Location);

    # Create the headers.
    $headers = @{
        Authorization = ("Bearer {0}" -f $AccessToken);
    };

    # Try to invoke the REST API.
    try
    {
        # Invoke the REST API.
        $response = Invoke-RestMethod -Uri $uri `
            -Headers $headers `
            -Method Get `
            -ContentType "application/json";

        # Return the capabilities.
        return $response;
    }
    # Something went wrong getting the capabilities.
    catch
    {
        # Throw an error.
        throw ("Unable to get the capabilities of the Azure SQL server, execption is:`r`n" -f $_);
    }
}

# Get the storage sizes for Azure SQL Servers.
function Get-AzureSqlServerSkuStorageSize
{
    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]$Capabilities,
        [Parameter(Mandatory = $true)]$PriorityList
    )

    # Object array for SKU.
    $stockKeepingUnits = @();

    # Foreach Azure SQL Server.
    foreach ($supportedServerVersion in $capabilities.supportedServerVersions)
    {
        # Foreach edition.
        foreach ($supportedEdition in $supportedServerVersion.supportedEditions)
        {
            # If edition is not in priority list.
            if ($supportedEdition.name -notin $PriorityList)
            {
                # Skip to next edition.
                continue;
            }

            # Foreach SLO.
            foreach ($supportedServiceLevelObjective in $supportedEdition.supportedServiceLevelObjectives)
            {
                # Max size.
                [bigint]$maxSizeValueGigabytes = [int]::MinValue;
                [bigint]$maxSizeValueMegabytes = [int]::MinValue;

                # Foreach max supported max size.
                foreach ($supportedMaxSize in $supportedServiceLevelObjective.supportedMaxSizes)
                {
                    # Skip visible status.
                    if ($supportedMaxSize.status -eq "Visible")
                    {
                        # Skip to next size.
                        continue;
                    }

                    # If max size unit is megabytes.
                    if ($supportedMaxSize.maxValue.unit -eq "Megabytes")
                    {
                        # Convert to Gigabytes.
                        $minValueGigabytes = $supportedMaxSize.maxValue.limit / 1024;
                        $minValueMegabytes = $supportedMaxSize.maxValue.limit
                    }
                    # Else gigabytes.
                    elseif ($supportedMaxSize.maxValue.unit -eq "Gigabytes")
                    {
                        $minValueGigabytes = $supportedMaxSize.maxValue.limit
                        $minValueMegabytes = $supportedMaxSize.maxValue.limit * 1024;
                    }
                    # Else terabytes.
                    elseif ($supportedMaxSize.maxValue.unit -eq "Terabytes")
                    {
                        # Convert to Gigabytes.
                        $minValueGigabytes = $supportedMaxSize.maxValue.limit * 1024;
                        $minValueMegabytes = $supportedMaxSize.maxValue.limit * 1024 * 1024;
                    }

                    # If max value is greater than previous.
                    if ($minValueMegabytes -gt $maxSizeValueMegabytes)
                    {
                        # Update value.
                        $maxSizeValueGigabytes = $minValueGigabytes;
                        $maxSizeValueMegabytes = $minValueMegabytes;
                    }
                }

                # If tier is hyperscale.
                if ($supportedServiceLevelObjective.sku.tier -eq "Hyperscale")
                {
                    # Set to 100TB.
                    $maxSizeValueGigabytes = 100TB / 1GB;
                    $maxSizeValueMegabytes = 100TB / 1MB;
                }

                # If only add if the value is greater than "-2147483648".
                if ([int]::MinValue -ne $maxSizeValueMegabytes)
                {
                    # Add to object array.
                    $stockKeepingUnits += [PSCustomObject]@{
                        Name            = $supportedServiceLevelObjective.name;
                        SkuName         = $supportedServiceLevelObjective.sku.name;
                        SkuTier         = $supportedServiceLevelObjective.sku.tier;
                        SkuFamily       = $supportedServiceLevelObjective.sku.family;
                        SkuCapacity     = $supportedServiceLevelObjective.sku.capacity;
                        SkuCapacityUnit = $supportedServiceLevelObjective.performanceLevel.unit;
                        StorageSizeInGb = $maxSizeValueGigabytes;
                        StorageSizeInMb = $maxSizeValueMegabytes;
                    }
                }
            }
        }
    }

    # Return sizes.
    return $stockKeepingUnits;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log ("Script started");

# Get Azure access token.
$accessToken = (Get-AzAccessToken -ResourceUrl https://management.core.windows.net/).Token;

# If access token is empty.
if ($null -eq $accessToken)
{
    # Throw an error.
    throw ("Not able to get access token for Azure");
}

# Get subscription ID.
$subscription = (Get-AzContext).Subscription;

# Get all Azure locations.
$azureLocations = Get-AzLocation;

# If location is not found.
if ($null -eq ($azureLocations | Where-Object { $_.Location -eq $Location }))
{
    # Throw an error.
    Write-Log ("Valid locations are:`r`n{0}" -f (($azureLocations).Location -join ", "));
    throw ("Azure location '{0}' not found" -f $Location);
}

# Get the capabilities.
$capabilities = Get-AzureSqlDatabaseCapabilities -AccessToken $accessToken `
    -SubscriptionId $subscription.Id `
    -Location $Location;

# Get the storage sizes.
$storageSizes = Get-AzureSqlServerSkuStorageSize -Capabilities $capabilities -PriorityList $PriorityList;

# Databases object array.
$databases = @();

# If we should check all databases.
if ($true -eq $All)
{
    # Write to log.
    Write-Log ("[{0}] Getting all Azure SQL servers" -f $subscription.Name);

    # Get all Azure SQL servers.
    $azureSqlServers = Get-AzSqlServer;

    # Foreach Azure SQL server.
    foreach ($azureSqlServer in $azureSqlServers)
    {
        # Write to log.
        Write-Log ("[{0}][{1}] Getting all Azure SQL databases" -f $subscription.Name, $azureSqlServer.ServerName);
    
        # Get all databases on the server.
        $azureSqlDatabases = Get-AzSqlDatabase -ResourceGroupName $azureSqlServer.ResourceGroupName `
            -ServerName $azureSqlServer.ServerName
        
        # Filter out system databases.
        $azureSqlDatabases = $azureSqlDatabases | Where-Object { $_.CurrentServiceObjectiveName -notlike "System*" -and $_.DatabaseName -ne "master" };

        # Foreach database.
        foreach ($azureSqlDatabase in $azureSqlDatabases)
        {
            # If database is in elastic pool.
            if ($null -ne $azureSqlDatabase.ElasticPoolName)
            {
                # Write to log.
                Write-Log ("[{0}][{1}][{2}] Database is in elastic pool '{3}', skipping" -f $subscription.Name, $azureSqlDatabase.ServerName, $azureSqlDatabase.DatabaseName, $azureSqlDatabase.ElasticPoolName);
            
                # Skip to next database.
                continue;
            }

            # Get the size of the database.
            $azureSqlDatabaseSize = Get-AzureSqlDatabaseSize -ServerName $azureSqlServer.ServerName `
                -DatabaseName $azureSqlDatabase.DatabaseName;

            # If database size is empty.
            if ($null -eq $azureSqlDatabaseSize)
            {
                # Continue to next.
                continue;
            }

            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Current SKU is '{3}' and size is {4} megabytes" -f $subscription.Name, $azureSqlDatabase.ServerName, $azureSqlDatabase.DatabaseName, $azureSqlDatabase.CurrentServiceObjectiveName, ([Math]::Round($azureSqlDatabaseSize, 0)));
        
            # Add to object array.
            $databases += [PSCustomObject]@{
                SubscriptionName  = $subscription.Name;
                ResourceGroupName = $azureSqlDatabase.ResourceGroupName;
                ServerName        = $azureSqlDatabase.ServerName;
                DatabaseName      = $azureSqlDatabase.DatabaseName;
                SkuName           = $azureSqlDatabase.CurrentServiceObjectiveName;
                ElasticPool       = $azureSqlDatabase.ElasticPoolName;
                SizeInMb          = $azureSqlDatabaseSize;
            }
        }

        # If no databases is found.
        if ($null -eq $azureSqlDatabases)
        {
            # Write to log.
            Write-Log ("[{0}][{1}] No databases found" -f $subscription.Name, $azureSqlServer.ServerName);
        }
    }
}
# Else we should only check a single database.
else
{
    # Get Azure SQL server.
    $azureSqlServer = Get-AzSqlServer -ServerName $ServerName;

    # If server is not found.
    if ($null -eq $azureSqlServer)
    {
        # Throw an error.
        throw ("Azure SQL server '{0}' not found" -f $ServerName);
    }

    # Get Azure SQL database.
    $azureSqlDatabase = Get-AzSqlDatabase -ResourceGroupName $azureSqlServer.ResourceGroupName `
        -ServerName $azureSqlServer.ServerName `
        -DatabaseName $DatabaseName;

    # If database is not found.
    if ($null -eq $azureSqlDatabase)
    {
        # Throw an error.
        throw ("Azure SQL database '{0}' not found" -f $DatabaseName);
    }

    # Get the size of the database.
    $azureSqlDatabaseSize = Get-AzureSqlDatabaseSize -ServerName $azureSqlServer.ServerName `
        -DatabaseName $azureSqlDatabase.DatabaseName;

    # If database size is empty.
    if ($null -eq $azureSqlDatabaseSize)
    {
        # Continue to next.
        continue;
    }

    # Write to log.
    Write-Log ("[{0}][{1}][{2}] Current SKU is '{3}' and size is {4} megabytes" -f $subscription.Name, $azureSqlDatabase.ServerName, $azureSqlDatabase.DatabaseName, $azureSqlDatabase.CurrentServiceObjectiveName, ([Math]::Round($azureSqlDatabaseSize, 0)));

    # Add to object array.
    $databases += [PSCustomObject]@{
        SubscriptionName  = $subscription.Name;
        ResourceGroupName = $azureSqlDatabase.ResourceGroupName;
        ServerName        = $azureSqlDatabase.ServerName;
        DatabaseName      = $azureSqlDatabase.DatabaseName;
        SkuName           = $azureSqlDatabase.CurrentServiceObjectiveName;
        SizeInMb          = $azureSqlDatabaseSize;
    }
}

# Databases to check.
$databasesToCheck = @();

# Foreach database.
foreach ($database in $databases)
{
    # Find all SKU available with current database size.
    $availableDatabaseSku = $storageSizes | Where-Object { $_.StorageSizeInMb -gt $database.SizeInMb };

    # Foreach priority.
    foreach ($priority in $PriorityList)
    {
        # Get all SKU using priority.
        $nextDatabaseSku = $availableDatabaseSku | Where-Object { $_.SkuTier -eq $priority };

        # If found SKU is found.
        if ($null -ne $nextDatabaseSku)
        {
            # Break out of foreach.
            break;
        }
    }

    # Get the SKU with the lowest storage size and capacity.
    $nextDatabaseSku = $nextDatabaseSku | Sort-Object StorageSizeInMb, SkuCapacity | Select-Object -First 1;

    # If SKU is already the same.
    if ($nextDatabaseSku.Name -eq $database.SkuName)
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] No change needed, database is using SKU '{3}'" -f $subscription.Name, $database.ServerName, $database.DatabaseName, $database.SkuName);
    }
    # Else SKU should be changed to a new one.
    else
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Database is using SKU '{3}', but based on storage, it could be changed to '{4}'" -f $subscription.Name, $database.ServerName, $database.DatabaseName, $database.SkuName, $nextDatabaseSku.Name);

        # Add to object array.
        $databasesToCheck += [PSCustomObject]@{
            SubscriptionName      = $database.SubscriptionName;
            ResourceGroupName     = $database.ResourceGroupName;
            ServerName            = $database.ServerName;
            DatabaseName          = $database.DatabaseName;
            DatabaseSizeInMb      = [Math]::Round($database.SizeInMb);
            DatabaseSizeInGb      = [Math]::Round($database.SizeInMb / 1024);
            CurrentSkuName        = $database.SkuName;
            SkuName               = $nextDatabaseSku.Name;
            SkuTier               = $nextDatabaseSku.SkuTier;
            SkuFamily             = $nextDatabaseSku.SkuFamily;
            SkuCapacity           = $nextDatabaseSku.SkuCapacity;
            SkuCapacityUnit       = $nextDatabaseSku.SkuCapacityUnit;
            SkuMaxStorageSizeInGb = $nextDatabaseSku.StorageSizeInGb;
        };
    }
}

# If no databases is found.
if ($databases.Count -eq 0)
{
    # Write to log.
    Write-Log ("[{0}] No databases found in subscription" -f $subscription.Name);
}

# If no databases to check.
if ($databases.Count -ne 0 -and $databasesToCheck.Count -ne 0)
{
    # If OutputFilePath is not set.
    if ($null -ne $OutputFilePath)
    {
        # Get folder path.
        $OutputFolderPath = Split-Path -Path $OutputFilePath;
        
        # Test if folder exist.
        if (-not (Test-Path -Path $OutputFolderPath))
        {
            # Create folder.
            New-Item -Path $OutputFilePath -ItemType Directory -Force | Out-Null;
        }
        
        # Write to log.
        Write-Log ("Exporting to CSV file to '{0}'" -f $OutputFilePath);

        # Export to CSV file.
        $databasesToCheck | Export-Csv -Path $OutputFilePath `
            -NoTypeInformation `
            -Delimiter ";" `
            -Encoding "utf8" `
            -Force;
    }
}

# If we should update the databases.
if ($true -eq $Update)
{
    # Foreach database to check.
    foreach ($databaseToCheck in $databasesToCheck)
    {
        # Try to update SKU.
        try
        {
            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Trying to update SKU from '{3}' to '{4}', this might take a while" -f $databaseToCheck.SubscriptionName, $databaseToCheck.ServerName, $databaseToCheck.DatabaseName, $databaseToCheck.CurrentSkuName, $databaseToCheck.SkuName);

            # Update the database.
            Set-AzSqlDatabase -ResourceGroupName $databaseToCheck.ResourceGroupName `
                -ServerName $databaseToCheck.ServerName `
                -DatabaseName $databaseToCheck.DatabaseName `
                -Edition $databaseToCheck.SkuTier `
                -RequestedServiceObjectiveName $databaseToCheck.SkuName | Out-Null;

            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Successfully updated SKU" -f $databaseToCheck.SubscriptionName, $databaseToCheck.ServerName, $databaseToCheck.DatabaseName);
        }
        # Something went wrong updating sku.
        catch
        {
            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Something went wrong updating SKU, execption is:`r`n" -f $databaseToCheck.SubscriptionName, $databaseToCheck.ServerName, $databaseToCheck.DatabaseName, $_);
        }
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Log ("Script finished");

############### Finalize - End ###############
#endregion
