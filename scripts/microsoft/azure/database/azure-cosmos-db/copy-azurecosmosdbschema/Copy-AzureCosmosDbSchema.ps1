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
  Copy Cosmos DB schema to another account.

.DESCRIPTION
  This script allows you to copy a Azure Cosmos DB schema (databases and containers). The script is split in two parts with the "action" parameter.
  Export = Exports account, database and container info to a file in temp.
  Import = Creates account, database and containers if it doesnt exist.
  
  Usage would be:
  .\Copy-AzureCosmosDbSchema.ps1 -Action "Export" -ResourceGroupName "<source resource group name>" -AccountName "<source Cosmos DB account>"
  .\Copy-AzureCosmosDbSchema.ps1 -Action "Import" -ResourceGroupName "<target resource group name>" -AccountName "<target Cosmos DB account>"

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  08-07-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
[cmdletbinding()]
Param
(    
    # Action.
    [Parameter(Mandatory=$true)][ValidateSet("Export", "Import")][string]$Action,
    
    # Cosmos DB account.
    [Parameter(Mandatory=$true)][string]$ResourceGroupName,
    [Parameter(Mandatory=$true)][string]$AccountName
)

# Clear host.
#Clear-Host;

# Import module(s).
Import-Module -Name Az.Accounts -Force -DisableNameChecking;
Import-Module -Name Az.CosmosDB -Force -DisableNameChecking;

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
        [Parameter(Mandatory=$false)][string]$Text
    )
  
    # If text is not present.
    If([string]::IsNullOrEmpty($Text))
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

