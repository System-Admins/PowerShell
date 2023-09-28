# Must be running PowerShell version 5.1 or higher.
#Requires -Version 5.1;

# Must have the following modules installed.
#Requires -Module Az.Accounts;
#Requires -Module Az.CosmosDB;
#Requires -Module Az.Resources;

<#
.SYNOPSIS
  Set throughput value on the Cosmos DB database/container based on JSON input.
  Currently the script only support SQL API accounts.

.DESCRIPTION
  Go through the JSON input and check if the throughput settings is correct on the Cosmos DB account.
  If not then it will try to set the correct throughput settings accordingly.
  To set throughput on a database only, set the "ContainerName" to an empty string in the JSON input.
  If you need to set throughput on a container (that is not member of an shared pool), specify the "ContainerName" in the JSON input.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  28-09-2023
  Purpose/Change: Initial script development

.PARAMETER AccountName
  The name of the Cosmos DB account.

.PARAMETER ThroughputInput
  The JSON input to set throughput on the Cosmos DB account.
  Example of JSON input:
  [
    {
        "DatabaseName":  "myDatabase1",
        "ContainerName":  "",
        "AutoscaleEnabled":  true,
        "Throughput":  15000
    },
    {
        "DatabaseName":  "myDatabase1",
        "ContainerName":  "myContainer1",
        "AutoscaleEnabled":  false,
        "Throughput":  8000
    }
  ]

.EXAMPLE
  .\Set-CosmosDbThroughput.ps1 -AccountName "<Cosmos DB acocunt name>" -ThroughputInput "<JSON input>";
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
Param
(
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9-]{3,44}$')][string]$AccountName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ThroughputInput
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

