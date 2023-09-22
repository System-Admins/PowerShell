#Requires -Version 5.1;
#Requires -Modules Az.Accounts, Az.Resources, Az.Monitor, Az.ResourceGraph;

<#
.SYNOPSIS
  Identify Azure resources that have been scaled up/down.

.DESCRIPTION
  Itereates through all Azure subscriptions and searches for resources that have been scaled up/down using activity log.
  This is useful to identify resources that have been scaled up/down manually or by a script.

.Parameter Hours
  Specifies how long to search back in the activity log.
  Minimum is 1 and maximum is 2160 (90 days) hours.

.Parameter ResourceTypes
  Specifies which resource types to search for in the activity log.
  Default is Microsoft.Sql/servers/databases and Microsoft.Web/serverfarms.

.Parameter ResourceGroupName
  Specifies which resource group to search in for resources with scale events.

.Parameter SubscriptionName
  Specifies which subscription to search in for resources with scale events.

.EXAMPLE
  # This example searches for resources that have been scaled up/down in the last 24 hours in all subscriptions available in Azure.
  .\Get-AzureScaledResources.ps1;

.EXAMPLE
  # This example searches for resources that have been scaled up/down in the last 24 hours in a resource group in a specific subscription.
  # The resource types that are searched for are Microsoft.Sql/servers/databases and Microsoft.Web/serverfarms.
  .\Get-AzureScaledResources.ps1 -Hours 24 -ResourceTypes "Microsoft.Sql/servers/databases", "Microsoft.Web/serverfarms" -ResourceGroupName "myResourceGroup" -SubscriptionName "mySubcription";

.EXAMPLE
  # This example searches for resources that have been scaled up/down in the last 24 hours in a resource group.
  # The resource types that are searched for are Microsoft.Sql/servers/databases and Microsoft.Web/serverfarms.
  .\Get-AzureScaledResources.ps1 -Hours 24 -ResourceTypes "Microsoft.Sql/servers/databases", "Microsoft.Web/serverfarms" -ResourceGroupName "myResourceGroup";

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  22-09-2023
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

Param
(
    [Parameter(Mandatory = $false)][ValidateRange(1, 2160)][int]$Hours = 24,
    [Parameter(Mandatory = $false)][ValidateSet("Microsoft.Sql/servers/databases", "Microsoft.Web/serverfarms", "Microsoft.Sql/servers/elasticpools", "Microsoft.DocumentDB/databaseAccounts")][string[]]$ResourceTypes = @("Microsoft.Sql/servers/databases", "Microsoft.Web/serverfarms", "Microsoft.Sql/servers/elasticpools", "Microsoft.DocumentDB/databaseAccounts"),
    [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()][string]$ResourceGroupName,
    [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()][string]$SubscriptionName
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

# Allowed operations names.
$allowedOperationNames = @(
    "Update hosting plan",
    "Write SQL container throughput",
    "Write SQL database throughput",
    "Migrate SQL container offer to autoscale",
    "Update SQL database",
    "Create new or update existing elastic pool"
);

# Get start time date.
$StartTime = (Get-Date).AddHours(-$Hours);

# Export CSV file.
$CsvFilePath = ("{0}\AzureScaledResources.csv" -f [Environment]::GetFolderPath("Desktop"));

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
        # Write to log.
        Write-Information -MessageData "" -InformationAction Continue;
    }
    Else
    {
        # Write to log.
        Write-Information -MessageData ("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text) -InformationAction Continue;
    }
}

