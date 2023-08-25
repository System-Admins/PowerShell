# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Require modules.
#Requires -Module Az.Storage;
#Requires -Module Az.Resources;

<#
.SYNOPSIS
  Uploade an file to Azure Storage Account Blob Container.

.DESCRIPTION
  This script uploads a file to an blob container in Azure.
  It allows for append blobs to automatically to append to files.
  This is useful for logging etc.

.EXAMPLE
  # Upload and append file to Azure blob container.
  .\Append-DataToAzBlob.ps1 -StorageAccountName "MyStorageAcccount" -ContainerName "MyContainer" -FilePath "C:\Users\<user>\Desktop\test.txt";

.EXAMPLE
  # Overwrite file content to Azure blob container.
  .\Append-DataToAzBlob.ps1 -StorageAccountName "MyStorageAcccount" -ContainerName "MyContainer" -FilePath "C:\Users\<user>\Desktop\test.txt" -Overwrite;

.EXAMPLE
  # Place blob in specific folder in container.
  .\Append-DataToAzBlob.ps1 -StorageAccountName "MyStorageAcccount" -ContainerName "MyContainer" -FilePath "C:\Users\<user>\Desktop\test.txt" -TargetFolder "path/to/my/folder";

.EXAMPLE
  # Use specific blob type.
  .\Append-DataToAzBlob.ps1 -StorageAccountName "MyStorageAcccount" -ContainerName "MyContainer" -FilePath "C:\Users\<user>\Desktop\test.txt" -BlobType Block;

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  25-08-2023
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
[cmdletbinding()]
param
(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$StorageAccountName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ContainerName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$FilePath,
    [Parameter(Mandatory = $false)][string]$TargetFolder,
    [Parameter(Mandatory = $false)][ValidateSet("Append", "Block", "Page")][string]$BlobType = "Append",
    [Parameter(Mandatory = $false)][switch]$Overwrite = $false
)

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

############### Input - End ###############
#endregion

#region begin functoins
############### Functions - Start ###############

# Write to log.
function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory = $false)][string]$Text
    )
  
    # If text is not present.
    if ([string]::IsNullOrEmpty($Text))
    {
        # Write to log.
        Write-Information -MessageData ("") -InformationAction Continue;
    }
    else
    {
        # Write to log.
        Write-Information -MessageData ("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text) -InformationAction Continue;
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log ("Script started at {0}" -f (Get-Date));

# If local path dont exist.
if(!(Test-Path -Path $FilePath -PathType Leaf))
{
    # Throw execption.
        throw ("File at '{0}' dont exist" -f $FilePath);
}

# Get storage account resource.
$AzResource = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts' -Name $StorageAccountName -ErrorAction SilentlyContinue;

# If the resource dont exist.
if($null -eq $AzResource)
{
        # Throw execption.
        throw ("The storage account '{0}' dont exist" -f $StorageAccountName);
}

# Get file name.
$FileName = Split-Path -Path $FilePath -Leaf;

# Get storage account.
$StorageAccount = Get-AzStorageAccount -ResourceGroupName $AzResource.ResourceGroupName -Name $AzResource.Name;

# Get storage account resource.
$Container = Get-AzStorageContainer -Context ($StorageAccount).Context -Name $ContainerName -ErrorAction SilentlyContinue;

# If the container dont exist.
if($null -eq $Container)
{
        # Throw execption.
        throw ("The container '{0}' in storage account '{1}' dont exist" -f $ContainerName, $StorageAccount.StorageAccountName);
}

# If target folder is not specified.
if([string]::IsNullOrEmpty($TargetFolder))
{
    # Set blob name.
    $BlobName = $FileName;
}
# Else target folder is specified.
else
{
    # Set blob name.
    $BlobName = ("{0}/{1}" -f $TargetFolder, $FileName);
}
    
# Get storage blob.
$Blob = Get-AzStorageBlob -Container $Container.Name -Blob $BlobName -Context ($StorageAccount).Context -ErrorAction SilentlyContinue;

# If blob exist.
if($BlobType -eq "Append" -and $null -ne $Blob -and $Overwrite -eq $false)
{
    # Try to append blob.
    try
    {
        # Write to log.
        Write-Log ("Trying to append content to blob '{0}' from file '{1}' to storage account '{2}'" -f $BlobName, $StorageAccount.StorageAccountName, $FilePath);

        # Get content.
        $FileContent = [System.IO.File]::OpenRead($FilePath);

        # Append content to existing blob.
        $Blob.BlobBaseClient.AppendBlock($FileContent) | Out-Null;

        # Close connection to local file.
        $FileContent.Close();

        # Write to log.
        Write-Log ("Successfully appended content to blob '{0}' from file '{1}' to storage account '{2}'" -f $BlobName, $StorageAccount.StorageAccountName, $FilePath);
    }
    # Something went wrong while appending blob.
    catch
    {
        # Throw execption.
        throw ("Could not append content to blob '{0}' from file '{1}' to storage account '{2}'" -f $BlobName, $StorageAccount.StorageAccountName, $FilePath);
    }
}
# Else blob dont already exist.
else
{
    # Try to upload.
    try
    {
        # Write to log.
        Write-Log ("Trying to upload file '{0}' to storage account '{1}'" -f $FilePath, $StorageAccount.StorageAccountName);

        # If overwrite is enabled.
        if($Overwrite)
        {
            # Write to log.
            Write-Log ("Will overwrite file '{0}' in storage account '{1}', if it exists" -f $BlobName, $StorageAccount.StorageAccountName);
        }

        # Upload file.
        Set-AzStorageBlobContent -BlobType $BlobType -Container $ContainerName -Blob $BlobName -Context ($StorageAccount).Context -File $FilePath -Force:$Overwrite | Out-Null;

        # Write to log.
        Write-Log ("Successfully uploaded file '{0}' to storage account '{1}'" -f $FilePath, $StorageAccount.StorageAccountName);
    }
    # Something went wrong with the upload.
    catch
    {
        # Throw execption.
        throw ("Could not upload file '{0}' to storage account '{1}', execption is: `r`n {3}" -f $FilePath, $StorageAccount.StorageAccountName, $_);
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
