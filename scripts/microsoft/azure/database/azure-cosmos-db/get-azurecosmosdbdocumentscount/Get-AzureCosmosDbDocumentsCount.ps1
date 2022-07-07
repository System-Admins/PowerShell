# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Must have the following modules installed.
#Requires -Module Az.Accounts;
#Requires -Module Az.CosmosDB;

# Get number of documents in container.
Function Get-AzureCosmosDbDocumentsCount
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$ResourceGroupName,
        [Parameter(Mandatory=$true)][string]$AccountName,
        [Parameter(Mandatory=$true)][string]$DatabaseName,
        [Parameter(Mandatory=$true)][string]$ContainerName
    )

    # Add necessary assembly.
    Add-Type -AssemblyName System.Web;

    # Get Cosmos Db account.
    $Account = Get-AzCosmosDBAccount -ResourceGroupName $ResourceGroupName -Name $AccountName;

    # Get account keys.
    $AccountKeys = Get-AzCosmosDBAccountKey -ResourceGroupName $ResourceGroupName -Name $AccountName;

    # Set key to use.
    $Key = $AccountKeys.PrimaryMasterKey;

    # Get date.
    $Date = (Get-Date).ToUniversalTime().ToString('R');

    # Create resource link.
    $ResourceLink = ("dbs/{0}/colls/{1}" -f $DatabaseName, $ContainerName);

    # Create string that need to be hashed.
    $StringToSign = ("post" + "`n" + "docs" + "`n" + $ResourceLink + "`n" + $Date.ToLowerInvariant() + "`n" + "" + "`n");

    # Create new object.
    $HMACSHA = New-Object System.Security.Cryptography.HMACSHA256;

    # Convert to base from string.
    $HMACSHA.Key = [Convert]::FromBase64String($Key);

    # Compute hash from string.
    $Signature = $HMACSHA.ComputeHash([Text.Encoding]::UTF8.GetBytes($StringToSign));

    # Convert hash to string.
    $Signature = [Convert]::ToBase64String($Signature);

    # Create authorization for the header.
    $Authorization = [System.Web.HttpUtility]::UrlEncode("type=master&ver=1.0&sig=$Signature");

    # Create body.
    $Body = @{
        'query' = 'SELECT * FROM c';
        'parameters' = @();
    } | ConvertTo-Json -Depth 99;

    # Create header.
    $Header = @{
        Authorization = $Authorization;
        'x-ms-version' = '2018-12-31';
        'x-ms-documentdb-isquery' = 'True';
        'x-ms-date' = $Date;
        'x-ms-documentdb-query-enablecrosspartition' = 'True';
        'x-ms-max-item-count' = [int]::MaxValue;
    };

    # Create Uri.
    $Uri = $Account.DocumentEndpoint + $ResourceLink + "/docs";
    
    # Invoke API.
    $Result = Invoke-RestMethod -Method Post -ContentType 'application/query+json' -Uri $Uri -Headers $Header -Body $Body;

    # Return result.
    Return [int]($Result._count);
}

# Get number of documents in container.
Get-AzureCosmosDbDocumentsCount -ResourceGroupName "<ResourceGroupName>" `
                                -AccountName "<AccountName>" `
                                -DatabaseName "<DatabaseName>" `
                                -ContainerName "<ContainerName>";
