# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Must have the following modules installed.
#Requires -Module Az.Accounts;
#Requires -Module Az.CosmosDB;

# Also make sure that you have installed the following modules:
#Install-Module -Name Az.Accounts -SkipPublisherCheck -Force -Scope CurrentUser;
#Install-Module -Name Az.CosmosDB -SkipPublisherCheck -Force -Scope CurrentUser;

<#
.SYNOPSIS
  Check differences between to Cosmos DB accounts and fix them is set. 

.DESCRIPTION
  Get database, container, indexing policy, partition key and default TTL.

.EXAMPLE
  # Get differences at fix indexing policies.
  .\Compare-CosmosDbAccounts.ps1 -SourceSubcriptionName "" -SourceAccountName "" -TargetSubcriptionName "" -TargetAccountName "" -FixIndexingPolicy $true -FixPartitionKey $false;

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  28-06-2023
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
[cmdletbinding()]
param
(
    [Parameter(Mandatory = $true)][string]$SourceSubscriptionName,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9-]{3,44}$')][string]$SourceAccountName,
    [Parameter(Mandatory = $true)][string]$TargetSubscriptionName,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9-]{3,44}$')][string]$TargetAccountName,
    [Parameter(Mandatory = $false)][bool]$FixIndexingPolicy = $false,
    [Parameter(Mandatory = $false)][bool]$FixPartitionKey = $false
)

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Write to log.
Function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory = $false)][string]$Text,
        [Parameter(Mandatory = $false)][Switch]$NoTime
    )
  
    # If text is not present.
    If ([string]::IsNullOrEmpty($Text))
    {
        # Write to the console.
        Write-Host("");
    }
    Else
    {
        # If no time is specificied.
        If ($NoTime)
        {
            # Write to the console.
            Write-Host($Text);
        }
        Else
        {
            # Write to the console.
            Write-Host("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text);
        }
    }
}

# Get Cosmos DB SQL databases.
Function Get-CosmosDbSqlDatabases
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory = $true)][string]$SubscriptionName,
        [Parameter(Mandatory = $true)][string]$AccountName
    )

    # Change subscription.
    Select-AzSubscription -Subscription $SubscriptionName -ErrorAction Stop -Force | Out-Null;

    # Get Azure resource.
    $AzResource = Get-AzResource -ResourceType 'Microsoft.DocumentDB/databaseAccounts' -Name $AccountName;

    # If resource is not found.
    if ($null -eq $AzResource)
    {
        throw ("Azure Cosmos DB '{0}' is not found under the current Azure context" -f $AccountName);
    }

    # Write to log.
    Write-Log -Text ("Getting all Cosmos DB SQL databases from account '{0}' in subscription '{1}'" -f $AccountName, $SubscriptionName);

    # Get Cosmos DB databases.
    $AzCosmosDBSqlDatabase = Get-AzCosmosDBSqlDatabase -ResourceGroupName $AzResource.ResourceGroupName -AccountName $AzResource.Name;
    
    # Return Cosmos DB databases.
    return $AzCosmosDBSqlDatabase;
}

# Get Cosmos DB SQL containers.
Function Get-CosmosDbSqlContainers
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory = $true)][string]$SubscriptionName,
        [Parameter(Mandatory = $true)][string]$AccountName,
        [Parameter(Mandatory = $true)][string]$DatabaseName
    )

    # Change subscription.
    Select-AzSubscription -Subscription $SubscriptionName -ErrorAction Stop -Force | Out-Null;

    # Get Azure resource.
    $AzResource = Get-AzResource -ResourceType 'Microsoft.DocumentDB/databaseAccounts' -Name $AccountName;

    # If resource is not found.
    if ($null -eq $AzResource)
    {
        throw ("Azure Cosmos DB '{0}' is not found under the current Azure context" -f $AccountName);
    }

    # Write to log.
    Write-Log -Text ("Getting all Cosmos DB SQL containers from account '{0}' in database '{1}' from subscription '{2}'" -f $AccountName, $DatabaseName, $SubscriptionName);

    # Get Cosmos DB containers.
    $AzCosmosDBSqlContainers = Get-AzCosmosDBSqlContainer -ResourceGroupName $AzResource.ResourceGroupName -AccountName $AzResource.Name -DatabaseName $DatabaseName;
    
    # Return Cosmos DB containers.
    return $AzCosmosDBSqlContainers;
}

# Compare index policy.
Function Compare-CosmosDbSqlContainerIndexPolicy
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory = $true)]$SourceContainer,
        [Parameter(Mandatory = $true)]$TargetContainer
    )

    # Convert to JSON.
    $SourceJson = $SourceContainer.Resource.IndexingPolicy | ConvertTo-Json -Depth 100;
    $TargetJson = $TargetContainer.Resource.IndexingPolicy | ConvertTo-Json -Depth 100;

    # If the index policy is the same.
    if ($SourceJson -ceq $TargetJson)
    {
        # Return true.
        return $true;
    }
    # Else differrent.
    else
    {
        # Return true.
        return $false;
    }
}

# Compare partition key.
Function Compare-CosmosDbSqlContainerPartitionKey
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory = $true)]$SourceContainer,
        [Parameter(Mandatory = $true)]$TargetContainer
    )

    # Convert to JSON.
    $SourceJson = $SourceContainer.Resource.PartitionKey | ConvertTo-Json -Depth 100;
    $TargetJson = $TargetContainer.Resource.PartitionKey | ConvertTo-Json -Depth 100;

    # If the partition key is the same.
    if ($SourceJson -ceq $TargetJson)
    {
        # Return true.
        return $true;
    }
    # Else differrent.
    else
    {
        # Return true.
        return $false;
    }
}

# Update indexing policy.
Function Update-CosmosDbSqlIndexingPolicy
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory = $true)][string]$SubscriptionName,
        [Parameter(Mandatory = $true)][string]$AccountName,
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $true)][string]$ContainerName,
        [Parameter(Mandatory = $true)]$IndexingPolicy
    )

    # Change subscription.
    Select-AzSubscription -Subscription $SubscriptionName -ErrorAction Stop -Force | Out-Null;

    # Get Azure resource.
    $AzResource = Get-AzResource -ResourceType 'Microsoft.DocumentDB/databaseAccounts' -Name $AccountName;

    # If resource is not found.
    if ($null -eq $AzResource)
    {
        throw ("Azure Cosmos DB '{0}' is not found under the current Azure context" -f $AccountName);
    }

    # Create new indexing policy.
    $IndexingPolicy = New-AzCosmosDBSqlIndexingPolicy -IncludedPath $IndexingPolicy.IncludedPaths `
        -ExcludedPath ($IndexingPolicy.ExcludedPaths).Path `
        -Automatic $IndexingPolicy.Automatic `
        -IndexingMode $IndexingPolicy.IndexingMode;

    # Write to log.
    Write-Log -Text ("Updating indexing policy with source account value in container '{0}' in database '{1}' on account '{2}' from subscription '{3}'" -f $ContainerName, $DatabaseName, $AccountName, $SubscriptionName);

    # Update indexing policy.
    Update-AzCosmosDBSqlContainer -ResourceGroupName $AzResource.ResourceGroupName `
        -AccountName $AccountName `
        -DatabaseName $DatabaseName `
        -Name $ContainerName `
        -IndexingPolicy $IndexingPolicy | Out-Null;
}

# Update partition key.
Function Update-CosmosDbSqlPartitionKey
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory = $true)][string]$SubscriptionName,
        [Parameter(Mandatory = $true)][string]$AccountName,
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $true)][string]$ContainerName,
        [Parameter(Mandatory = $true)]$PartitionKey
    )

    # Change subscription.
    Select-AzSubscription -Subscription $SubscriptionName -ErrorAction Stop -Force | Out-Null;

    # Get Azure resource.
    $AzResource = Get-AzResource -ResourceType 'Microsoft.DocumentDB/databaseAccounts' -Name $AccountName;

    # If resource is not found.
    if ($null -eq $AzResource)
    {
        throw ("Azure Cosmos DB '{0}' is not found under the current Azure context" -f $AccountName);
    }

    # Write to log.
    Write-Log -Text ("Updating partition key with source account value in container '{0}' in database '{1}' on account '{2}' from subscription '{3}'" -f $ContainerName, $DatabaseName, $AccountName, $SubscriptionName);

    # Update indexing policy.
    Update-AzCosmosDBSqlContainer -ResourceGroupName $AzResource.ResourceGroupName `
        -AccountName $AccountName `
        -DatabaseName $DatabaseName `
        -Name $ContainerName `
        -PartitionKeyVersion $PartitionKey.Version `
        -PartitionKeyKind $PartitionKey.Kind `
        -PartitionKeyPath $PartitionKey.Paths  | Out-Null;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get source and target Cosmos DB SQL databases.
$SourceCosmosDbSqlDatabases = Get-CosmosDbSqlDatabases -SubscriptionName $SourceSubscriptionName -AccountName $SourceAccountName;
$TargetCosmosDbSqlDatabases = Get-CosmosDbSqlDatabases -SubscriptionName $TargetSubscriptionName -AccountName $TargetAccountName;

# Object array to store differences.
$Differences = @();

# Foreach source database.
foreach ($SourceCosmosDbSqlDatabase in $SourceCosmosDbSqlDatabases)
{
    # Get database from target account.
    $TargetCosmosDbSqlDatabase = $TargetCosmosDbSqlDatabases | Where-Object { $_.Name -eq $SourceCosmosDbSqlDatabase.Name };

    # If database dont exist.
    if ($null -eq $TargetCosmosDbSqlDatabase)
    {
        # Add to differerences.
        $Differences += [PSCustomObject]@{
            SourceSubscriptionName = $SourceSubscriptionName;
            SourceCosmosDbName     = $SourceAccountName
            TargetSubscriptionName = $TargetSubscriptionName;
            TargetCosmosDbName     = $TargetAccountName;
            SourceDatabaseName     = $SourceCosmosDbSqlDatabase.Name;
            TargetDatabaseName     = $null;
            Component              = "Database";
            Reason                 = ("Target database '{0}' does not exist" -f $SourceCosmosDbSqlDatabase.Name)
        };
    }
    # Else database exist.
    else
    {
        # Get source and target Cosmos DB containers.
        $SourceCosmosDbSqlContainers = Get-CosmosDbSqlContainers -SubscriptionName $SourceSubscriptionName -AccountName $SourceAccountName -DatabaseName $SourceCosmosDbSqlDatabase.Name;
        $TargetCosmosDbSqlContainers = Get-CosmosDbSqlContainers -SubscriptionName $TargetSubscriptionName -AccountName $TargetAccountName -DatabaseName $TargetCosmosDbSqlDatabase.Name;

        # Foreach source container.
        foreach ($SourceCosmosDbSqlContainer in $SourceCosmosDbSqlContainers)
        {
            # Get container from target database.
            $TargetCosmosDbSqlContainer = $TargetCosmosDbSqlContainers | Where-Object { $_.Name -eq $SourceCosmosDbSqlContainer.Name };

            # If container dont exist.
            if ($null -eq $TargetCosmosDbSqlContainer)
            {
                # Add to differerences.
                $Differences += [PSCustomObject]@{
                    SourceSubscriptionName = $SourceSubscriptionName;
                    SourceCosmosDbName     = $SourceAccountName
                    TargetSubscriptionName = $TargetSubscriptionName;
                    TargetCosmosDbName     = $TargetAccountName;
                    SourceDatabaseName     = $SourceCosmosDbSqlDatabase.Name;
                    TargetDatabaseName     = $SourceCosmosDbSqlDatabase.Name;
                    SourceContainerName    = $SourceCosmosDbSqlContainer.Name;
                    TargetContainerName    = $null;
                    Component              = "Container";
                    Reason                 = ("Target container '{0}' does not exist" -f $SourceCosmosDbSqlContainer.Name);
                };
            }
            # Else container exist.
            else
            {
                # If indexing policy is not the same (returns bool).
                if (-not (Compare-CosmosDbSqlContainerIndexPolicy -SourceContainer $SourceCosmosDbSqlContainer -TargetContainer $TargetCosmosDbSqlContainer))
                {
                    # Write to log.
                    Write-Log -Text ("IndexPolicy does not match for container '{0}' in database '{1}'" -f $TargetCosmosDbSqlContainer.Name, $TargetCosmosDbSqlDatabase.Name);

                    # Add to differerences.
                    $Differences += [PSCustomObject]@{
                        SourceSubscriptionName = $SourceSubscriptionName;
                        SourceCosmosDbName     = $SourceAccountName
                        TargetSubscriptionName = $TargetSubscriptionName;
                        TargetCosmosDbName     = $TargetAccountName;
                        SourceDatabaseName     = $SourceCosmosDbSqlDatabase.Name;
                        TargetDatabaseName     = $SourceCosmosDbSqlDatabase.Name;
                        SourceContainerName    = $SourceCosmosDbSqlContainer.Name;
                        TargetContainerName    = $TargetCosmosDbSqlContainer.Name;
                        Component              = "IndexingPolicy";
                        SourceIndexingPolicy   = $SourceCosmosDbSqlContainer.Resource.IndexingPolicy | ConvertTo-Json -Depth 100;
                        TargetIndexingPolicy   = $TargetCosmosDbSqlContainer.Resource.IndexingPolicy | ConvertTo-Json -Depth 100;
                        Reason                 = ("Indexing policy is not the same");
                    };

                    # If fix indexing policy is set.
                    if ($true -eq $FixIndexingPolicy)
                    {
                        # Update indexing policy, using the source account value.
                        Update-CosmosDbSqlIndexingPolicy -SubscriptionName $TargetSubscriptionName -AccountName $TargetAccountName -DatabaseName $TargetCosmosDbSqlDatabase.Name -ContainerName $TargetCosmosDbSqlContainer.Name -IndexingPolicy $SourceCosmosDbSqlContainer.Resource.IndexingPolicy;
                    }
                }

                # If partition key is not the same (returns bool).
                if (-not (Compare-CosmosDbSqlContainerPartitionKey -SourceContainer $SourceCosmosDbSqlContainer -TargetContainer $TargetCosmosDbSqlContainer))
                {
                    # Write to log.
                    Write-Log -Text ("PartitionKey does not match for container '{0}' in database '{1}'" -f $TargetCosmosDbSqlContainer.Name, $TargetCosmosDbSqlDatabase.Name);
                
                    # Add to differerences.
                    $Differences += [PSCustomObject]@{
                        SourceSubscriptionName = $SourceSubscriptionName;
                        SourceCosmosDbName     = $SourceAccountName
                        TargetSubscriptionName = $TargetSubscriptionName;
                        TargetCosmosDbName     = $TargetAccountName;
                        SourceDatabaseName     = $SourceCosmosDbSqlDatabase.Name;
                        TargetDatabaseName     = $SourceCosmosDbSqlDatabase.Name;
                        SourceContainerName    = $SourceCosmosDbSqlContainer.Name;
                        TargetContainerName    = $TargetCosmosDbSqlContainer.Name;
                        Component              = "PartitionKey";
                        SourcePartitionKey     = $SourceCosmosDbSqlContainer.Resource.PartitionKey | ConvertTo-Json -Depth 100;
                        TargetPartitionKey     = $TargetCosmosDbSqlContainer.Resource.PartitionKey | ConvertTo-Json -Depth 100;
                        Reason                 = ("Partition key is not the same");
                    };

                    # If fix partition key is set.
                    if ($true -eq $FixPartitionKey)
                    {
                        # Update partition key, using the source account value.
                        Update-CosmosDbSqlPartitionKey -SubscriptionName $TargetSubscriptionName -AccountName $TargetAccountName -DatabaseName $TargetCosmosDbSqlDatabase.Name -ContainerName $TargetCosmosDbSqlContainer.Name -PartitionKey $SourceCosmosDbSqlContainer.Resource.PartitionKey;
                    }
                }

                # If default TTL is not the same.
                if ($SourceCosmosDbSqlContainer.Resource.DefaultTtl -ne $TargetCosmosDbSqlContainer.Resource.DefaultTtl)
                {
                    # Write to log.
                    Write-Log -Text ("Default TTL does not match for container '{0}' in database '{1}'" -f $TargetCosmosDbSqlContainer.Name, $TargetCosmosDbSqlDatabase.Name);
                
                    # Add to differerences.
                    $Differences += [PSCustomObject]@{
                        SourceSubscriptionName = $SourceSubscriptionName;
                        SourceCosmosDbName     = $SourceAccountName
                        TargetSubscriptionName = $TargetSubscriptionName;
                        TargetCosmosDbName     = $TargetAccountName;
                        SourceDatabaseName     = $SourceCosmosDbSqlDatabase.Name;
                        TargetDatabaseName     = $SourceCosmosDbSqlDatabase.Name;
                        SourceContainerName    = $SourceCosmosDbSqlContainer.Name;
                        TargetContainerName    = $TargetCosmosDbSqlContainer.Name;
                        Component              = "DefaultTTL";
                        SourcePartitionKey     = $SourceCosmosDbSqlContainer.Resource.DefaultTtl;
                        TargetPartitionKey     = $TargetCosmosDbSqlContainer.Resource.DefaultTtl;
                        Reason                 = ("Default TTL not the same");
                    };
                }
            }
        }
    }
}

# Return results.
return $Differences;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