# Export database and container information from Cosmos Db.
Function Export-CosmosDbAccountInfo
{
    [CmdletBinding()]
    param
    (
        # Resource group.
        [Parameter(Mandatory=$true)][string]$ResourceGroupName,

        # Account name.
        [Parameter(Mandatory=$true)][string]$CosmosDbAccountName
    )

    # Object array to store all containers to migrate.
    $Databases = @();
    $Containers = @();

    # If CosmosDb account exists.
    If($CosmosDbAccount = Get-AzCosmosDBAccount -ResourceGroupName $ResourceGroupName -Name $CosmosDbAccountName)
    {
        # Write to log.
        Write-Log ("Found Cosmos DB account '{0}' in resource group '{1}'" -f $CosmosDbAccountName, $ResourceGroupName);

        # Get CosmosDb SQL databases.
        $CosmosDbSqlDatabases = Get-AzCosmosDBSqlDatabase -ResourceGroupName $ResourceGroupName -AccountName $CosmosDbAccount.Name;

        # Foreach database.
        Foreach($CosmosDbSqlDatabase in $CosmosDbSqlDatabases)
        {
            # Write to log.
            Write-Log ("Getting info from database '{0}' from account '{1}' in resource group '{2}'" -f $CosmosDbSqlDatabase.Name, $CosmosDbAccount.Name, $ResourceGroupName);

            # Add to results.
            $Databases += [PSCustomObject]@{
                ResourceGroup = $ResourceGroupName;
                Account = $CosmosDbAccount.Name
                Name = $CosmosDbSqlDatabase.Name;
                Id = $CosmosDbSqlDatabase.Resource.Id;
            };

            # Get CosmosDb containers.
            $CosmosDbContainers = Get-AzCosmosDBSqlContainer -ResourceGroupName $ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $CosmosDbSqlDatabase.Name;

            # Foreach container.
            Foreach($CosmosDbContainer in $CosmosDbContainers)
            {
                # Write to log.
                Write-Log ("Getting info from container '{0}' in database '{1}' from account '{2}' in resource group '{3}'" -f $CosmosDbContainer.Name, $CosmosDbSqlDatabase.Name, $CosmosDbAccount.Name, $ResourceGroupName);

                # Add to results.
                $Containers += [PSCustomObject]@{
                    ResourceGroup = $ResourceGroupName;
                    Type = "SQL";
                    Account = $CosmosDbAccount.Name
                    Database = $CosmosDbSqlDatabase.Name;
                    Name = $CosmosDbContainer.Name;
                    IndexingPolicy = $CosmosDbContainer.Resource.IndexingPolicy;
                    PartitionKey = $CosmosDbContainer.Resource.PartitionKey;
                    DefaultTtl = $CosmosDbContainer.Resource.DefaultTtl
                    UniqueKeyPolicy = $CosmosDbContainer.Resource.UniqueKeyPolicy;
                    ClientEncryptionPolicy = $CosmosDbContainer.Resource.ClientEncryptionPolicy;
                    AnalyticalStorageTtl = $CosmosDbContainer.Resource.AnalyticalStorageTtl;
                };
            }
        }

        

        # Add to result.
        $Account = [PSCustomObject]@{
            ResourceGroupName = $ResourceGroupName;
            ApiKind = "Sql";
            Name = $CosmosDbAccount.Name;
            EnableAutomaticFailover = $CosmosDbAccount.EnableAutomaticFailover;
            EnableMultipleWriteLocations = $CosmosDbAccount.EnableMultipleWriteLocations;
            DisableKeyBasedMetadataWriteAccess = $CosmosDbAccount.DisableKeyBasedMetadataWriteAccess;
            EnableFreeTier = $CosmosDbAccount.EnableFreeTier;
            Location = $CosmosDbAccount.Location;
            DefaultConsistencyLevel = $CosmosDbAccount.ConsistencyPolicy.DefaultConsistencyLevel;
            MaxStalenessIntervalInSeconds = $CosmosDbAccount.ConsistencyPolicy.MaxIntervalInSeconds;
            MaxStalenessPrefix = $CosmosDbAccount.ConsistencyPolicy.MaxStalenessPrefix;
            PublicNetworkAccess = $CosmosDbAccount.PublicNetworkAccess;
            EnableAnalyticalStorage = $CosmosDbAccount.EnableAnalyticalStorage;
            NetworkAclBypass = $CosmosDbAccount.NetworkAclBypass;
        };

        # Return data.
        Return [PSCustomObject]@{
            Account = $Account;
            Databases = $Databases;
            Containers = $Containers;
        };
    }
    # Cosmos Db account doesnt exist.
    Else
    {
        # Write to log.
        Write-Log ("Did not find Cosmos DB account '{0}' (source) in resource group '{1}'" -f $CosmosDbAccountName, $ResourceGroupName);
    }
}

