# Must be running PowerShell version 5.1 or higher.
#Requires -Version 5.1;

# Must have the following modules installed.
#Requires -Module Az.Accounts;
#Requires -Module Az.Sql;

<#
.SYNOPSIS
  Set replica count, backup storage redundancy and zone redundancy for Azure SQL resources.

.DESCRIPTION
  Run through all elegible Azure resources and set replica count if applicable.
  Currently supported is SQL database and elastic pool.
  This should ideally be done with ARM-templates, but the functionality is supported in all scenarios yet (hyperscale for an example).

.PARAMETER SqlResourceName
  Name of the SQL resource (database or elastic pool) to set high available settings for.

.PARAMETER ReplicaCount
  Number of replicas to set for the SQL resource.

.PARAMETER BackupStorageRedundancy
  Backup storage redundancy to set for the SQL resource.
  Currently supports local, zone, geo and geozone (geo-zone is only available for hyperscale).

.PARAMETER ZoneRedundancy
  Zone redundancy to set for the SQL resource.

.PARAMETER ReadScaleOut
  Read scale out to set for the SQL resource (only works for premium editions).

.EXAMPLE
  # Set replica count to 1, backup storage redundancy to local, zone redundancy to true and read scale out to disabled for SQL database.
  .\Set-AzureSqlHighAvailability.ps1 -SqlResourceName "mySqlDatabase" -ReplicaCount 1 -BackupStorageRedundancy "Local" -ZoneRedundancy $true -ReadScaleOut "Disabled";

.EXAMPLE
  # Set replicas for SQL elastic pool (0 to 4 supported) only for hyperscale.
  .\Set-AzureSqlHighAvailability.ps1 -SqlResourceName "mySqlElasticPool" -ReplicaCount 0;

.EXAMPLE
  # Disable zone redundancy for SQL elastic pool.
  .\Set-AzureSqlHighAvailability.ps1 -SqlResourceName "mySqlElasticPool" -ZoneRedundancy $false;

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (xalth@pension.dk)
  Creation Date:  26-09-2023
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
param
(
    [Parameter(Mandatory = $true)][string]$SqlResourceName,
    [Parameter(Mandatory = $false)][ValidateRange(0, 4)][int]$ReplicaCount = 0,
    [Parameter(Mandatory = $false)][ValidateSet("Local", "Zone", "Geo", "GeoZone")][string]$BackupStorageRedundancy = "Local",
    [Parameter(Mandatory = $false)][bool]$ZoneRedundancy = $false,
    [Parameter(Mandatory = $false)][ValidateSet("Disabled", "Enabled")]$ReadScaleOut = "Disabled"
)

############### Bootstrap - End ###############
#endregion

#region begin input
############### Variables - Start ###############

# Zone redundancy support.
$DatabaseZoneRedundancySupport = @("GeneralPurpose", "BusinessCritical", "Hyperscale", "Premium");
$ElasticPoolZoneRedundancySupport = @("GeneralPurpose", "BusinessCritical");

# Read scale out support.
$DatabaseReadScaleOutSupport = @("Premium");

# Backup storage redundancy support.
$DatabaseBackupStorageRedundancySupport = @("GeneralPurpose", "BusinessCritical", "Hyperscale", "Basic", "Standard", "Premium");

