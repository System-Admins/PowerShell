#Requires -RunAsAdministrator;
#Requires -Version 5.1;

[CmdletBinding()]
param
(
    # Storage account name (resource name, not the URI).
    [Parameter(Mandatory = $true)]
    [string]
    $StorageAccountName = 'mystorageaccount',

    # Blob container name.
    [Parameter(Mandatory = $true)]
    [string]
    $BlobContainerName,

    # SAS Token (only requires the permission "Create").
    # Looks like this:
    # sp=c&st=2025-07-02T17:20:27Z&se=2027-07-03T01:20:27Z&spr=https&sv=2024-11-04&sr=c&sig=y2ROHV64gQZxxxxxxxxxxxxxslKocFnww%3D
    [Parameter(Mandatory = $true)]
    [string]
    $SASToken,

    # Registry path to check if the hardware hash has been uploaded.
    [Parameter(Mandatory = $false)]
    [string]
    $RegistryKeyPath = 'HKLM:\SOFTWARE\SystemAdmins\AutoPilot',

    # Registry key value to check if the hardware hash has been uploaded.
    [Parameter(Mandatory = $false)]
    [string]
    $RegistryKeyValueName = 'UploadedHashToBlobStorage'
)

# Get registry key value.
$RegistryKeyValue = Get-ItemPropertyValue `
    -Path $RegistryKeyPath `
    -Name $RegistryKeyValueName `
    -ErrorAction SilentlyContinue;

# If registry key value is already set to 1.
if (1 -eq $RegistryKeyValueName)
{
    # Write to log.
    Write-Host ("AutoPilot hash already uploaded to storage account '{0}.blob.core.windows.net'" -f $StorageAccountName);
    Write-Host ("Remove the registry key path '{0}', to enforce re-upload" -f $RegistryKeyPath);

    # Return true.
    return $true

    # Exit script.
    exit 0;
}

# Connect to local host.
$cimSession = New-CimSession;

# Get serial number.
$serialNumber = (Get-CimInstance `
        -CimSession $cimSession `
        -Class Win32_BIOS).SerialNumber;

# Get hardware hash.
$deviceHardwareData = (Get-CimInstance `
        -CimSession $cimSession `
        -Namespace root/cimv2/mdm/dmmap `
        -Class MDM_DevDetail_Ext01 `
        -Filter "InstanceID='Ext' AND ParentID='./DevDetail'").DeviceHardwareData;

# Create object.
[PSCustomObject]$autoPilotInfo = [PSCustomObject]@{
    'Device Serial Number' = $serialNumber;
    'Windows Product ID'   = '';
    'Hardware Hash'        = $deviceHardwareData;
};

# Get output file path.
[string]$outputFilePath = ('{0}\{1}_{2}.csv' -f $env:TEMP, $serialNumber, $env:COMPUTERNAME);

# Export to CSV.
$null = $autoPilotInfo | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | Out-File -FilePath $outputFilePath -Encoding utf8 -Force;

#Get the File-Name without path
[string]$outputFileName = (Get-Item -Path $outputFilePath).Name;

# Construct URI for uploading blob to storage account.
[string]$uri = ('https://{0}.blob.core.windows.net/{1}/{2}?{3}' -f $storageAccountName, $blobContainerName, $outputFileName, $sasToken);

# Define required headers.
[hashtable]$headers = @{
    'x-ms-blob-type' = 'BlockBlob'
};

# Boolean for upload success.
[bool]$uploadSuccess = $false;

# Try to upload file.
try
{
    # Upload File.
    $null = Invoke-RestMethod `
        -Uri $uri `
        -Method Put `
        -Headers $headers `
        -InFile $outputFilePath `
        -ErrorAction Stop;

    # Set upload success to true.
    $uploadSuccess = $true;
}
# Something went wrong uploading the file.
catch
{
    # Throw exception.
    throw ("Failed to upload file '{0}' to Azure Storage Account.`r`n{1}" -f $outputFilePath, $_);
}

# If the upload was successful.
if ($true -eq $uploadSuccess)
{
    # Create new registry path.
    $null = New-Item -Path $RegistryKeyPath -Force;

    # Set registry key.
    $null = New-ItemProperty `
        -Path $RegistryKeyPath `
        -Name $RegistryKeyValueName `
        -Value 1 `
        -Type DWord `
        -Force;

    # Remove the output file.
    $null = Remove-Item `
        -Path $outputFilePath `
        -Force `
        -ErrorAction SilentlyContinue;

    # Write to log.
    Write-Host ("AutoPilot hash uploaded to storage account '{0}.blob.core.windows.net'" -f $StorageAccountName);

    # Return true.
    return $true

    # Exit script.
    exit 0;
}
