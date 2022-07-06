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
  Clone Azure Cosmos DB.

.DESCRIPTION
  .

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  04-07-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
[cmdletbinding()]
Param
(    
    # Source.
    [Parameter(Mandatory=$true)][string]$SourceResourceGroupName,
    [Parameter(Mandatory=$true)][string]$SourceAccountName,

    # Target.
    [Parameter(Mandatory=$true)][string]$TargetResourceGroupName,
    [Parameter(Mandatory=$true)][string]$TargetAccountName,
    [Parameter(Mandatory=$false)][bool]$DeleteTargetIfExist = $false
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
        [Parameter(Mandatory=$false)][string]$Text,
        [Parameter(Mandatory=$false)][Switch]$NoTime
    )
  
    # If text is not present.
    If([string]::IsNullOrEmpty($Text))
    {
        # Write to the console.
        Write-Host("");
    }
    Else
    {
        # If no time is specificied.
        If($NoTime)
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

# Get Azure Cosmos DB backup info.
Function Get-AzureCosmosDbBackupInfo
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$ResourceGroupName, # Optional
        [Parameter(Mandatory=$false)][string]$AccountName, # Optional
        [Parameter(Mandatory=$false)][string]$DatabaseName, # Optional
        [Parameter(Mandatory=$false)][string]$ContainerName # Optional
    )

    # Get subscription.
    $Subscription = (Get-AzContext).Subscription;

    # Get context.
    $AzContext = Get-AzContext;

    # Get access token.
    $AccessToken = Get-AzAccessToken;

    # Result.
    $AccountResults = @();
    $DatabaseResults = @();
    $ContainerResults = @();

    # If resource group name is set.
    If(!([string]::IsNullOrEmpty($ResourceGroupName)))
    {        
        # Get specific resource group.
        $ResourceGroups = Get-AzResourceGroup -Name $ResourceGroupName;
    }
    # Else resource group name not set.
    Else
    {
        # Get all resource groups.
        $ResourceGroups = Get-AzResourceGroup;
    }

    # Counters.
    $ResourceGroupsCount = $ResourceGroups.Count;
    $ResourceGroupsCounter = 1;

    # Foreach resource group.
    Foreach($ResourceGroup in $ResourceGroups)
    {
        # Write to log.
        Write-Log ("[{0}][{1}]: Enumerating resource group ({2} out of {3})" -f $Subscription.Name, $ResourceGroup.ResourceGroupName, $ResourceGroupsCounter, $ResourceGroupsCount);

        # If account name is set.
        If(!([string]::IsNullOrEmpty($AccountName)))
        {        
            # Get specific account.
            $CosmosDbAccounts = Get-AzCosmosDBAccount -ResourceGroupName $ResourceGroup.ResourceGroupName -Name $AccountName;
        }
        # Else account name not set.
        Else
        {
            # Get all accounts.
            $CosmosDbAccounts = Get-AzCosmosDBAccount -ResourceGroupName $ResourceGroup.ResourceGroupName;
        }

        # Counters.
        $CosmosDbAccountsCount = $CosmosDbAccounts.Count;
        $CosmosDbAccountsCounter = 1;

        # Foreach account.
        Foreach($CosmosDbAccount in $CosmosDbAccounts)
        {
            # If continous backup is enabled.
            If($CosmosDbAccount.BackupPolicy.BackupType -eq "Continuous")
            {
                # Write to log.
                Write-Log ("[{0}][{1}]: Enumerating account ({2} out of {3})" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbAccountsCounter, $CosmosDbAccountsCount);

                # Get database account instance id.
                $DatabaseAccountInstance = Get-AzCosmosDBRestorableDatabaseAccount -DatabaseAccountName $CosmosDbAccount.Name;

                # If database name is set.
                If(!([string]::IsNullOrEmpty($DatabaseName)))
                {        
                    # Get specific CosmosDb SQL database.
                    $CosmosDbSqlDatabases = Get-AzCosmosDBSqlDatabase -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName $CosmosDbAccount.Name -Name $DatabaseName;
                }
                # Else database name not set.
                Else
                {
                    # Get CosmosDb SQL databases.
                    $CosmosDbSqlDatabases = Get-AzCosmosDBSqlDatabase -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName $CosmosDbAccount.Name;
                }

                # Latest account restore.
                $AccountRestoreTime = [DateTime]::MaxValue;

                # Counters.
                $CosmosDbSqlDatabasesCount = $CosmosDbSqlDatabases.Count;
                $CosmosDbSqlDatabasesCounter = 1;

                # Foreach database.
                Foreach($CosmosDbSqlDatabase in $CosmosDbSqlDatabases)
                {
                    # Write to log.
                    Write-Log ("[{0}][{1}][{2}]: Enumerating database ({3} out of {4})" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $CosmosDbSqlDatabasesCounter, $CosmosDbSqlDatabasesCount);

                    # If container name is set.
                    If(!([string]::IsNullOrEmpty($ContainerName)))
                    {        
                        # Get specific CosmosDb SQL container
                        $CosmosDbContainers = Get-AzCosmosDBSqlContainer -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $CosmosDbSqlDatabase.Name -Name $ContainerName;
                    }
                    # Else database name not set.
                    Else
                    {
                        # Get CosmosDb containers.
                        $CosmosDbContainers = Get-AzCosmosDBSqlContainer -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $CosmosDbSqlDatabase.Name;
                    }

                    # Latest database restore.
                    $DatabaseRestoreTime = [DateTime]::MaxValue;

                    # Max threads allowed.
                    $MaxThreads = 8;

                    # Counters.
                    $CosmosDbContainersCount = $CosmosDbContainers.Count;
                    $CosmosDbContainersCounter = 1;

                    # Foreach container.
                    Foreach($CosmosDbContainer in $CosmosDbContainers)
                    {
                        # Write to log.
                        Write-Log ("[{0}][{1}][{2}][{3}]: Getting backup info for container ({4} out of {5})" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $CosmosDbContainer.Name, $CosmosDbContainersCounter, $CosmosDbContainersCount);

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
                                $CosmosDbSqlDatabase,
                                $DatabaseAccountInstance,
                                $CosmosDbContainer
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

                            # Try to get the Cosmos Db backup info from the container. 
                            Try
                            {

                                # Get backup info from container.
                                $BackupInfo = Get-AzCosmosDBSqlContainerBackupInformation -ResourceGroupName $ResourceGroup.ResourceGroupName `
                                                                                            -AccountName $CosmosDbAccount.Name `
                                                                                            -DatabaseName $CosmosDbSqlDatabase.Name `
                                                                                            -Name $CosmosDbContainer.Name `
                                                                                            -Location $ResourceGroup.Location;

                                # If backup info is set.
                                If($BackupInfo.LatestRestorableTimestamp)
                                {
                                    # Restore time for container.
                                    $ContainerRestoreTime = ([datetime]$BackupInfo.LatestRestorableTimestamp);

                                    # Add to object array.
                                    $Result = [PSCustomObject]@{
                                        Type = "Container";
                                        SubscriptionName = $Subscription.Name;
                                        SubscriptionId = $Subscription.Id;
                                        ResourceGroupName = $ResourceGroup.ResourceGroupName;
                                        Location = $CosmosDbAccount.Location;
                                        CosmosDbAccount = $CosmosDbAccount.Name;
                                        DatabaseAccountInstanceId = $DatabaseAccountInstance.DatabaseAccountInstanceId;
                                        CosmosDbDatabase = $CosmosDbSqlDatabase.Name;
                                        CosmosDbContainer = $CosmosDbContainer.Name;
                                        LatestBackup = $ContainerRestoreTime;
                                    }
                                }
                                # No timestamp available.
                                Else
                                {
                                    # Add to object array.
                                    $Result = [PSCustomObject]@{
                                        Type = "Container";
                                        SubscriptionName = $Subscription.Name;
                                        SubscriptionId = $Subscription.Id;
                                        ResourceGroupName = $ResourceGroup.ResourceGroupName;
                                        Location = $CosmosDbAccount.Location;
                                        CosmosDbAccount = $CosmosDbAccount.Name;
                                        DatabaseAccountInstanceId = $DatabaseAccountInstance.DatabaseAccountInstanceId;
                                        CosmosDbDatabase = $CosmosDbSqlDatabase.Name;
                                        CosmosDbContainer = $CosmosDbContainer.Name;
                                        LatestBackup = $null;
                                    }
                                }

                                # Return result.
                                Return $Result;
                            }
                            # Something went wrong getting back info.
                            Catch
                            {
                            }
                        };

                        # If there is more than maximum jobs running.
                        While (((Get-Job -State Running) | Where-Object {$_.Name -like "parallel-*"}).Count -ge $MaxThreads)
                        {
                            # Sleep.
                            Start-Sleep -Seconds 5;
                        }

                        # Start sleep (to offset jobs).
                        Start-Sleep -Seconds 1;

                        # Start parallel job.
                        Start-Job -Name ("parallel-{0}" -f (New-Guid).Guid) `
                                    -ScriptBlock $ScriptBlock `
                                    -ArgumentList $AzContext, $AccessToken, $Subscription, $ResourceGroup, $CosmosDbAccount, $CosmosDbSqlDatabase, $DatabaseAccountInstance, $CosmosDbContainer | Out-Null;

                        # Add to counter.
                        $CosmosDbContainersCounter++;
                    }

                    # Wait for all jobs to finish.
                    While (((Get-Job -State Running) | Where-Object {$_.Name -like "parallel-*"}).Count -gt 0)
                    {
                        # Get all jobs.
                        $JobsRunning = ((Get-Job -State Running) | Where-Object {$_.Name -like "parallel-*"})
    
                        # Write to screen.
                        Write-Log ("Waiting for {0} backup info job(s) to complete" -f $JobsRunning.Count);

                        # Start sleep.
                        Start-Sleep -Seconds 5;
                    }

                    # Get all completed jobs.
                    $CompletedJobs = Get-Job -State Completed | Where-Object {$_.Name -like "parallel-*"};

                    # Object arrays.
                    $ContainerResults = @();

                    # Foreach completed job.
                    Foreach($CompletedJob in $CompletedJobs)
                    {
                        # Add to object array.
                        $ContainerResults += Receive-Job -Job $CompletedJob;
                    }

                    # Get latest container backup.
                    $ContainerRestoreTime = $ContainerResults | Select-Object -ExpandProperty LatestBackup | Sort-Object | Select-Object -First 1;

                    # If container time is less than database restore time.
                    If($ContainerRestoreTime -lt $DatabaseRestoreTime)
                    {
                        # Write to log.
                        Write-Log ("[{0}][{1}][{2}]: Latest restore for database is now set to '{3}'" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $ContainerRestoreTime);
                            
                        # Update database restore to container time.
                        $DatabaseRestoreTime = $ContainerRestoreTime;
                    }

                    # If database time is less than account restore time.
                    If($DatabaseRestoreTime -lt $AccountRestoreTime)
                    {
                        # Write to log.
                        Write-Log ("[{0}][{1}]: Latest restore for account is now set to '{2}'" -f $Subscription.Name, $CosmosDbAccount.Name, $DatabaseRestoreTime);
                
                        # Update database restore to container time.
                        $AccountRestoreTime = $DatabaseRestoreTime;
                    }

                    # Add to object array.
                    $DatabaseResults += [PSCustomObject]@{
                        Type = "Database";
                        SubscriptionName = $Subscription.Name;
                        SubscriptionId = $Subscription.Id;
                        ResourceGroupName = $ResourceGroup.ResourceGroupName;
                        Location = $CosmosDbAccount.Location;
                        CosmosDbAccount = $CosmosDbAccount.Name;
                        DatabaseAccountInstanceId = $DatabaseAccountInstance.DatabaseAccountInstanceId;
                        CosmosDbDatabase = $CosmosDbSqlDatabase.Name;
                        LatestBackup = $DatabaseRestoreTime;
                    }

                    # Add to counter.
                    $CosmosDbSqlDatabasesCounter++;
                }

                # Add to object array.
                $AccountResults += [PSCustomObject]@{
                    Type = "Account";
                    SubscriptionName = $Subscription.Name;
                    SubscriptionId = $Subscription.Id;
                    ResourceGroupName = $ResourceGroup.ResourceGroupName;
                    Location = $CosmosDbAccount.Location;
                    CosmosDbAccount = $CosmosDbAccount.Name;
                    DatabaseAccountInstanceId = $DatabaseAccountInstance.DatabaseAccountInstanceId;
                    LatestBackup = $AccountRestoreTime;
                }
            }
            # Backup is not enabled.
            Else
            {
                # Write to log.
                Write-Log ("[{0}][{1}]: Backup is not enabled on account" -f $Subscription.Name, $CosmosDbAccount.Name);
            }

            # Add to counter.
            $CosmosDbAccountsCounter++;
        }

        # Add to counter.
        $ResourceGroupsCounter++;
    }

    # Return results.
    Return [PSCustomObject]@{
        Account = $AccountResults;
        Database = $DatabaseResults;
        Container = $ContainerResults;
    };
}

