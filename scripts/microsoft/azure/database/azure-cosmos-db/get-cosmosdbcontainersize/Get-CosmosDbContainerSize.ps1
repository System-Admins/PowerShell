# Must be running PowerShell version 5.1 or higher.
#Requires -Version 5.1;

# Must have the following modules installed.
#Requires -Module Az.Accounts;
#Requires -Module Az.CosmosDB;
#Requires -Module Az.Resources;

<#
.SYNOPSIS
  This script takes enumerate all containers in a Cosmos DB account and get documents count and container sizes.

.DESCRIPTION
  Uses Cosmos DB REST api and PowerShell cmdlet to gather container size and documents count.
  It will export the info to an CSV file on the desktop.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  16-01-2023
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
Param
(
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9-]{3,44}$')][string]$AccountName,
    [Parameter(Mandatory = $false)][string]$Path
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
        [Parameter(Mandatory = $true)][string]$ResourceLink,
        [Parameter(Mandatory = $true)][ValidateSet("colls")][string]$ResourceType,
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

# Get Cosmos DB container.
Function Get-CosmosDbContainerSize
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

    # Invoke REST method
    Try
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
            Return $UsageItems;
        }
    }
    Catch
    {
        
    }

    # Return result.
    Return $Result;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# If path is empty.
If ([string]::IsNullOrEmpty($Path))
{
    # Set path to the desktop.
    $Path = ("{0}\{1}_{2}.csv" -f [Environment]::GetFolderPath("Desktop"), $AccountName, (Get-Date).ToString("yyyyMMdd"));
}

# Get Cosmos DB account.
$CosmosDbAccount = Get-AzResource -ResourceType 'Microsoft.DocumentDB/databaseAccounts' | Where-Object { $_.Name -eq $AccountName };

# If the Cosmos DB account exists.
If ($null -eq $CosmosDbAccount)
{
    # Throw exception.
    throw ("The Cosmos DB account '{0}' dont exist" -f $AccountName);
}

# Write to log.
Write-Log ("The Cosmos DB account '{0}' exist in resource group '{1}'" -f $CosmosDbAccount.Name, $CosmosDbAccount.ResourceGroupName);

# Get endpoint URI.
$CosmosDbAccountDocumentEndpoint = (Get-AzCosmosDBAccount -ResourceGroupName $CosmosDbAccount.ResourceGroupName -Name $CosmosDbAccount.Name).DocumentEndpoint;

# Get master key.
$CosmosDbAccountMasterKey = (Get-AzCosmosDBAccountKey -ResourceGroupName $CosmosDbAccount.ResourceGroupName -Name $CosmosDbAccount.Name).PrimaryReadonlyMasterKey;

# Write to log.
Write-Log ("Getting all databases in Cosmos DB account [{0}][{1}]" -f $CosmosDbAccount.Name, $CosmosDbAccount.ResourceGroupName);

# Get all databases.
$CosmosDbDatabases = Get-AzCosmosDBSqlDatabase -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name;

# Object arrays to store results.
$ContainerResults = @();

# Foreach database.
Foreach ($CosmosDbDatabase in $CosmosDbDatabases)
{
    # Write to log.
    Write-Log ("Getting all containers in the database [{0}][{1}][{2}]" -f $CosmosDbAccount.ResourceGroupName, $CosmosDbAccount.Name, $CosmosDbDatabase.Name);

    # Get all containers in the database.
    $CosmosDbContainers = Get-AzCosmosDBSqlContainer -ResourceGroupName $CosmosDbAccount.ResourceGroupName -AccountName $CosmosDbAccount.Name -DatabaseName $CosmosDbDatabase.Name;

    # Foreach container.
    Foreach ($CosmosDbContainer in $CosmosDbContainers)
    {
        # Write to log.
        Write-Log ("Getting container size from [{0}][{1}][{2}][{3}]" -f $CosmosDbAccount.ResourceGroupName, $CosmosDbAccount.Name, $CosmosDbDatabase.Name, $CosmosDbContainer.Name);

        # Get container size.
        $ContainerSizeInfo = Get-CosmosDbContainerSize -EndpointUri $CosmosDbAccountDocumentEndpoint -MasterKey $CosmosDbAccountMasterKey -DatabaseName $CosmosDbDatabase.Name -CollectionName $CosmosDbContainer.Name;

        # Add to object array.
        $ContainerResults += [PSCustomObject]@{
            "ResourceGroupName" = $CosmosDbAccount.ResourceGroupName;
            "AccountName"       = $CosmosDbAccount.Name;
            "DatabaseName"      = $CosmosDbDatabase.Name;
            "ContainerName"     = $CosmosDbContainer.Name;
            "ContainerSize"     = $ContainerSizeInfo.collectionSize;
            "DocumentsCount"    = $ContainerSizeInfo.documentsCount;
            "DocumentsSize"     = $ContainerSizeInfo.documentsSize;
        }
    }
}

# Write to log.
Write-Log ("Exporting container info to '{0}'" -f $Path);

# Export results.
$ContainerResults | Export-Csv -Path $Path -Encoding UTF8 -Delimiter ";" -NoTypeInformation -Force;

# Return results.
Return $ContainerResults;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