# Import database and container information to new Cosmos Db.
Function Import-CosmosDbAccountInfo
{
    [CmdletBinding()]
    param
    (
        # Resource group.
        [Parameter(Mandatory=$true)][string]$ResourceGroupName,

        # Account name.
        [Parameter(Mandatory=$true)][string]$CosmosDbAccountName,

        # Exported CosmosDB info.
        [Parameter(Mandatory=$true)]$CosmosDbInfo
    )

    # Get subscription.
    $Subscription = (Get-AzContext).Subscription;

    # Get context.
    $AzContext = Get-AzContext;

    # Get access token.
    $AccessToken = Get-AzAccessToken;
    
    # If resource group exist.
    If($ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)
    {
        # If CosmosDb account dont exists.
        If(!($CosmosDbAccount = Get-AzCosmosDBAccount -ResourceGroupName $ResourceGroupName -Name $CosmosDbAccountName -ErrorAction SilentlyContinue))
        {
            # Write to log.
            Write-Log ("Creating DB account '{0}' in resource group '{1}', this might take up to 5 minutes" -f $CosmosDbAccountName, $ResourceGroup.ResourceGroupName);

            # Try to create.
            Try
            {
                # Create new account.
                New-AzCosmosDBAccount -EnableAutomaticFailover:$CosmosDbInfo.Account.EnableAutomaticFailover `
                                      -EnableMultipleWriteLocations:$CosmosDbInfo.Account.EnableMultipleWriteLocations `
                                      -ApiKind Sql `
                                      -DisableKeyBasedMetadataWriteAccess:$CosmosDbInfo.Account.DisableKeyBasedMetadataWriteAccess `
                                      -EnableFreeTier $CosmosDbInfo.Account.EnableFreeTier `
                                      -Location $ResourceGroup.Location `
                                      -ResourceGroupName $ResourceGroup.ResourceGroupName `
                                      -Name $CosmosDbAccountName `
                                      -DefaultConsistencyLevel $CosmosDbInfo.Account.ConsistencyPolicy.DefaultConsistencyLevel `
                                      -MaxStalenessIntervalInSeconds $CosmosDbInfo.Account.ConsistencyPolicy.MaxIntervalInSeconds `
                                      -MaxStalenessPrefix $CosmosDbInfo.Account.ConsistencyPolicy.MaxStalenessPrefix `
                                      -PublicNetworkAccess $CosmosDbInfo.Account.PublicNetworkAccess `
                                      -EnableAnalyticalStorage $CosmosDbInfo.Account.EnableAnalyticalStorage `
                                      -NetworkAclBypass $CosmosDbInfo.Account.NetworkAclBypass -ErrorAction Stop | Out-Null;

                # Get new account.
                $CosmosDbAccount = Get-AzCosmosDBAccount -ResourceGroupName $ResourceGroup.ResourceGroupName -Name $CosmosDbAccountName;   
            }
            # Something went wrong.
            Catch
            {
                 # Write to log.
                Write-Log ("Something went wrong creating the account '{0}' in resource group '{1}', here is the error message:" -f $CosmosDbAccountName, $ResourceGroup.ResourceGroupName);
                Write-Host ($Error[0]);

                # Break.
                Break;
            }
        }

        # If account exist.
        If($CosmosDbAccount)
        {
            # If CosmosDb account provisioning state is succeeded.
            If($CosmosDbAccount.ProvisioningState -eq "Succeeded")
            {
                # Foreach database.
                Foreach($Database in $CosmosDbInfo.Databases)
                {
                    # If database dont exist.
                    If(!(Get-AzCosmosDBSqlDatabase -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $Database.Name -ErrorAction SilentlyContinue))
                    {
                        # Write to log.
                        Write-Log ("Creating database '{0}' in account '{1}' in resource group '{2}', this might take up to 2 minutes" -f $Database.Name, $CosmosDbAccount.Name, $ResourceGroup.ResourceGroupName);

                        # Create database.
                        New-AzCosmosDBSqlDatabase -ResourceGroupName $ResourceGroup.ResourceGroupName `
                                                  -AccountName $CosmosDbAccount.Name `
                                                  -Name $Database.Name | Out-Null;
                    }
                    # Database already exist.
                    Else
                    {
                        # Write to log.
                        Write-Log ("Database '{0}' already exist in account '{1}'" -f $Database.Name, $CosmosDbAccount.Name);
                    }
                }

                # Max threads allowed.
                $MaxThreads = 8;

                # Foreach container.
                Foreach($Container in $CosmosDbInfo.Containers)
                {
                    # If container dont exist.
                    If(!(Get-AzCosmosDBSqlContainer -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $Container.Database -Name $Container.Name -ErrorAction SilentlyContinue))
                    {
                        # Write to log.
                        Write-Log ("Creating container '{0}' in database '{1}' in account '{2}' in resource group '{3}'" -f $Container.Name, $Container.Database, $CosmosDbAccount.Name, $ResourceGroup.ResourceGroupName);

                        # Create script block.
                        $ScriptBlock = {
        
                            # Script block parameters.
                            Param
                            (
                                $AzContext,
                                $AccessToken,
                                $Subscription,
                                $ResourceGroup,
                                $CosmosDbAccount,
                                $Container
                            )

                            # Keep trying to import modules.
                            Do
                            {
                                # Try to import modules.
                                Try
                                {
                                    # Import module(s).
                                    Import-Module -Name Az.Accounts -Force -DisableNameChecking -ErrorAction Stop | Out-Null;
                                    Import-Module -Name Az.CosmosDB -Force -DisableNameChecking -ErrorAction Stop | Out-Null;

                                    # Imported module.
                                    $ImportedModules = $true;
                                }
                                # Resource in use.
                                Catch
                                {
                                    # Imported module.
                                    $ImportedModules = $false;
                                }
                            }
                            # Stop if modules are imported.
                            While($ImportedModules -eq $false);

                            # Connect to Azure.
                            Connect-AzAccount -AccessToken $AccessToken.Token -SubscriptionId $Subscription.Id -AccountId $AzContext.Account.Id -Force | Out-Null;

                            # Construct parameters.
                            $Parameters = @{};

                            # Add to parameters (required).
                            $Parameters.Add("ResourceGroupName", $ResourceGroup.ResourceGroupName);
                            $Parameters.Add("AccountName", $CosmosDbAccount.Name);
                            $Parameters.Add("DatabaseName", $Container.Database);
                            $Parameters.Add("Name", $Container.Name);
                            $Parameters.Add("PartitionKeyKind", $Container.PartitionKey.Kind);
                            $Parameters.Add("PartitionKeyPath", $Container.PartitionKey.Paths);

                            # Indexing policy.
                            If($Container.IndexingPolicy)
                            {
                                # Create index policy.
                                $IndexingPolicy = New-AzCosmosDBSqlIndexingPolicy -IncludedPath $Container.IndexingPolicy.IncludedPaths -ExcludedPath ($Container.IndexingPolicy.ExcludedPaths).Path -Automatic $Container.IndexingPolicy.Automatic -IndexingMode $Container.IndexingPolicy.IndexingMode;

                                # Add to parameters.
                                $Parameters.Add("IndexingPolicy", $IndexingPolicy);
                            }

                            # Partition key version.
                            If($Container.PartitionKey.Version -ne $null)
                            {
                                # Add to parameters.
                                $Parameters.Add("PartitionKeyVersion", $Container.PartitionKey.Version);
                            }

                            # Unique key policy.
                            If($Container.UniqueKeyPolicy.UniqueKeys)
                            {
                                # Create Unique key policy.
                                $UniqueKeyPolicy = New-AzCosmosDBSqlUniqueKeyPolicy -UniqueKey $Container.UniqueKeyPolicy.UniqueKeys;
                
                                # Add to parameters.
                                $Parameters.Add("UniqueKeyPolicy", $UniqueKeyPolicy);
                            }
            
                            # Client encryption policy.
                            If($Container.AnalyticalStorageTtl)
                            {
                                # Add to parameters.
                                $Parameters.Add("AnalyticalStorageTtl", $Container.AnalyticalStorageTtl);
                            }

                            # Try to get the Cosmos Db backup info from the container. 
                            Try
                            {
                                # Create container.
                                New-AzCosmosDBSqlContainer @Parameters | Out-Null;
                            }
                            # Something went wrong getting back info.
                            Catch
                            {
                                # Return error.
                                Return $Error[0];
                            }
                        };

                        # If there is more than maximum jobs running.
                        While (((Get-Job -State Running) | Where-Object {$_.Name -like "parallel-newcontainer-*"}).Count -ge $MaxThreads)
                        {
                            # Write to log.
                            #Write-Log ("Max threads reached '{0}', waiting for jobs to complete before creating new" -f $MaxThreads);
                            
                            # Sleep.
                            Start-Sleep -Seconds 5;
                        }

                        # Start sleep (to offset jobs).
                        #Start-Sleep -Seconds 1;

                        # Start parallel job.
                        Start-Job -Name ("parallel-newcontainer-{0}" -f (New-Guid).Guid) `
                                    -ScriptBlock $ScriptBlock `
                                    -ArgumentList $AzContext, $AccessToken, $Subscription, $ResourceGroup, $CosmosDbAccount, $Container | Out-Null;
                    }
                    # Container already exist.
                    Else
                    {
                        # Write to log.
                        Write-Log ("Container '{0}' already exist in database '{1}' in account '{2}' in resource group '{3}'" -f $Container.Name, $Container.Database, $CosmosDbAccountName, $ResourceGroupName);
                    }
                }

                # Wait for all jobs to finish.
                While (((Get-Job -State Running) | Where-Object {$_.Name -like "parallel-newcontainer-*"}).Count -gt 0)
                {
                    # Get all jobs.
                    $JobsRunning = ((Get-Job -State Running) | Where-Object {$_.Name -like "parallel-newcontainer-*"})
    
                    # Write to screen.
                    Write-Log ("Waiting for {0} new container job(s) to complete" -f $JobsRunning.Count);

                    # Start sleep.
                    Start-Sleep -Seconds 5;
                }
            }
            # Else the Cosmos DB account is not ready.
            Else
            {
                # Write to log.
                Write-Log ("The '{0}' account in resource group '{1}' is not ready, provisioning state is '{2}'" -f $CosmosDbAccount.Name, $ResourceGroup.ResourceGroupName, $CosmosDbAccount.ProvisioningState);
            }
        }
        # Else account do not exist.
        Else
        {
            # Write to log.
            Write-Log ("The '{0}' account in resource group '{1}' is not available" -f $AccountName, $ResourceGroupName);
        }
   
    }
    Else
    {
        # Write to log.
        Write-Log ("Resource group '{0}' dont exist" -f $ResourceGroupName);
    }
}

# Copy Cosmos DB schema to another account.
Function Copy-AzureCosmosDbSchema
{
    [CmdletBinding()]
    param
    (
        # Action.
        [Parameter(Mandatory=$true)][ValidateSet("Export", "Import")][string]$Action,
    
        # Cosmos DB account.
        [Parameter(Mandatory=$true)][string]$ResourceGroupName,
        [Parameter(Mandatory=$true)][string]$AccountName
    )

    # Construct path to XML output file.
    $XmlFilePath = ("{0}\cosmosdbinfo.xml" -f $env:TEMP);

    # If action is export.
    If($Action -eq "Export")
    {
        # Export database and container information from source Cosmos Db account.
        $CosmosDbInfo = Export-CosmosDbAccountInfo -ResourceGroupName $ResourceGroupName -CosmosDbAccountName $AccountName;

        # Write to log.
        Write-Log ("Exporting info to XML '{0}'" -f $XmlFilePath);

        # Export info.
        $CosmosDbInfo | Export-Clixml -Depth 99 -Path $XmlFilePath -Encoding UTF8 -Force;
    }
    # If action is import.
    ElseIf($Action -eq "Import")
    {
        # If export file exist.
        If(Test-Path -Path $XmlFilePath)
        {
            # Write to log.
            Write-Log ("Importing info from XML '{0}'" -f $XmlFilePath);

            # Import info.
            $CosmosDbInfo = Import-Clixml -Path $XmlFilePath;

            # Write to log.
            Write-Log ("Completed importing info from XML '{0}'" -f $XmlFilePath);

            # Create database and containers from export.
            Import-CosmosDbAccountInfo -ResourceGroupName $ResourceGroupName -CosmosDbAccountName $AccountName -CosmosDbInfo $CosmosDbInfo;

            # Write to log.
            Write-Log ("Removing file '{0}'" -f $XmlFilePath);

            # Remove export file.
            Remove-Item -Path $XmlFilePath -Force -Confirm:$false | Out-Null;
        }
        Else
        {
            # Write to log.
            Write-Log ("Cosmos DB export file don't exist at '{0}'" -f $XmlFilePath);
        }
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Copy Cosmos DB schema to another account.
Copy-AzureCosmosDbSchema -Action $Action -ResourceGroupName $ResourceGroupName -AccountName $AccountName;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