# Test JSON.
function Test-Json
{
    param
    (
        [Parameter(Mandatory = $true)][string]$JsonString
    )

    # Valid JSON input.
    [bool]$validJson = $true;
 
    # Try to test string.
    try
    {
        # Try to convert input string to JSON object.
        $jsonObjects = $JsonString | ConvertFrom-Json;
    }
    # Something went wrong.
    catch
    {
        # Not a valid JSON object.
        $validJson = $false;
    }

    # Valid JSON object keys.
    $validJsonKeys = @(
        "DatabaseName",
        "ContainerName",
        "AutoscaleEnabled",
        "Throughput"
    );

    # Check if JSON objects is valid.
    foreach ($jsonObject in $jsonObjects)
    {
        # Foreach valid JSON key.
        foreach ($validJsonKey in $validJsonKeys)
        {
            # If JSON object dont have the key.
            if ($null -eq $jsonObject.$validJsonKey)
            {
                # Not a valid JSON object.
                $validJson = $false;
            }
        } 
    }

    # If valid.
    if ($true -eq $validJson)
    {
        # Return valid.
        return $true;
    }
    # Else invalid.
    else
    {
        # Return not valid.
        return $false;
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log ("Script started at {0}" -f (Get-Date));

# Get Cosmos DB account.
$CosmosDbAccount = Get-AzResource -ResourceType 'Microsoft.DocumentDB/databaseAccounts' -Name $AccountName;

# If the Cosmos DB account dont exist.
if ($null -eq $CosmosDbAccount)
{
    # Throw exception.
    throw ("The Cosmos DB account '{0}' dont exist" -f $AccountName);
}

# If JSON input is valid. 
if ($false -eq (Test-Json -JsonString $ThroughputInput))
{
    # Throw execption.
    throw ("The following JSON input is not valid:`r`n'{0}'" -f $JsonThroughputSettings);
}

# Convert string to JSON.
$declaredThroughputSettings = ConvertFrom-Json -InputObject $ThroughputInput;

# Get all throughput settings for databases only.
$declaredDatabaseThroughputSettings = $declaredThroughputSettings | Where-Object { [string]::IsNullOrEmpty($_.ContainerName) };

# Get all throughput settings for containers only.
$declaredContainerThroughputSettings = $declaredThroughputSettings | Where-Object { -not [string]::IsNullOrEmpty($_.ContainerName) };

# Container counter.
$databaseCounter = 1;

# If there is some databases to update.
if ($declaredDatabaseThroughputSettings.Count -gt 0)
{
    # Write to log.
    Write-Log ("");

    # Write to log.
    Write-Log ("[{0}] Databases ({1}) to check throughput settings:" -f $CosmosDbAccount.Name, $declaredDatabasesThroughputSettings.Count);
    
    # Foreach database.
    foreach ($declaredDatabaseThroughputSetting in $declaredDatabaseThroughputSettings)
    {
        # Write to log.
        Write-Log ("{0}. Account: {1} | Database: {2} | Autoscale: {3} | Throughput: {4}" -f $databaseCounter, $CosmosDbAccount.Name, $declaredContainerThroughputSetting.DatabaseName, $declaredContainerThroughputSetting.AutoscaleEnabled, $declaredContainerThroughputSetting.Throughput);

        # Add to counter.
        $databaseCounter++;
    }

    # Write to log.
    Write-Log ("");
}

# Foreach database to adjust throughput (R/U).
foreach ($declaredDatabaseThroughputSetting in $declaredDatabaseThroughputSettings[0])
{
    # Variables.
    [bool]$autoscaleEnabledOnDatabase = $false;
    [int]$throughputValue = 0;

    # Get Cosmos DB database
    $cosmosDbDatabase = Get-AzCosmosDBSqlDatabase -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $declaredDatabaseThroughputSetting.DatabaseName -ErrorAction SilentlyContinue;

    # If database is not found.
    if ($null -eq $cosmosDbDatabase)
    {
        # Write to log.
        Write-Log ("[{0}][{1}] Database not found, skipping" -f $CosmosDbAccount.Name, $declaredDatabaseThroughputSetting.DatabaseName);
    
        # Continue to next database.
        continue;
    }

    # Try to convert autoscale to boolean.
    try
    {
        # Convert string to boolean.
        [bool]$declaredDatabaseThroughputSetting.AutoscaleEnabled = [System.Convert]::ToBoolean($declaredDatabaseThroughputSetting.AutoscaleEnabled);
    }
    # Something went wrong while converting.
    catch
    {
        # Write to log.
        Write-Log ("[{0}][{1}] Autoscale value '{2}' of database not valid from JSON, skipping" -f $CosmosDbAccount.Name, $declaredDatabaseThroughputSetting.DatabaseName, $declaredDatabaseThroughputSetting.AutoscaleEnabled);

        # Continue to next database.
        contiune;
    }
    
    # If throughput value is empty.
    if ([string]::IsNullOrEmpty($declaredDatabaseThroughputSetting.Throughput))
    {
        # Write to log.
        Write-Log ("[{0}][{1}] Throughput value is empty, skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name);

        # Continue to next database.
        continue;
    }

    # Get throughput settings on the database.
    $cosmosDbDatabaseThroughput = Get-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $declaredDatabaseThroughputSetting.DatabaseName -ErrorAction SilentlyContinue;

    # If there is no throughput settings on the database.
    if ($null -eq $cosmosDbDatabaseThroughput)
    {
        # Write to log.
        Write-Log ("[{0}][{1}] Shared throughput on database is not enabled, skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name);

        # Continue to next database.
        continue;
    }

    # If autoscale is enabled.
    if ($cosmosDbDatabaseThroughput.AutoscaleSettings.MaxThroughput -ne 0)
    {
        # Autoscale is enabled.
        $autoscaleEnabledOnDatabase = $true;

        # Set throughput value.
        $throughputValue = $cosmosDbDatabaseThroughput.AutoscaleSettings.MaxThroughput;
    }
    # Else autoscale is not enabled.
    else
    {
        # Set throughput value.
        $throughputValue = $cosmosDbDatabaseThroughput.Throughput;
    }

    # If autoscale should be enabled or disabled.
    if ($declaredDatabaseThroughputSetting.AutoscaleEnabled -ne $autoscaleEnabledOnDatabase)
    {
        # If manual.
        if ($false -eq $declaredDatabaseThroughputSetting.AutoscaleEnabled)
        {
            # Set throughput type.
            [string]$throughputType = "Manual";
        }
        # Else use autoscale.
        else
        {
            # Set throughput type.
            [string]$throughputType = "Autoscale";
        }

        # Write to log.
        Write-Log ("[{0}][{1}] Autoscale should be set to '{2}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $throughputType);

        # Try to change autoscale setting.
        try
        {
            # Write to log.
            Write-Log ("[{0}][{1}] Trying to change autoscale to '{2}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $throughputType);
        
            # Invoke autoscale migration.
            Invoke-AzCosmosDBSqlDatabaseThroughputMigration -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $cosmosDbDatabase.Name -ThroughputType $throughputType | Out-Null;

            # Write to log.
            Write-Log ("[{0}][{1}] Successfully change autoscale to '{2}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $throughputType);
        }
        catch
        {
            # Write to log.
            Write-Log ("[{0}][{1}] Something went wrong change autoscale, here is the execption: `r`n{2}" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $_);
        }

        # Update throughput settings from the database.
        $cosmosDbDatabaseThroughput = Get-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $declaredDatabaseThroughputSetting.DatabaseName -ErrorAction SilentlyContinue;

        # If autoscale is enabled.
        if ($cosmosDbDatabaseThroughput.AutoscaleSettings.MaxThroughput -ne 0)
        {
            # Autoscale is enabled.
            $autoscaleEnabledOnDatabase = $true;
        }
        # Else autoscale is not enabled.
        else
        {
            # Autoscale is disabled.
            $autoscaleEnabledOnDatabase = $false;
        }
    }
    # Else autoscale setting already correct.
    else
    {
        # Write to log.
        Write-Log ("[{0}][{1}] Autoscale already set to '{2}', skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $autoscaleEnabledOnDatabase);
    }

    # If throughput value is already correct.
    if ($throughputValue -eq ($declaredDatabaseThroughputSetting.Throughput -as [int]))
    {
        # Write to log.
        Write-Log ("[{0}][{1}] Throughput value is already set to '{2}', skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $throughputValue);

        # Continue to next database.
        continue;
    }
    # Else we need to update the throughput value.
    else
    {
        # Get nearest thousands for throughput.
        $throughputNearestThounds = [math]::Ceiling($declaredDatabaseThroughputSetting.Throughput / 1000) * 1000;

        # If throughput value and nearest thousands is not the same.
        if ($throughputNearestThounds -ne $declaredDatabaseThroughputSetting.Throughput)
        {
            # Write to log.
            Write-Log ("[{0}][{1}] Throughput value must be specified as whole thousands, changing input value from '{2}' to '{3}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $declaredDatabaseThroughputSetting.Throughput, $throughputNearestThounds);

            # Update value.
            $declaredDatabaseThroughputSetting.Throughput = $throughputNearestThounds;
        }

        # Try to change throughput.
        try
        {
            # Write to log.
            Write-Log ("[{0}][{1}] Trying to change throughput to '{2}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $declaredDatabaseThroughputSetting.Throughput);
        
            # If autoscale is enabled use max throughput.
            if ($true -eq $autoscaleEnabledOnDatabase)
            {
                # Change throughput.
                Update-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $cosmosDbDatabase.Name -AutoscaleMaxThroughput $declaredDatabaseThroughputSetting.Throughput -ErrorAction Stop | Out-Null;
            }
            # Else autoscale is not enabled use static throughput.
            else
            {
                # Change throughput.
                Update-AzCosmosDBSqlDatabaseThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $cosmosDbDatabase.Name -Throughput $declaredDatabaseThroughputSetting.Throughput -ErrorAction Stop | Out-Null;
            }

            # Write to log.
            Write-Log ("[{0}][{1}] Successfully change throughput to '{2}', scale up can take up to 6 hours" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $declaredDatabaseThroughputSetting.Throughput);
        }
        # Something went wrong changing the throughput.
        catch
        {
            # Write to log.
            Write-Log ("[{0}][{1}] Something went wrong change throughput, here is the execption: `r`n{2}" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $_);
        }
    }
}

# Container counter.
$containerCounter = 1;

# If there is some containers to update.
if ($declaredContainerThroughputSettings.Count -gt 0)
{
    # Write to log.
    Write-Log ("");
    
    # Write to log.
    Write-Log ("[{0}] Containers ({1}) to check throughput settings:" -f $CosmosDbAccount.Name, $declaredContainerThroughputSettings.Count);
    
    # Foreach container.
    foreach ($declaredContainerThroughputSetting in $declaredContainerThroughputSettings)
    {
        # Write to log.
        Write-Log ("{0}. Account: {1} | Database: {2} | Container: {3} | Autoscale: {4} | Throughput: {5}" -f $containerCounter, $CosmosDbAccount.Name, $declaredContainerThroughputSetting.DatabaseName, $declaredContainerThroughputSetting.ContainerName, $declaredContainerThroughputSetting.AutoscaleEnabled, $declaredContainerThroughputSetting.Throughput);

        # Add to counter.
        $containerCounter++;
    }

    # Write to log.
    Write-Log ("");
}

# Foreach container to adjust throughput (R/U).
foreach ($declaredContainerThroughputSetting in $declaredContainerThroughputSettings)
{
    # Variables.
    [bool]$autoscaleEnabledOnContainer = $false;
    [int]$throughputValue = 0;

    # Get Cosmos DB database
    $cosmosDbDatabase = Get-AzCosmosDBSqlDatabase -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $declaredContainerThroughputSetting.DatabaseName -ErrorAction SilentlyContinue;

    # If database is not found.
    if ($null -eq $cosmosDbDatabase)
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Database not found, skipping" -f $CosmosDbAccount.Name, $declaredContainerThroughputSetting.DatabaseName, $declaredContainerThroughputSetting.ContainerName);
     
        # Continue to next container.
        continue;
    }

    # Get Cosmos DB container.
    $cosmosDbContainer = Get-AzCosmosDBSqlContainer -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $cosmosDbDatabase.Name -Name $declaredContainerThroughputSetting.ContainerName -ErrorAction SilentlyContinue;

    # If container is not found.
    if ($null -eq $cosmosDbContainer)
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Container not found, skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $declaredContainerThroughputSetting.ContainerName);
    
        # Continue to next container.
        continue;
    }

    # Try to convert autoscale to boolean.
    try
    {
        # Convert string to boolean.
        [bool]$declaredContainerThroughputSetting.AutoscaleEnabled = [System.Convert]::ToBoolean($declaredContainerThroughputSetting.AutoscaleEnabled);
    }
    # Something went wrong while converting.
    catch
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Autoscale value '{3}' of container not valid from JSON, skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $declaredContainerThroughputSetting.AutoscaleEnabled);
    
        # Continue to next container.
        contiune;
    }

    # If throughput value is empty.
    if ([string]::IsNullOrEmpty($declaredContainerThroughputSetting.Throughput))
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Throughput value is empty, skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name);
    
        # Continue to next container.
        continue;
    }

    # Get throughput settings on the container.
    $cosmosDbContainerThroughput = Get-AzCosmosDBSqlContainerThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $cosmosDbDatabase.Name -Name $cosmosDbContainer.Name -ErrorAction SilentlyContinue;

    # If there is no throughput settings on the container (must be shared pool).
    if ($null -eq $cosmosDbContainerThroughput)
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Container is using database shared throughput, skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name);

        # Continue to next container.
        continue;
    }
    
    # If autoscale is enabled.
    if ($cosmosDbContainerThroughput.AutoscaleSettings.MaxThroughput -ne 0)
    {
        # Autoscale is enabled.
        $autoscaleEnabledOnContainer = $true;
    
        # Set throughput value.
        $throughputValue = $cosmosDbContainerThroughput.AutoscaleSettings.MaxThroughput;
    }
    # Else autoscale is not enabled.
    else
    {
        # Set throughput value.
        $throughputValue = $cosmosDbContainerThroughput.Throughput;
    }

    # If autoscale should be enabled or disabled.
    if ($declaredContainerThroughputSetting.AutoscaleEnabled -ne $autoscaleEnabledOnContainer)
    {
        # If manual.
        if ($false -eq $declaredContainerThroughputSetting.AutoscaleEnabled)
        {
            # Set throughput type.
            [string]$throughputType = "Manual";
        }
        # Else use autoscale.
        else
        {
            # Set throughput type.
            [string]$throughputType = "Autoscale";
        }

        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Autoscale should be set to '{3}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $throughputType);

        # Try to change autoscale setting.
        try
        {
            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Trying to change autoscale to '{3}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $throughputType);
        
            # Invoke autoscale migration.
            Invoke-AzCosmosDBSqlContainerThroughputMigration -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $cosmosDbDatabase.Name -Name $cosmosDbContainer.Name -ThroughputType $throughputType | Out-Null;

            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Successfully change autoscale to '{3}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $throughputType);
        }
        catch
        {
            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Something went wrong change autoscale, here is the execption: `r`n{3}" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $_);
        }

        # Update throughput settings from the container.
        $cosmosDbContainerThroughput = Get-AzCosmosDBSqlContainerThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $cosmosDbDatabase.Name -Name $cosmosDbContainer.Name -ErrorAction SilentlyContinue;

        # If autoscale is enabled.
        if ($cosmosDbContainerThroughput.AutoscaleSettings.MaxThroughput -ne 0)
        {
            # Autoscale is enabled.
            $autoscaleEnabledOnContainer = $true;
        }
        # Else autoscale is not enabled.
        else
        {
            # Autoscale is disabled.
            $autoscaleEnabledOnContainer = $false;
        }
    }
    # Else autoscale setting already correct.
    else
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Autoscale already set to '{3}', skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $autoscaleEnabledOnDatabase);
    }

    # If throughput value is already correct.
    if ($throughputValue -eq ($declaredContainerThroughputSetting.Throughput -as [int]))
    {
        # Write to log.
        Write-Log ("[{0}][{1}][{2}] Throughput value is already set to '{3}', skipping" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $throughputValue);

        # Continue to next container.
        continue;
    }
    # Else we need to update the throughput value.
    else
    {
        # Get nearest thousands for throughput.
        $throughputNearestThounds = [math]::Ceiling($declaredContainerThroughputSetting.Throughput / 1000) * 1000;

        # If throughput value and nearest thousands is not the same.
        if ($throughputNearestThounds -ne ($declaredContainerThroughputSetting.Throughput -as [int]))
        {
            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Throughput value must be specified as whole thousands, changing input value from '{3}' to '{4}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $declaredContainerThroughputSetting.Throughput, $throughputNearestThounds);

            # Update value.
            $declaredContainerThroughputSetting.Throughput = $throughputNearestThounds;
        }

        # Try to change throughput.
        try
        {
            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Trying to change throughput to '{3}'" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $declaredContainerThroughputSetting.Throughput);
        
            # If autoscale is enabled use max throughput.
            if ($true -eq $autoscaleEnabledOnDatabase)
            {
                # Change throughput.
                Update-AzCosmosDBSqlContainerThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $cosmosDbDatabase.Name -Name $cosmosDbContainer.Name -AutoscaleMaxThroughput $declaredContainerThroughputSetting.Throughput  -ErrorAction Stop | Out-Null;
            }
            # Else autoscale is not enabled use static throughput.
            else
            {
                # Change throughput.
                Update-AzCosmosDBSqlContainerThroughput -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $cosmosDbDatabase.Name -Name $cosmosDbContainer.Name -Throughput $declaredContainerThroughputSetting.Throughput -ErrorAction Stop | Out-Null;
            }

            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Successfully change throughput to '{3}', scale up can take up to 6 hours" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $throughputNearestThounds);
        }
        # Something went wrong changing the throughput.
        catch
        {
            # Write to log.
            Write-Log ("[{0}][{1}][{2}] Something went wrong change throughput, here is the execption: `r`n{3}" -f $CosmosDbAccount.Name, $cosmosDbDatabase.Name, $cosmosDbContainer.Name, $_);
        }
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
