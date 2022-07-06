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
  Truncate Azure Cosmos DB.

.DESCRIPTION
  .

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  05-07-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
[cmdletbinding()]

Param
(    
    # Action.
    [Parameter(Mandatory=$false)][ValidateSet("Delete", "Default")][string]$Action = 'Delete',
    
    # Cosmos DB account.
    [Parameter(Mandatory=$true)][string]$ResourceGroupName,
    [Parameter(Mandatory=$true)][string]$AccountName,
    [Parameter(Mandatory=$false)][string]$DatabaseName,
    [Parameter(Mandatory=$false)][string]$ContainerName
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

# Truncate Azure Cosmos DB.
Function Truncate-AzureCosmosDb
{
    [cmdletbinding()]	
		
    Param
    (
        # Action.
        [Parameter(Mandatory=$true)][ValidateSet("Delete", "Default")][string]$Action,
    
        # Cosmos DB account.
        [Parameter(Mandatory=$false)][string]$ResourceGroupName,
        [Parameter(Mandatory=$false)][string]$AccountName,
        [Parameter(Mandatory=$false)][string]$DatabaseName,
        [Parameter(Mandatory=$false)][string]$ContainerName
    )

    # Get subscription.
    $Subscription = (Get-AzContext).Subscription;

    # Get context.
    $AzContext = Get-AzContext;

    # Get access token.
    $AccessToken = Get-AzAccessToken;

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
            # Write to log.
            Write-Log ("[{0}][{1}]: Enumerating account ({2} out of {3})" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbAccountsCounter, $CosmosDbAccountsCount);

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

                # Counters.
                $CosmosDbContainersCount = $CosmosDbContainers.Count;
                $CosmosDbContainersCounter = 1;

                # Max threads allowed.
                $MaxThreads = 8;

                # Foreach container.
                Foreach($CosmosDbContainer in $CosmosDbContainers)
                {
                    # Write to log.
                    Write-Log ("[{0}][{1}][{2}][{3}]: Enumerating container ({4} out of {5})" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $CosmosDbContainer.Name, $CosmosDbContainersCounter, $CosmosDbContainersCount);

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
                            $CosmosDbContainer,
                            $TtlInSeconds
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

                        # Try to set TTL on container. 
                        Try
                        {                        
                            # Set TTL to zero to enforce item deletes.
                            Update-AzCosmosDBSqlContainer -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $CosmosDbSqlDatabase.Name -Name $CosmosDbContainer.Name -TtlInSeconds $TtlInSeconds -Confirm:$false | Out-Null; 
                        }
                        # Something went wrong getting back info.
                        Catch
                        {
                        }
                    }

                    # If there is more than maximum jobs running.
                    While (((Get-Job -State Running) | Where-Object {$_.Name -like "parallel-truncate-*"}).Count -ge $MaxThreads)
                    {
                        # Sleep.
                        Start-Sleep -Seconds 5;
                    }

                    # Start sleep (to offset jobs).
                    Start-Sleep -Seconds 1;

                    # Set value based on action.
                    Switch($Action)
                    {
                        # Truncate.
                        "Delete" {
                            $TtlInSeconds = 1;
                        };
                        # Truncate.
                        "Default" {
                            $TtlInSeconds = -1;
                        };
                    }

                    # If TTL is set and action is delete.
                    If($CosmosDbContainer.Resource.DefaultTtl -lt 0 -and $TtlInSeconds -eq 1)
                    {
                        # Write to log.
                        Write-Log ("[{0}][{1}][{2}][{3}]: Starting job to set TTL to delete (1 second)" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $CosmosDbContainer.Name);

                        # Start parallel job.
                        Start-Job -Name ("parallel-truncate-{0}" -f (New-Guid).Guid) `
                                    -ScriptBlock $ScriptBlock `
                                    -ArgumentList $AzContext, $AccessToken, $Subscription, $ResourceGroup, $CosmosDbAccount, $CosmosDbSqlDatabase, $DatabaseAccountInstance, $CosmosDbContainer, $TtlInSeconds | Out-Null;
                    }
                    # Else if TTL is default and action is default.
                    ElseIf(($CosmosDbContainer.Resource.DefaultTtl -gt 0 -or $CosmosDbContainer.Resource.DefaultTtl -eq $null) -and $TtlInSeconds -eq -1)
                    {
                        # Write to log.
                        Write-Log ("[{0}][{1}][{2}][{3}]: Starting job to set TTL to default (forever)" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $CosmosDbContainer.Name);

                        # Start parallel job.
                        Start-Job -Name ("parallel-truncate-{0}" -f (New-Guid).Guid) `
                                    -ScriptBlock $ScriptBlock `
                                    -ArgumentList $AzContext, $AccessToken, $Subscription, $ResourceGroup, $CosmosDbAccount, $CosmosDbSqlDatabase, $DatabaseAccountInstance, $CosmosDbContainer, $TtlInSeconds | Out-Null;
                    }
                    # TTL already set correct.
                    Else
                    {
                        # Write to log.
                        Write-Log ("[{0}][{1}][{2}][{3}]: TTL is already set to '{4}', skipping" -f $Subscription.Name, $CosmosDbAccount.Name, $CosmosDbSqlDatabase.Name, $CosmosDbContainer.Name, $Action);
                    }

                    # Add to counter.
                    $CosmosDbContainersCounter++;
                }

                # Wait for all jobs to finish.
                While (((Get-Job -State Running) | Where-Object {$_.Name -like "parallel-truncate-*"}).Count -gt 0)
                {
                    # Get all jobs.
                    $JobsRunning = ((Get-Job -State Running) | Where-Object {$_.Name -like "parallel-truncate-*"})
    
                    # Write to screen.
                    Write-Log ("Waiting for {0} truncate job(s) to complete" -f $JobsRunning.Count);

                    # Start sleep.
                    Start-Sleep -Seconds 5;
                }

                # Add to counter.
                $CosmosDbSqlDatabasesCounter++;
            }

            # Add to counter.
            $CosmosDbAccountsCounter++;
        }

        # Add to counter.
        $ResourceGroupsCounter++;
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Truncate Azure Cosmos DB.
Truncate-AzureCosmosDb -Action $Action `
                       -ResourceGroupName $ResourceGroupName `
                       -AccountName $AccountName `
                       -DatabaseName $DatabaseName `
                       -ContainerName $ContainerName;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion
