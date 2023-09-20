# Must be running PowerShell version 5.1 or higher.
#Requires -Version 5.1;

# Must have the following modules installed.
#Requires -Module Az.Accounts;
#Requires -Module Az.CosmosDB;
#Requires -Module Az.Resources;

<#
.SYNOPSIS
  Set throughput to the minimum value possible on the Cosmos DB database/container.
  Currently the script only support SQL API accounts.
  It will search in all available Azure subscriptions.

.DESCRIPTION
  Uses Cosmos DB REST api and PowerShell cmdlet to gather container size, throughput and documents count.
  After gathering information, it will decrease throughput values to lowest possible.
  This script was created for non-production environments to minimize costs for the Cosmos DB
  and currently there is a bug when you restore a Cosmos DB from continous backup it will assign a random throughput value.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  22-02-2023
  Purpose/Change: Initial script development
  
.EXAMPLE
  .\Set-CosmosDbThroughput.ps1 -AccountName "<Cosmos DB acocunt name>"
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
Param
(
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9-]{3,44}$')][string]$AccountName
)

############### Bootstrap - End ###############
#endregion

#region begin input
############### Variables - Start ###############

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
        [Parameter(Mandatory = $false)][string]$Text
    )
  
    # If text is not present.
    If ([string]::IsNullOrEmpty($Text))
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

# Generate authorization key.
Function New-MasterKeyAuthorizationSignature
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $false)][ValidateSet("Get")][string]$Verb = "Get",
        [Parameter(Mandatory = $false)][string]$ResourceLink,
        [Parameter(Mandatory = $true)][ValidateSet("colls", "offers")][string]$ResourceType,
        [Parameter(Mandatory = $true)][string]$MasterKey,
        [Parameter(Mandatory = $true)][ValidateSet("master")][string]$KeyType,
        [Parameter(Mandatory = $false)][string]$TokenVersion = "1.0",
        [Parameter(Mandatory = $true)][datetime]$Today
    )

    # Add assemblies.
    Add-Type -AssemblyName System.Web;

    # DateTime in string format.
    $DateTime = $Today.ToString("r");

    # Create SHA.
    $HmacSha256 = New-Object System.Security.Cryptography.HMACSHA256;

    # Convert BASE64 to byte array.
    $HmacSha256.Key = [System.Convert]::FromBase64String($MasterKey);
    
    # Create payload.
    $PayLoad = "$($Verb.ToLowerInvariant())`n$($ResourceType.ToLowerInvariant())`n$ResourceLink`n$($DateTime.ToLowerInvariant())`n`n";

    # Create hash from the payload.
    $HashPayLoad = $HmacSha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($PayLoad));

    # Convert hash to BASE64.
    $Signature = [System.Convert]::ToBase64String($HashPayLoad);

    # Encode URL.
    $UrlEncode = [System.Web.HttpUtility]::UrlEncode("type=$KeyType&ver=$TokenVersion&sig=$Signature");

    # Return URL encoding.
    Return $UrlEncode;
}