# Construct restore JSON template for Cosmos DB restore.
Function Get-JsonCosmosDbRestore
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$TargetAccountName,
        [Parameter(Mandatory=$true)][string]$TargetLocation,
        [Parameter(Mandatory=$true)][string]$SourceSubscriptionId,
        [Parameter(Mandatory=$true)][string]$SourceLocation,
        [Parameter(Mandatory=$true)][string]$SourceAccountId,
        [Parameter(Mandatory=$true)][datetime]$SourceBackupTime
    )
    
    # Construct JSON.
    $Json = @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#';
        'contentVersion' = '1.0.0.0';
        'resources' = @(
            @{
                'name' = $TargetAccountName;
                'type' = 'Microsoft.DocumentDB/databaseAccounts';
                'apiVersion' = '2021-10-15';
                'location' = $TargetLocation;
                'properties' = @{
                    locations = @(
                        @{
                            'locationName' = $TargetLocation;
                        };
                    );
                    'databaseAccountOfferType' = 'Standard';
                    'createMode' = 'Restore';
                    'restoreParameters' = @{
                        'restoreSource' = ('/subscriptions/{0}/providers/Microsoft.DocumentDB/locations/{1}/restorableDatabaseAccounts/{2}' -f $SourceSubscriptionId, $SourceLocation, $SourceAccountId);
                        'restoreMode' = 'PointInTime';
                        'restoreTimestampInUtc' = $SourceBackupTime.ToString([CultureInfo]'en-us');
                    };
                }; 
            };
        );
    } | ConvertTo-Json -Depth 99;

    # Return JSON.
    Return $Json;
}

