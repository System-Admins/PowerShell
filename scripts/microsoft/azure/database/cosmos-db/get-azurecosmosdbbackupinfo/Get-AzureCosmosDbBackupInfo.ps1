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
    $Subscription = Get-AzSubscription;

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

    # Foreach resource group.
    Foreach($ResourceGroup in $ResourceGroups)
    {
        # Write to log.
        Write-Host ("[{0}][{1}]: Enumerating resource group" -f $Subscription.Name, $ResourceGroup.ResourceGroupName);

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

        # Foreach account.
        Foreach($CosmosDbAccount in $CosmosDbAccounts)
        {
            # Write to log.
            Write-Host ("[{0}][{1}]: Enumerating account" -f $Subscription.Name, $CosmosDbAccount.Name);

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

            # Foreach database.
            Foreach($CosmosDbSqlDatabase in $CosmosDbSqlDatabases)
            {
                # Write to log.
                Write-Host ("[{0}][{1}][{2}]: Enumerating database" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name);

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

                # Foreach container.
                Foreach($CosmosDbContainer in $CosmosDbContainers)
                {
                    # Write to log.
                    Write-Host ("[{0}][{1}][{2}][{3}]: Enumerating container" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $CosmosDbContainer.Name);
                    Write-Host ("[{0}][{1}][{2}][{3}]: Getting backup info for container" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $CosmosDbContainer.Name);

                    # Get backup info from container. 
                    If($BackupInfo = Get-AzCosmosDBSqlContainerBackupInformation -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $CosmosDbSqlDatabase.Name -Name $CosmosDbContainer.Name -Location $ResourceGroup.Location -ErrorAction SilentlyContinue)
                    {
                        # If backup info is set.
                        If($BackupInfo.LatestRestorableTimestamp)
                        {
                            # Restore time for container.
                            $ContainerRestoreTime = [datetime]$BackupInfo.LatestRestorableTimestamp;

                            # If container time is less than database restore time.
                            If($ContainerRestoreTime -lt $DatabaseRestoreTime)
                            {
                                # Write to log.
                                Write-Host ("[{0}][{1}][{2}]: Latest restore for database is now set to '{3}'" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $ContainerRestoreTime);
                            
                                # Update database restore to container time.
                                $DatabaseRestoreTime = $ContainerRestoreTime;
                            }

                            # Write to log.
                            Write-Host ("[{0}][{1}][{2}][{3}]: Latest restore for container is '{4}'" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $CosmosDbContainer.Name, ($ContainerRestoreTime).ToString("dd-MM-yyyy hh:mm:ss"));

                            # Add to object array.
                            $ContainerResults += [PSCustomObject]@{
                                Type = "Container";
                                SubscriptionName = $Subscription.Name;
                                SubscriptionId = $Subscription.Id;
                                ResourceGroupName = $ResourceGroup.ResourceGroupName;
                                CosmosDbAccount = $CosmosDbAccount.Name;
                                CosmosDbDatabase = $CosmosDbSqlDatabase.Name;
                                CosmosDbContainer = $CosmosDbContainer.Name;
                                LatestBackup = $ContainerRestoreTime;
                            }
                        }
                    }
                }

                # If database time is less than account restore time.
                If($DatabaseRestoreTime -lt $AccountRestoreTime)
                {
                    # Write to log.
                    Write-Host ("[{0}][{1}]: Latest restore for account is now set to '{2}'" -f $Subscription.Name, $CosmosDbAccount.Name, $DatabaseRestoreTime);
                
                    # Update database restore to container time.
                    $AccountRestoreTime = $DatabaseRestoreTime;
                }

                # Add to object array.
                $DatabaseResults += [PSCustomObject]@{
                    Type = "Database";
                    SubscriptionName = $Subscription.Name;
                    SubscriptionId = $Subscription.Id;
                    ResourceGroupName = $ResourceGroup.ResourceGroupName;
                    CosmosDbAccount = $CosmosDbAccount.Name;
                    CosmosDbDatabase = $CosmosDbSqlDatabase.Name;
                    LatestBackup = $DatabaseRestoreTime;
                }
            }

            # Add to object array.
            $AccountResults += [PSCustomObject]@{
                Type = "Account";
                SubscriptionName = $Subscription.Name;
                SubscriptionId = $Subscription.Id;
                ResourceGroupName = $ResourceGroup.ResourceGroupName;
                CosmosDbAccount = $CosmosDbAccount.Name;
                LatestBackup = $AccountRestoreTime;
            }
        }
    }

    # Return results.
    Return [PSCustomObject]@{
        Account = $AccountResults;
        Database = $DatabaseResults;
        Container = $ContainerResults;
    };
}

# Get Azure Cosmos DB backup info (all parameters are optional).
$AzureCosmosDbBackupInfo = Get-AzureCosmosDbBackupInfo;