# Replica count support.
$DatabaseReplicaCountSupport = @("Hyperscale");
$ElasticPoolReplicaCountSupport = @("Hyperscale");

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
        [Parameter(Mandatory = $false)][string]$Text,
        [Parameter(Mandatory = $false)][Switch]$NoTime
    )
  
    # If text is not present.
    if ([string]::IsNullOrEmpty($Text))
    {
        # Write to the console.
        Write-Host("");
    }
    else
    {
        # If no time is specificied.
        if ($NoTime)
        {
            # Write to the console.
            Write-Information -MessageData $Text -InformationAction Continue;
        }
        else
        {
            # Write to the console.
            Write-Information -MessageData ("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text)  -InformationAction Continue;
        }
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get (only MSSQL) Azure resources.
$AzResources = Get-AzResource -Name $SqlResourceName | Where-Object { $_.ResourceType -like "Microsoft.Sql*" };

# If resources is not found.
if ($null -eq $AzResources)
{
    Write-Log ("{0}: Resource not found, skipping" -f $SqlResourceName);
    Write-Log ("Script finished at {0}" -f (Get-Date));
    return;
}

# Get Azure subscription.
$AzSubscription = (Get-AzContext).Subscription;

# For each SQL resource.
foreach ($AzResource in $AzResources)
{
    # If resource type is a elastic pool.
    if ($AzResource.ResourceType -eq "Microsoft.Sql/servers/elasticpools")
    {
        Write-Log ("{0}: Resource is in the resource group '{1}' in subscription '{2}'" -f $SqlResourceName, $AzResource.ResourceGroupName, $AzSubscription.Name);
        Write-Log ("{0}: Resource type is a SQL elastic pool" -f $SqlResourceName);
        
        # Get server name.
        $ServerName = $AzResource.Name.Split("/")[0];

        # Get database name.
        $ElasticPoolName = $AzResource.Name.Split("/")[1];

        # Get Azure SQL elastic pool.
        $AzSqlElasticPool = Get-AzSqlElasticPool -ResourceGroupName $AzResource.ResourceGroupName -ServerName $ServerName -ElasticPoolName $ElasticPoolName;

        Write-Log ("{0}: Elastic pool edition is '{1}'" -f $SqlResourceName, $AzSqlElasticPool.Edition);

        # If the elastic pool SKU support replicas.
        if ($AzSqlElasticPool.Edition -in $ElasticPoolReplicaCountSupport)
        {
            # If replica count is already correct.
            if ($AzSqlElasticPool.HighAvailabilityReplicaCount -eq $ReplicaCount)
            {
                Write-Log ("{0}: Replica count is already set to '{1}', skipping" -f $SqlResourceName, $ReplicaCount);
                continue;
            }

            # Try to set replica count.
            try
            {
                Write-Log ("{0}: Trying to set replica count to '{1}', this might take some time" -f $SqlResourceName, $ReplicaCount);

                # Set replica count.
                Set-AzSqlElasticPool -ResourceGroupName $AzSqlElasticPool.ResourceGroupName -ServerName $AzSqlElasticPool.ServerName -ElasticPoolName $AzSqlElasticPool.ElasticPoolName -HighAvailabilityReplicaCount $ReplicaCount -ErrorAction Stop | Out-Null;

                Write-Log ("{0}: Succesfully set replica count to '{1}'" -f $SqlResourceName, $ReplicaCount);
            }
            # Something went wrong setting the replica count.
            catch
            {
                Write-Log ("{0}: Could not set replica count, here is the execption:");
                Write-Log -NoTime ($_);
            }
        }
        # Else the elastic pool SKU dont support replicas.
        else
        {
            Write-Log ("{0}: Elastic pool edition dont support replicas" -f $SqlResourceName);
        }

        # If the elastic pool SKU supports zone redundancy.
        if ($AzSqlElasticPool.Edition -in $ElasticPoolZoneRedundancySupport)
        {
            # If zone redundancy is already correct.
            if ($AzSqlElasticPool.ZoneRedundant -eq $ZoneRedundancy)
            {
                Write-Log ("{0}: Zone redundancy is already set to '{1}', skipping" -f $SqlResourceName, $ZoneRedundancy);
                continue;
            }

            # Try to set the zone redundancy.
            try
            {
                Write-Log ("{0}: Trying to set zone redundancy to '{1}', this might take some time" -f $SqlResourceName, $ZoneRedundancy);

                # Set zone redundancy.
                Set-AzSqlElasticPool -ResourceGroupName $AzSqlElasticPool.ResourceGroupName -ServerName $AzSqlElasticPool.ServerName -ElasticPoolName $AzSqlElasticPool.ElasticPoolName -ZoneRedundant:$ZoneRedundancy -ErrorAction Stop | Out-Null;

                Write-Log ("{0}: Succesfully set zone redundancy to '{1}'" -f $SqlResourceName, $ZoneRedundancy);
            }
            # Something went wrong setting the zone redundancy.
            catch
            {
                Write-Log ("{0}: Could not set zone redundancy, here is the execption:");
                Write-Log -NoTime ($_);
            }
        }
        # Else elastic pool SKU does not support zone redundancy.
        else
        {
            Write-Log ("{0}: Elastic pool edition dont support zone redundancy" -f $SqlResourceName);
        }
    }
    # Else if resource type is a SQL database.
    elseif ($AzResource.ResourceType -eq "Microsoft.Sql/servers/databases")
    {
        Write-Log ("{0}: Resource is in the resource group '{1}' in subscription '{2}'" -f $SqlResourceName, $AzResource.ResourceGroupName, $AzSubscription.Name);
        Write-Log ("{0}: Resource type is a SQL database" -f $SqlResourceName);

        # Get server name.
        $ServerName = $AzResource.Name.Split("/")[0];

        # Get database name.
        $DatabaseName = $AzResource.Name.Split("/")[1];
    
        # Get Azure SQL database.
        $AzSqlDatabase = Get-AzSqlDatabase -ResourceGroupName $AzResource.ResourceGroupName -ServerName $ServerName -DatabaseName $DatabaseName;

        Write-Log ("{0}: Database edition is '{1}'" -f $SqlResourceName, $AzSqlDatabase.Edition);

        # If the SQL database is member of a elastic pool.
        if ($null -ne $AzSqlDatabase.ElasticPoolName)
        {
            Write-Log ("{0}: SQL database is member of a elastic pool, skipping" -f $SqlResourceName);
            continue;
        }

        # If the database SKU supports zone redundancy.
        if ($AzSqlElasticPool.Edition -in $DatabaseReplicaCountSupport)
        {
            # If replica count is already correct.
            if ($AzSqlDatabase.HighAvailabilityReplicaCount -eq $ReplicaCount)
            {
                Write-Log ("{0}: Replica count is already set to '{1}', skipping" -f $SqlResourceName, $ReplicaCount);
                continue;
            }

            # Try to set replica count.
            try
            {
                Write-Log ("{0}: Trying to set replica count to '{1}', this might take some time" -f $SqlResourceName, $ReplicaCount);
    
                # Set replica count.
                Set-AzSqlDatabase -ResourceGroupName $AzSqlDatabase.ResourceGroupName -ServerName $AzSqlDatabase.ServerName -DatabaseName $AzSqlDatabase.DatabaseName -HighAvailabilityReplicaCount $ReplicaCount -ErrorAction Stop | Out-Null;
    
                Write-Log ("{0}: Succesfully set replica count to '{1}'" -f $SqlResourceName, $ReplicaCount);
            }
            # Something went wrong setting the replica count.
            catch
            {
                Write-Log ("{0}: Could not set replica count, here is the execption:");
                Write-Log -NoTime ($_);
            }
        }
        # Else the database SKU dont support replicas.
        else
        {
            Write-Log ("{0}: SQL database edition dont support replicas " -f $SqlResourceName);
        }

        # If the database supports zone redundancy.
        if ($AzSqlDatabase.Edition -in $DatabaseZoneRedundancySupport)
        {
            # If zone redundancy is already correct.
            if ($AzSqlDatabase.ZoneRedundant -eq $ZoneRedundancy)
            {
                Write-Log ("{0}: Zone redundancy is already set to '{1}', skipping" -f $SqlResourceName, $ZoneRedundancy);
                continue;
            }

            # Try to set the zone redundancy.
            try
            {
                Write-Log ("{0}: Trying to set zone redundancy to '{1}', this might take some time" -f $SqlResourceName, $ZoneRedundancy);

                # Set zone redundancy.
                Set-AzSqlDatabase -ResourceGroupName $AzSqlDatabase.ResourceGroupName -ServerName $AzSqlDatabase.ServerName -DatabaseName $AzSqlDatabase.DatabaseName -ZoneRedundant:$ZoneRedundancy -ErrorAction Stop | Out-Null;

                Write-Log ("{0}: Succesfully set zone redundancy to '{1}'" -f $SqlResourceName, $ZoneRedundancy);
            }
            # Something went wrong setting the zone redundancy.
            catch
            {
                Write-Log ("{0}: Could not set zone redundancy, here is the execption:");
                Write-Log -NoTime ($_);
            }
        }
        # Else database SKU does not support zone redundancy.
        else
        {
            Write-Log ("{0}: SQL database edition dont support zone redundancy" -f $SqlResourceName);
        }

        # If the database support read scale out.
        if ($AzSqlDatabase.Edition -in $DatabaseReadScaleOutSupport)
        {
            # If read scale out is already correct.
            if ($AzSqlDatabase.ReadScale -eq $ReadScaleOut)
            {
                Write-Log ("{0}: Read scale out is already set to '{1}', skipping" -f $SqlResourceName, $ReadScaleOut);
                continue;
            }

            # Try to set the read scale out.
            try
            {
                Write-Log ("{0}: Trying to set read scale out to '{1}', this might take some time" -f $SqlResourceName, $ReadScaleOut);

                # Set read scale out.
                Set-AzSqlDatabase -ResourceGroupName $AzSqlDatabase.ResourceGroupName -ServerName $AzSqlDatabase.ServerName -DatabaseName $AzSqlDatabase.DatabaseName -ReadScale $ReadScaleOut -ErrorAction Stop | Out-Null;

                Write-Log ("{0}: Succesfully set read scale out to '{1}'" -f $SqlResourceName, $ReadScaleOut);
            }
            # Something went wrong setting the read scale out.
            catch
            {
                Write-Log ("{0}: Could not set read scale out, here is the execption:");
                Write-Log -NoTime ($_);
            }
        }
        # Else database SKU does not support read scale out.
        else
        {
            Write-Log ("{0}: SQL database edition dont support read scale out" -f $SqlResourceName);
        }

        # If the database supports backup storage redundancy.
        if ($AzSqlDatabase.Edition -in $DatabaseBackupStorageRedundancySupport)
        {
            # Set variable to the backup storage redundancy.
            $SetBackupStorageRedundancy = $BackupStorageRedundancy;

            # If backup storage redundancy is set to GeoZone and edition is not hyperscale.
            if (($BackupStorageRedundancy -eq "GeoZone") -and ($AzSqlDatabase.Edition -ne "Hyperscale"))
            {
                Write-Log ("{0}: Backup storage redundancy is set to '{1}', but edition is not hyperscale, setting to Geo" -f $SqlResourceName, $BackupStorageRedundancy);
                
                # Set backup storage redundancy to Geo.
                $SetBackupStorageRedundancy = "Geo";
            }

            # If backup storage redundancy is already correct.
            if ($AzSqlDatabase.CurrentBackupStorageRedundancy -eq $SetBackupStorageRedundancy)
            {
                Write-Log ("{0}: Backup storage redundancy is already set to '{1}', skipping" -f $SqlResourceName, $SetBackupStorageRedundancy);
                continue;
            }

            # Try to set the backup storage redundancy.
            try
            {
                Write-Log ("{0}: Trying to set backup storage redundancy to '{1}', this might take some time" -f $SqlResourceName, $SetBackupStorageRedundancy);

                # Set backup storage redundancy.
                Set-AzSqlDatabase -ResourceGroupName $AzSqlDatabase.ResourceGroupName -ServerName $AzSqlDatabase.ServerName -DatabaseName $AzSqlDatabase.DatabaseName -BackupStorageRedundancy $SetBackupStorageRedundancy -ErrorAction Stop | Out-Null;

                Write-Log ("{0}: Succesfully set backup storage redundancy to '{1}'" -f $SqlResourceName, $SetBackupStorageRedundancy);
            }
            # Something went wrong setting the backup storage redundancy.
            catch
            {
                Write-Log ("{0}: Could not set backup storage redundancy, here is the execption:");
                Write-Log -NoTime ($_);
            }
        }
        # Else database SKU does not support backup storage redundancy.
        else
        {
            Write-Log ("{0}: SQL database edition dont support backup storage redundancy" -f $SqlResourceName);
        }
    }
    # Else resource is not supported.
    else
    {
        Write-Log ("{0}: Resource ({1}) is not a valid type, skipping" -f $SqlResourceName, $AzResource.ResourceType);
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

Write-Log ("Script finished at {0}" -f (Get-Date));

############### Finalize - End ###############
#endregion