# Get Cosmos DB container metadata.
Function Get-CosmosDbContainerStatistics
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)][string]$EndpointUri,
        [Parameter(Mandatory = $true)][string]$MasterKey,
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $true)][string]$CollectionName
    )

    # Get datetime in UTC format.
    $Today = [DateTime]::UtcNow;

    # Construct resource link.
    $ResourceLink = ("dbs/{0}/colls/{1}" -f $DatabaseName, $CollectionName);

    # Generate auth key.
    $AuthHeader = New-MasterKeyAuthorizationSignature -Verb GET `
        -ResourceLink $ResourceLink `
        -ResourceType colls `
        -MasterKey $MasterKey `
        -KeyType master `
        -Today $Today;

    # Create REST header.
    $Headers = @{
        'authorization'                               = $AuthHeader;
        "x-ms-version"                                = "2018-09-17";
        "x-ms-date"                                   = $Today.ToString("r");
        "x-ms-documentdb-populatepartitionstatistics" = "true";
        "x-ms-documentdb-populatequotainfo"           = "true";
    };

    # Construct URI for the REST method.
    $Uri = ("{0}{1}" -f $EndpointUri, $ResourceLink);

    # Try to invoke REST method
    try
    {
        # Invoke REST method.
        $Result = Invoke-WebRequest -Method Get -ContentType "application/json" -Uri $Uri -Headers $Headers;

        # Split header response.
        $Resources = ($Result.headers["x-ms-resource-usage"]).Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)

        # Hash table to store keys/values.
        $UsageItems = @{};

        # Foreach resource.
        Foreach ($Resource in $Resources)
        {
            # Split resource info to key and value.
            [string] $Key, $Value = $Resource.Split('=');
            
            # Add to hash table.
            $UsageItems[$Key] = $Value;
        }

        # If there is any items.
        If ($UsageItems)
        {
            # Return items.
            Return $UsageItems;
        }
    }
    # Something went wrong while getting the container size.
    catch
    {
        # Write to log.
        Write-Log ("{0}" -f $_);
    }
}

# Get Cosmos DB offers (throughput info).
Function Get-CosmosDbOffers
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)][string]$EndpointUri,
        [Parameter(Mandatory = $true)][string]$MasterKey
    )

    # Get datetime in UTC format.
    $Today = [DateTime]::UtcNow;

    # Generate auth key.
    $AuthHeader = New-MasterKeyAuthorizationSignature -Verb GET `
        -ResourceType offers `
        -MasterKey $MasterKey `
        -KeyType master `
        -Today $Today;

    # Create REST header.
    $Headers = @{
        'authorization' = $AuthHeader;
        "x-ms-version"  = "2018-09-17";
        "x-ms-date"     = $Today.ToString("r");
    };

    # Construct URI for the REST method.
    $Uri = ("{0}offers" -f $EndpointUri);

    # Try to invoke REST method
    try
    {
        # Invoke REST method.
        $Result = Invoke-WebRequest -Method Get -ContentType "application/json" -Uri $Uri -Headers $Headers;

        # Return offers.
        return ($Result.Content | ConvertFrom-Json).Offers;
    }
    # Something went wrong while getting the offers.
    catch
    {
        # Write to log.
        Write-Log ("{0}" -f $_);
    }
}

# Convert any-to-any data sizes.
function Convert-DataSize
{
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory = $true)][ValidateSet("Bytes", "KB", "MB", "GB", "TB")][string]$From,
        [Parameter(Mandatory = $true)][ValidateSet("Bytes", "KB", "MB", "GB", "TB")][string]$To,
        [Parameter(Mandatory = $true)][double]$Value,
        [Parameter(Mandatory = $false)][int]$Precision = 4
    )

    # What to convert it from.
    switch ($From)
    {
        "Bytes" { $value = $Value }
        "KB" { $value = $Value * 1024 }
        "MB" { $value = $Value * 1024 * 1024 }
        "GB" { $value = $Value * 1024 * 1024 * 1024 }
        "TB" { $value = $Value * 1024 * 1024 * 1024 * 1024 }
    }

    # What to convert it to.
    switch ($To)
    {
        "Bytes" { return $value }
        "KB" { $Value = $Value / 1KB }
        "MB" { $Value = $Value / 1MB }
        "GB" { $Value = $Value / 1GB }
        "TB" { $Value = $Value / 1TB }

    }

    # Return value.
    return [Math]::Round($value, $Precision, [MidPointRounding]::AwayFromZero)
}

# Get Cosmos DB throughput info.
function Get-CosmosDbThroughputInfo
{
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory = $true)]$AccountName
    )

    # Get all available Azure subscriptions.
    $AzSubscriptions = (Get-AzContext -ListAvailable).Subscription;

    # Foreach subscription.
    foreach ($AzSubscription in $AzSubscriptions)
    {
        # Write to log.
        Write-Log ("Changing context to subscription '{0}'" -f $AzSubscription.Name);
        
        # Try to change subscription.
        try
        {
            # Change context to subscription.
            Set-AzContext -SubscriptionName $AzSubscription.Name -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null;
        }
        # Something went wrong while changing subscription.
        catch
        {
            # Write to log.
            Write-Log ("Something went wrong while changing context to subscription '{0}', skipping" -f $AzSubscription.Name);

            # Take next subscription.
            continue;
        }

        # Write to log.
        Write-Log ("Searching after Cosmos DB '{0}' in subscription '{1}'" -f $AccountName, $AzSubscription.Name);

        # Get Cosmos DB account.
        $CosmosDbAccount = Get-AzResource -ResourceType 'Microsoft.DocumentDB/databaseAccounts' | Where-Object { $_.Name -eq $AccountName };

        # If the Cosmos DB account exists.
        if ($null -ne $CosmosDbAccount)
        {
            # Write to log.
            Write-Log ("Found Cosmos DB '{0}' in subscription '{1}'" -f $AccountName, $AzSubscription.Name);

            # Break foreach loop.
            break;
        }
        # Else Cosmos DB dont exist in current subscription.
        else
        {
            # Write to log.
            Write-Log ("Cosmos DB '{0}' is not found in subscription '{1}'" -f $AccountName, $AzSubscription.Name);
        }
    }

    # If the Cosmos DB account exists.
    if ($null -eq $CosmosDbAccount)
    {
        # Throw exception.
        throw ("The Cosmos DB account '{0}' dont exist" -f $AccountName);
    }

    # Get endpoint URI.
    $CosmosDbAccountDocumentEndpoint = (Get-AzCosmosDBAccount -ResourceGroupName $CosmosDbAccount.ResourceGroupName -Name $CosmosDbAccount.Name).DocumentEndpoint;

    # Get master key.
    $CosmosDbAccountMasterKey = (Get-AzCosmosDBAccountKey -ResourceGroupName $CosmosDbAccount.ResourceGroupName -Name $CosmosDbAccount.Name).PrimaryReadonlyMasterKey;

    # Write to log.
    Write-Log ("[{0}][{1}] Getting all databases in Cosmos DB account" -f $CosmosDbAccount.ResourceGroupName, $CosmosDbAccount.Name);

    # Get all databases.
    $CosmosDbDatabases = Get-AzCosmosDBSqlDatabase -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name;

    # If there is no databases.
    if ($null -eq $CosmosDbDatabases)
    {
        # Write to log.
        Write-Log ("[{0}][{1}] No databases found in Cosmos DB account" -f $CosmosDbAccount.ResourceGroupName, $CosmosDbAccount.Name);

        # Return null.
        return $null;
    }

    # Write to log.
    Write-Log ("[{0}][{1}] Getting offers in Cosmos DB account" -f $CosmosDbAccount.ResourceGroupName, $CosmosDbAccount.Name);

    # Get all offers.
    $CosmosDbOffers = Get-CosmosDbOffers -EndpointUri $CosmosDbAccountDocumentEndpoint -MasterKey $CosmosDbAccountMasterKey;

    # Object arrays to store results.
    $ContainerResults = @();

    # Foreach database.
    Foreach ($CosmosDbDatabase in $CosmosDbDatabases)
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Getting (if any) database throughput values" -f $CosmosDbAccount.ResourceGroupName, $CosmosDbAccount.Name, $CosmosDbDatabase.Name);

        # Get throughput settings on the database.
        $DatabaseThroughput = Get-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $CosmosDbDatabase.Name -ErrorAction SilentlyContinue;
    
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Getting all containers in the database" -f $CosmosDbAccount.ResourceGroupName, $CosmosDbAccount.Name, $CosmosDbDatabase.Name);

        # Get all containers in the database.
        $CosmosDbContainers = Get-AzCosmosDBSqlContainer -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $CosmosDbDatabase.Name;

        # Foreach container.
        Foreach ($CosmosDbContainer in $CosmosDbContainers)
        {        
            # Write to log.
            Write-Log ("[{0}][{1}][{2}][{3}] Getting container statistics and throughput settings" -f $CosmosDbAccount.ResourceGroupName, $CosmosDbAccount.Name, $CosmosDbDatabase.Name, $CosmosDbContainer.Name);

            # Get container size.
            $ContainerStatistics = Get-CosmosDbContainerStatistics -EndpointUri $CosmosDbAccountDocumentEndpoint -MasterKey $CosmosDbAccountMasterKey -DatabaseName $CosmosDbDatabase.Name -CollectionName $CosmosDbContainer.Name;

            # Get container throughput.
            $ContainerThroughput = Get-AzCosmosDBSqlContainerThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $CosmosDbDatabase.Name -Name $CosmosDbContainer.Name -ErrorAction SilentlyContinue;

            # If there is set throughput on the container.
            if ($null -ne $ContainerThroughput)
            {
                # Manual throughput.
                [bool]$SharedThroughput = $false;

                # Set throughput object.
                $ThroughputSettings = $ContainerThroughput;
            }
            # Else throughput is shared in the database.
            else
            {
                # Shared throughput.
                [bool]$SharedThroughput = $true;

                # Set throughput object.
                $ThroughputSettings = $DatabaseThroughput;
            }

            # If autoscale is enabled.
            if ($ThroughputSettings.AutoscaleSettings.MaxThroughput -ne 0)
            {
                # Autoscale is enabled.
                [bool]$AutoscaleEnabled = $true;

                # Max throughput.
                $MaxThroughput = $ThroughputSettings.AutoscaleSettings.MaxThroughput;
            }
            # Else autoscale is not enabled
            else
            {
                # Autoscale is disabled.
                [bool]$AutoscaleEnabled = $false;

                # Max throughput.
                $MaxThroughput = $ThroughputSettings.Throughput;
            }

            # Get offer from throughput.
            $Offer = $CosmosDbOffers | Where-Object { $_.id -eq $ThroughputSettings.Name };

            # Add to object array.
            $ContainerResults += [PSCustomObject]@{
                "ResourceGroupName"            = $CosmosDbAccount.ResourceGroupName;
                "AccountName"                  = $CosmosDbAccount.Name;
                "DatabaseName"                 = $CosmosDbDatabase.Name;
                "ContainerName"                = $CosmosDbContainer.Name;
                "ContainerSizeInKB"            = $ContainerStatistics.collectionSize;
                "DocumentsCount"               = $ContainerStatistics.documentsCount;
                "DocumentsSizeInKB"            = $ContainerStatistics.documentsSize;
                "SharedThroughput"             = $SharedThroughput;
                "MinimumThroughput"            = $ThroughputSettings.Throughput;
                "MinimumThroughputPossible"    = $ThroughputSettings.MinimumThroughput;
                "AutoscaleEnabled"             = $AutoscaleEnabled;
                "MaxThroughput"                = $MaxThroughput;
                "MaxThroughputEverProvisioned" = $Offer.content.offerMinimumThroughputParameters.maxThroughputEverProvisioned;
                "MaxConsumedStorageEverInKB"   = $Offer.content.offerMinimumThroughputParameters.maxConsumedStorageEverInKB;
            };
        }
    }

    # Return result.
    Return $ContainerResults;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get throughput info.
$CosmosDbThroughputs = Get-CosmosDbThroughputInfo -AccountName $AccountName;

# Foreach throughput info.
foreach ($CosmosDbThroughput in $CosmosDbThroughputs)
{
    # If the throughput is not low as possible.
    if ($CosmosDbThroughput.MaxThroughput -ne $CosmosDbThroughput.MinimumThroughputPossible)
    {
        # If Cosmos DB container is using shared throughput from the database.
        if ($true -eq $CosmosDbThroughput.SharedThroughput)
        {
            # Refresh throughput values.
            $CosmosDbDatabaseThroughput = Get-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $CosmosDbThroughput.ResourceGroupName -AccountName $CosmosDbThroughput.AccountName -Name $CosmosDbThroughput.DatabaseName;
            
            # If the shared throughput is not low as possible.
            if ($CosmosDbDatabaseThroughput.AutoscaleSettings.MaxThroughput -ne $CosmosDbThroughput.MinimumThroughputPossible)
            {
                # If autoscale is enabled.
                if ($true -eq $CosmosDbThroughput.AutoscaleEnabled)
                {
                    # Write to log.
                    Write-Log ("[{0}][{1}][{2}] Setting autoscale database throughput from {3} to {4}" -f $CosmosDbThroughput.ResourceGroupName, $CosmosDbThroughput.AccountName, $CosmosDbThroughput.DatabaseName, $CosmosDbThroughput.MaxThroughput, $CosmosDbThroughput.MinimumThroughputPossible);

                    # Update autoscale max throughput on the database.
                    Update-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $CosmosDbThroughput.ResourceGroupName `
                        -AccountName $CosmosDbThroughput.AccountName `
                        -Name $CosmosDbThroughput.DatabaseName `
                        -AutoscaleMaxThroughput $CosmosDbThroughput.MinimumThroughputPossible `
                        -ErrorAction Stop | Out-Null;
                }
                # Else autoscale is not enabled.
                else
                {
                    # Write to log.
                    Write-Log ("[{0}][{1}][{2}] Setting database throughput from {3} to {4}" -f $CosmosDbThroughput.ResourceGroupName, $CosmosDbThroughput.AccountName, $CosmosDbThroughput.DatabaseName, $CosmosDbThroughput.MaxThroughput, $CosmosDbThroughput.MinimumThroughputPossible);

                    # Update autoscale max throughput on the database.
                    Update-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $CosmosDbThroughput.ResourceGroupName `
                        -AccountName $CosmosDbThroughput.AccountName `
                        -Name $CosmosDbThroughput.DatabaseName `
                        -Throughput $CosmosDbThroughput.MinimumThroughputPossible `
                        -ErrorAction Stop | Out-Null;
                }
            }
        }
        # Else throughput is set on container.
        else
        {
            # If autoscale is enabled.
            if ($true -eq $CosmosDbThroughput.AutoscaleEnabled)
            {
                # Write to log.
                Write-Log ("[{0}][{1}][{2}][{3}] Setting autoscale container throughput from {4} to {5}" -f $CosmosDbThroughput.ResourceGroupName, $CosmosDbThroughput.AccountName, $CosmosDbThroughput.DatabaseName, $CosmosDbThroughput.ContainerName, $CosmosDbThroughput.MaxThroughput, $CosmosDbThroughput.MinimumThroughputPossible);

                # Update autoscale max throughput on the container.
                Update-AzCosmosDBSqlContainerThroughput -ResourceGroupName $CosmosDbThroughput.ResourceGroupName `
                    -AccountName $CosmosDbThroughput.AccountName `
                    -DatabaseName $CosmosDbThroughput.DatabaseName `
                    -Name $CosmosDbThroughput.ContainerName `
                    -AutoscaleMaxThroughput $CosmosDbThroughput.MinimumThroughputPossible `
                    -ErrorAction Stop | Out-Null;
            }
            # Else autoscale is not enabled.
            else
            {
                # Write to log.
                Write-Log ("[{0}][{1}][{2}][{3}] Setting container throughput from {4} to {5}" -f $CosmosDbThroughput.ResourceGroupName, $CosmosDbThroughput.AccountName, $CosmosDbThroughput.DatabaseName, $CosmosDbThroughput.ContainerName, $CosmosDbThroughput.MaxThroughput, $CosmosDbThroughput.MinimumThroughputPossible);

                # Update autoscale max throughput on the container.
                Update-AzCosmosDBSqlContainerThroughput -ResourceGroupName $CosmosDbThroughput.ResourceGroupName `
                    -AccountName $CosmosDbThroughput.AccountName `
                    -DatabaseName $CosmosDbThroughput.DatabaseName `
                    -Name $CosmosDbThroughput.ContainerName `
                    -Throughput $CosmosDbThroughput.MinimumThroughputPossible `
                    -ErrorAction Stop | Out-Null;
            }
        }
    }
    # Else throughput value already correct.
    else
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}][{3}] Throughput value '{4}' is already correct, skipping" -f $CosmosDbThroughput.ResourceGroupName, $CosmosDbThroughput.AccountName, $CosmosDbThroughput.DatabaseName, $CosmosDbThroughput.ContainerName, $CosmosDbThroughput.MinimumThroughputPossible);
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Log ("Script finished at {0}" -f (Get-Date));

############### Finalize - End ###############
#endregion