# Clone Azure Cosmos DB.
Function Clone-AzureCosmosDb
{
    [cmdletbinding()]	
		
    Param
    (
        # Source.
        [Parameter(Mandatory=$true)][string]$SourceResourceGroupName,
        [Parameter(Mandatory=$true)][string]$SourceAccountName,

        # Target.
        [Parameter(Mandatory=$true)][string]$TargetResourceGroupName,
        [Parameter(Mandatory=$true)][string]$TargetAccountName,
        [Parameter(Mandatory=$false)][bool]$DeleteTargetIfExist = $false
    )

    # Get Azure subscription.
    $AzureSubscription = (Get-AzContext).Subscription;

    # If source account exist.
    If($SourceAccount = Get-AzCosmosDBAccount -ResourceGroupName $SourceResourceGroupName -Name $SourceAccountName -ErrorAction SilentlyContinue)
    {
        # If target resource group exist.
        If($TargetResourceGroup = Get-AzResourceGroup -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue)
        {
            # Write to log.
            Write-Log ("Target resource group '{0}' exist" -f $TargetResourceGroupName);

            # If target account exist.
            If(Get-AzCosmosDBAccount -ResourceGroupName $TargetResourceGroupName -Name $TargetAccountName -ErrorAction SilentlyContinue)
            {
                # If target account delete is set.
                If($DeleteTargetIfExist -eq $true)
                {
                    # Write to log.
                    Write-Log ("Removing target account '{0}' in resource group '{1}'" -f $TargetAccountName, $TargetResourceGroupName);

                    # Remove account.
                    Remove-AzCosmosDBAccount -ResourceGroupName $TargetResourceGroupName -Name $TargetAccountName -Confirm:$false;
                }
                # Else set to false.
                Else 
                {
                    # Write to log.
                    Write-Log ("Skipping removal of target account '{0}' in resource group '{1}'" -f $TargetAccountName, $TargetResourceGroupName);
                }
            }

            # If target account dontexist.
            If(!($TargetAccount = Get-AzCosmosDBAccount -ResourceGroupName $TargetResourceGroupName -Name $TargetAccountName -ErrorAction SilentlyContinue))
            {
                # Write to log.
                Write-Log ("Getting latest available backup from source Cosmos DB account '{0}' in resource group '{1}', this might take a while" -f $SourceAccountName, $SourceResourceGroupName);

                # Get backup info from source.
                $SourceCosmosDbBackupInfo = Get-AzureCosmosDbBackupInfo -ResourceGroupName $SourceResourceGroupName -AccountName $SourceAccountName;

                # Write to log.
                Write-Log ("Latest available backup is '{0}'" -f $SourceCosmosDbBackupInfo.Account.LatestBackup);

                # If account backup is not null.
                If(!([string]::IsNullOrEmpty($SourceCosmosDbBackupInfo.Account.LatestBackup)))
                {
                    # Construct JSON file.
                    $Json = Get-JsonCosmosDbRestore -TargetAccountName $TargetAccountName `
                                                    -TargetLocation $TargetResourceGroup.Location `
                                                    -SourceSubscriptionId $AzureSubscription.Id `
                                                    -SourceLocation $SourceCosmosDbBackupInfo.Account.Location `
                                                    -SourceAccountId $SourceCosmosDbBackupInfo.Account.DatabaseAccountInstanceId `
                                                    -SourceBackupTime $SourceCosmosDbBackupInfo.Account.LatestBackup;
    
                    # Output file path.
                    $JsonFilePath = ('{0}\{1}.json' -f $env:TEMP, $SourceCosmosDbBackupInfo.Account.DatabaseAccountInstanceId);

                    # Write to log.
                    Write-Log ("Exporting JSON deploy restore file to '{0}'" -f $JsonFilePath);

                    # Export JSON to file.
                    $Json | Out-File -FilePath $JsonFilePath -Encoding utf8 -Force;

                    # Write to log.
                    Write-Log ("Starting restore from '{0}' ({1}) to '{2}' ({3}), this might take a while" -f $SourceAccountName, $SourceResourceGroupName, $TargetAccountName, $TargetResourceGroupName);

                    # Start restore.
                    New-AzResourceGroupDeployment -ResourceGroupName $TargetResourceGroupName -TemplateFile $JsonFilePath -Mode Incremental -AsJob | Out-Null;

                    # Remove all completed jobs.
                    Get-Job -Command 'New-AzResourceGroupDeployment' | Where-Object {$_.State -ne "Running"} | Remove-Job -Force;

                    # Write to log.
                    Write-Log ("Deployment in progress (maximum time is 180 minutes)");

                    # While job is not running over 180 minutes.
                    Do
                    {
                        # Get background job.
                        $Job = Get-Job -Command 'New-AzResourceGroupDeployment' | Select-Object -First 1;

                        # Get time span.
                        $RunningTime = New-TimeSpan -Start $Job.PSBeginTime -End (Get-Date);

                        # If job running.
                        If($Job.State -eq "Running")
                        {
                            # If running time is over 100 minutes.
                            If($RunningTime.Minutes -ge 100)
                            {
                                # Write to log.
                                Write-Log ("Stopped because job '{0}' was running more than 180 minutes" -f $Job.Id);

                                # Stop loop.
                                $StopLoop = $true;
                            }
                            # Under 180 minutes.
                            Else
                            {
                                # Write to log.
                                Write-Log ("Restore job '{0}' still running ({1} minutes and {2} seconds)" -f $Job.Id, $RunningTime.Minutes, $RunningTime.Seconds);

                                # Start sleep
                                Start-Sleep -Seconds 30;  

                                # Continue loop.
                                $StopLoop = $false;
                            }                          
                        }
                        # Else if job is complete.
                        ElseIf($Job.State -eq "Completed")
                        {
                            # Write to log.
                            Write-Log ("Restore job '{0}' is completed" -f $Job.Id);

                            # Stop loop.
                            $StopLoop = $true;
                        }
                        # Job not running.
                        Else
                        {
                            # Write to log.
                            Write-Log ("Restore job '{0}' is not running" -f $Job.Id);

                            # Stop loop.
                            $StopLoop = $true;
                        }
                    }
                    # While stop loop is false.
                    While($StopLoop -eq $false);

                    # If target account exist.
                    If($TargetAccount = Get-AzCosmosDBAccount -ResourceGroupName $TargetResourceGroupName -Name $TargetAccountName -ErrorAction SilentlyContinue)
                    {
                        # Write to log.
                        Write-Log ("Target account provisioning state is '{0}'" -f $TargetAccount.ProvisioningState);
                    }
                    # Else no target account exist.
                    Else
                    {
                        # Write to log.
                        Write-Log ("Target account '{0}' ({1}) was not created, something went wrong" -f $TargetAccountName, $TargetResourceGroupName);
                    }

                }
                # No backup available.
                Else
                {
                    # Write to log.
                    Write-Log ("No available backup for '{0}'" -f $SourceCosmosDbBackupInfo.Account.CosmosDbAccount);
                }
            }
            # Else source acocunt dont exist.
            Else
            {
                # Write to log.
                Write-Log ("Target Cosmos DB account '{0}' in resource group '{1}' already exist, skipping" -f $SourceAccountName, $SourceResourceGroupName);
            }
        }
        # Else if target resource group dont exist.
        Else
        {
            # Write to log.
            Write-Log ("Target resource group '{0}' do not exist, skipping" -f $TargetResourceGroupName);
        }
    }
    # Else source acocunt dont exist.
    Else
    {
        # Write to log.
        Write-Log ("Source Cosmos DB account '{0}' in resource group '{1}' dont not exist" -f $SourceAccountName, $SourceResourceGroupName);
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Clone Azure Cosmos DB.
Clone-AzureCosmosDb -SourceResourceGroupName $SourceResourceGroupName `
                    -SourceAccountName $SourceAccountName `
                    -TargetResourceGroupName $TargetResourceGroupName `
                    -TargetAccountName $TargetAccountName `
                    -DeleteTargetIfExist $DeleteTargetIfExist;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion
