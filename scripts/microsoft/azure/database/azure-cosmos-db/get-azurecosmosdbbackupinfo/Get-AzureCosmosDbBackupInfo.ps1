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

# Get backup info.
$CosmosDbBackupInfo = Get-AzureCosmosDbBackupInfo -ResourceGroupName "<optional>" `
                            -AccountName "<optional>" `
                            -DatabaseName "<optional>" `
                            -ContainerName "<optional>";

# Get account restore.
$CosmosDbBackupInfo.Account | Select-Object CosmosDbAccount, LatestBackup;
$CosmosDbBackupInfo.Database | Select-Object CosmosDbAccount, CosmosDbDatabase, LatestBackup;
$CosmosDbBackupInfo.Container | Select-Object CosmosDbAccount, CosmosDbDatabase, CosmosDbContainer, LatestBackup;