# Get Azure resources.
Function Get-AzureResources
{
    [cmdletbinding()]
		
    Param
    (
        [Parameter(Mandatory = $true)]$AzContexts,
        [Parameter(Mandatory = $true)][string[]]$ResourceTypes,
        [Parameter(Mandatory = $false)][string]$ResourceGroupName
    )
  
    # Variable to store resources in.
    [array]$resources = @();

    # Foreach Azure context.
    foreach ($azContext in $azContexts)
    {
        # Try to set the Azure context.
        try
        {
            # Write to log.
            Write-Log -Text ("[{0}] Trying to change Azure subscription" -f $azContext.Subscription.Name);

            # Set the Azure context.
            Set-AzContext -SubscriptionId $azContext.Subscription.Id -TenantId $azContext.Tenant.Id -ErrorAction Stop | Out-Null;

            # Write to log.
            Write-Log -Text ("[{0}] Succesfully changed Azure subscription" -f $azContext.Subscription.Name);
        }
        # Something went wrong while setting the Azure context.
        catch
        {
            # Write to log.
            Write-Log -Text ("[{0}] Failed to change Azure subscription" -f $azContext.Subscription.Name);
        
            # Continue.
            continue;
        }

        # Foreach resource type allowed.
        foreach ($resourceType in $ResourceTypes)
        {
            # If a resource group name is specified.
            if (-not [string]::IsNullOrEmpty($ResourceGroupName))
            {
                # Write to log.
                Write-Log -Text ("[{0}] Getting all resources types from resource group '{1}'" -f $azContext.Subscription.Name, $ResourceGroupName);
        
                # Get resources.
                $resources += Get-AzResource -ResourceType $resourceType -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue;
            }
            # If no resource group name is specified.
            else
            {
                # Write to log.
                Write-Log -Text ("[{0}] Getting all resources types from subscription" -f $azContext.Subscription.Name, $ResourceGroupName);

                # Get resources.
                $resources += Get-AzResource -ResourceType $resourceType -ErrorAction SilentlyContinue;
            }
        }
    }

    # Return resources.
    return $resources;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# If we are not logged into Azure.
if ($null -eq (Get-AzContext))
{
    # Write to log.
    Write-Log -Text ("Connecting to Azure");

    # Connect to Azure.
    Connect-AzAccount -WarningAction SilentlyContinue | Out-Null;
}

# Get Azure contexts.
$azContexts = Get-AzContext -ListAvailable;

# If the subscription name is specified.
if (-not [string]::IsNullOrEmpty($SubscriptionName))
{
    # Write to log.
    Write-Log -Text ("Specific subscription name is specified '{0}'" -f $SubscriptionName);

    # Get the Azure context by subscription name.
    $azContexts = $azContexts | Where-Object { $_.Subscription.Name -eq $SubscriptionName };
}

# If azure contexts are not present.
if ($null -eq $azContexts)
{
    # Write to log.
    Write-Log -Text ("No Azure subscription found, aborting");

    # Exit.
    Exit;
}

# Get Azure resources.
$resources = Get-AzureResources -AzContexts $azContexts -ResourceTypes $ResourceTypes -ResourceGroupName $ResourceGroupName;

# Object array to store scaled resources in.
[array]$scaledResources = @();

# Foreach subscription.
foreach ($subscription in $resources | Group-Object -Property SubscriptionId)
{
    # Get Azure context.
    $azContext = $azContexts | Where-Object { $_.Subscription.Id -eq $subscription.Name };

    # Try to set the Azure context.
    try
    {
        # Write to log.
        Write-Log -Text ("[{0}] Trying to change Azure subscription" -f $azContext.Subscription.Name);

        # Set the Azure context.
        Set-AzContext -SubscriptionId $azContext.Subscription.Id -TenantId $azContext.Tenant.Id -ErrorAction Stop | Out-Null;

        # Write to log.
        Write-Log -Text ("[{0}] Succesfully changed Azure subscription" -f $azContext.Subscription.Name);
    }
    # Something went wrong while setting the Azure context.
    catch
    {
        # Write to log.
        Write-Log -Text ("[{0}] Failed to change Azure subscription" -f $azContext.Subscription.Name);
        
        # Continue.
        continue;
    }

    # Foreach resource in subscription.
    foreach ($resource in $subscription.Group)
    {
        # Write to log.
        Write-Log -Text ("[{0}][{1}][{2}] Getting activity log ({3})" -f $azContext.Subscription.Name, $resource.ResourceGroupName, $resource.ResourceName, $resource.ResourceType);

        # Get activity log.
        $activityLog = Get-AzLog -ResourceId $resource.ResourceId -StartTime $StartTime -Status Succeeded -ErrorAction SilentlyContinue -WarningAction SilentlyContinue;

        # Remove duplicates (enforce uniqueness on the CorrelationId).
        $activityLog = $activityLog | Sort-Object -Property CorrelationId -Unique;

        # If there is no activity log.
        if ($null -eq $activityLog)
        {
            # Write to log.
            Write-Log -Text ("[{0}][{1}][{2}] No data in the activity log with start date '{3}'" -f $azContext.Subscription.Name, $resource.ResourceGroupName, $resource.ResourceName, $StartTime);
        
            # Continue.
            continue;
        }

        # Write to log.
        Write-Log -Text ("[{0}][{1}][{2}] Searching in activity log after scale events, this might take some time" -f $azContext.Subscription.Name, $resource.ResourceGroupName, $resource.ResourceName);

        # Foreach activity log entry.
        foreach ($logEntry in $activityLog)
        {
            # If log entry is not a scale operation.
            if ($logEntry.OperationName -notin $allowedOperationNames)
            {
                # Continue.
                continue;
            }

            # If log entry is SQL database (no specific event for SQL database scale up).
            iF ($logEntry.OperationName -eq "Update SQL database")
            {
                # Resource Graph KQL query.
                $resourceGraphQuery = 'resourcechanges | where id startswith "{0}" | where properties.changeAttributes.correlationId == "{1}"' -f $logEntry.ResourceId, $logEntry.CorrelationId;

                # Run Azure Resource Graph query
                $changes = Search-AzGraph  -Query $resourceGraphQuery -First 1;

                # If there is no result.
                if ($changes.Count -lt 1)
                {                
                    # Continue.
                    continue;
                }

                # Check if there is any updates to SKU.
                $skuUpdate = $changes.properties.changes | Get-Member | Where-Object { $_.Name -like '*sku*' };

                # If there is no result.
                if ($skuUpdate.Count -lt 1)
                {
                    # Continue.
                    continue;
                }
            }

            # If log entry is SQL elastic pool (no specific event for SQL database scale up).
            iF ($logEntry.OperationName -eq "Create new or update existing elastic pool")
            {
                # Resource Graph KQL query.
                $resourceGraphQuery = 'resourcechanges | where id startswith "{0}" | where properties.changeAttributes.correlationId == "{1}"' -f $logEntry.ResourceId, $logEntry.CorrelationId;
            
                # Run Azure Resource Graph query
                $changes = Search-AzGraph  -Query $resourceGraphQuery -First 1;
            
                # If there is no result.
                if ($changes.Count -lt 1)
                {                
                    # Continue.
                    continue;
                }
            
                # Check if there is any updates to SKU.
                $skuUpdate = $changes.properties.changes | Get-Member | Where-Object { $_.Name -like '*sku*' };

                # Check if there is any max size bytes.
                $maxSizeBytesUpdate = $changes.properties.changes | Get-Member | Where-Object { $_.Name -like '*maxSizeBytes*' };
            
                # If there is no result.
                if ($SkuUpdate.Count -lt 1 -and $maxSizeBytesUpdate.Count -lt 1)
                {
                    # Continue.
                    continue;
                }
            }

            # Write to log.
            Write-Log -Text ("[{0}][{1}][{2}] Found scale operation on Azure resource" -f $azContext.Subscription.Name, $resource.ResourceGroupName, $resource.ResourceName);

            # Variable to store SKU.
            $resourceSku = $null;

            # Get current SKU of resource.
            if ($resource.ResourceType -eq 'Microsoft.Web/serverfarms')
            {
                # Get SKU.
                $resourceSku = $resource.Sku.Name;
                $resourceTier = $resource.Sku.Tier;
            }
            # Else if resource type is SQL database.
            elseif ($resource.ResourceType -eq 'Microsoft.Sql/servers/databases')
            {
                # Get SKU.
                $resourceSku = $resource.Sku.Name;
                $resourceTier = $resource.Sku.Tier;
            }
            # Else if resource type is Cosmos DB (SQL).
            elseif ($resource.ResourceType -eq 'Microsoft.DocumentDB/databaseAccounts')
            {
                # Get SKU.
                $resourceSku = "N/A";
                $resourceTier = "N/A";
            }

            # Create object resource in.
            $scaledResource = [PSCustomObject]@{
                TenantId          = $azContext.Tenant.Id;
                SubscriptionId    = $azContext.Subscription.Id;
                SubscriptionName  = $azContext.Subscription.Name;
                ResourceGroupName = $resource.ResourceGroupName;
                ResourceName      = $resource.ResourceName;
                ResourceType      = $resource.ResourceType;
                ResourceSku       = $resourceSku;
                ResourceTier      = $resourceTier;
                InitiatedBy       = $logEntry.Caller;
                Time              = $logEntry.EventTimestamp;
                CorrelationId     = $logEntry.CorrelationId;
            };

            # Add to scaled resources object array.
            $scaledResources += $scaledResource;
        }
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# If there is any info in the scaled resources object array.
if ($scaledResources.Count -gt 0)
{
    # Write to log.
    Write-Log -Text ("Exporting result to a CSV file '{0}'" -f $CsvFilePath);

    # Export scaled resources to a CSV file on the desktop.
    $scaledResources | Export-Csv -Path $CsvFilePath -NoTypeInformation -Encoding UTF8;
}

# Write to log.
Write-Log -Text ("Disconnecting from Azure");

# Disconnect from Azure.
Disconnect-AzAccount -ErrorAction SilentlyContinue;

############### Finalize - End ###############
#endregion
