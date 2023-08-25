# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Require modules.
#Requires -Module Az.Storage;
#Requires -Module Az.Resources;

<#
.SYNOPSIS
  Mount Azure File Share locally to a drive.

.DESCRIPTION
  This script on works on Windows based machines.
  You need to have access to the storage account key.

.EXAMPLE
  # Mount Azure File Share to a PS drive under the current user.
  .\Mount-AzureFileShare.ps1 -StorageAccountName "MyStorageAcccount" -FileShare "MyFileShare" -MountName "MyMountPoint";

  # Mount Azure File Share to the drive letter "T:\" under the current user.
  .\Mount-AzureFileShare.ps1 -StorageAccountName "MyStorageAcccount" -FileShare "MyFileShare" -MountName "T" -Persist;

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  25-01-2023
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
[cmdletbinding()]
param
(
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9`]{3,24}$')][string]$StorageAccountName,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9](?:[a-z0-9]|(\-(?!\-))){1,61}[a-z0-9]$')][string]$FileShare,
    [Parameter(Mandatory = $false)][ValidatePattern('^[a-z0-9-`]{1,30}$')][string]$MountName = "AzureFileShare",
    [Parameter(Mandatory = $false)][switch]$Persist = $false
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

# If host is not Windows.
if ([System.Environment]::OSVersion.Platform -ne "Win32NT")
{
    # Throw execption.
    throw ("This script dont work on other than Windows, current OS platform is '{0}'" -f [System.Environment]::OSVersion.Platform);
}

# If host is not Windows.
if ($MountName.Length -ne 1 -and $Persist -eq $true)
{
    # Throw execption.
    throw ("To use the persist parameter, you must apply a single drive letter from A to Z");
}

# Get storage account resource.
$AzResource = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts' -Name $StorageAccountName -ErrorAction SilentlyContinue;

# If the resource dont exist.
if ($null -eq $AzResource)
{
    # Throw execption.
    throw ("The storage account '{0}' dont exist" -f $StorageAccountName);
}

# Get storage account.
$StorageAccount = Get-AzStorageAccount -ResourceGroupName $AzResource.ResourceGroupName -Name $AzResource.Name;

# Get container.
$Share = Get-AzStorageShare -Context $StorageAccount.Context -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $FileShare };

# If file share dont exist.
if ($null -eq $Share)
{
    # Throw execption.
    throw ("The file '{0}' dont exist in storage account '{1}'" -f $FileShare, $StorageAccountName);
}

# Get file share endpoint.
$FileShareEndpoint = [System.Uri]$StorageAccount.PrimaryEndpoints.File

# Test TCP connection against file share on TCP/445.
$TestConnection = Test-NetConnection -ComputerName $FileShareEndpoint.DnsSafeHost -Port 445 -WarningAction SilentlyContinue;

# If firewall is closed.
if ($false -eq $TestConnection.TcpTestSucceeded)
{
    # Throw execption.
    throw ("Firewall is closed (TCP/445) to '{0}'" -f $FileShareEndpoint.DnsSafeHost);
}

# Get access key from storage account.
$StorageAccountKey = Get-AzStorageAccountKey -ResourceGroupName $AzResource.ResourceGroupName -Name $AzResource.Name | Select-Object -First 1 -ExpandProperty Value;

# If storage account key is empty.
if ([string]::IsNullOrEmpty($StorageAccountKey))
{
    # Throw execption.
    throw ("Could not get access key from storage account '{0}'" -f $AzResource.Name);
}

# Get username and password for connection.
$StorageAccountUsername = ('localhost\{0}' -f $AzResource.Name);
$StorageAccountPassword = $StorageAccountKey;

# Construct file share UNC path.
$FileShareUncPath = ('\\{0}\{1}' -f $FileShareEndpoint.DnsSafeHost, $FileShare);

# Convert the password to a secure string.
$SecureStorageAccountPassword = $StorageAccountPassword | ConvertTo-SecureString -AsPlainText -Force;
 
# Convert username and password to a credential object.
$StorageAccountCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $StorageAccountUsername, $SecureStorageAccountPassword;

# Get SMB client.
$SmbClient = Get-Service -Name "LanmanWorkstation";

# Get LmCompatibilityLevel registry value.
$LmCompatibilityLevel = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -ErrorAction SilentlyContinue;

# If LmCompatibilityLevel is set.
if ($null -ne $LmCompatibilityLevel)
{
    # Get LmCompatibilityLevel registry value.
    $LmCompatibilityLevelValue = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -ErrorAction SilentlyContinue;

    # If value is not set to "only" NTLMv2.
    if ($LmCompatibilityLevelValue -lt 3 -or $LmCompatibilityLevelValue -gt 5)
    {
        # Throw execption.
        throw ("'LmCompatibilityLevel' is set to '{0}', but should be 3, 4 or 5" -f $LmCompatibilityLevelValue);
    }
}

# If SMB 1.0 is enabled.
if ($SmbClient.ServicesDependedOn | Where-Object { $_.Name -eq "mrxsmb10" -and $_.Status -eq "Running" })
{
    # Throw execption.
    throw ("SMB 1.0 is enabled on the host running this script, it is not compatible with Azure File Share");
}

# If mount point already exist.
if (Test-Path -Path ('{0}:' -f $MountName))
{
    # Try to remove mount point.
    try
    {
        # Write to log.
        Write-Log ("Mount point '{0}' already exist, trying to remove" -f $MountName);

        # Remove PS drive.
        Remove-PSDrive -Name $MountName -Force | Out-Null;

        # Write to log.
        Write-Log ("Successfully removed existing mount point '{0}' " -f $MountName);
    }
    # Something went wrong while removing existing mount point.
    catch
    {
        # Throw execption.
        throw ("Existing mount point '{0}' could not be removed, here is the execption:`r`n {1}" -f $MountName, $_)
    }
}

# Try to mount file share.
try
{
    # Write to log.
    Write-Log ("Trying to create a mount point on '{0}' for '{1}'" -f $MountName, $FileShareUncPath);

    # Mount file share.
    New-PSDrive -Name $MountName -PSProvider FileSystem -Root $FileShareUncPath -Credential $StorageAccountCredential -Confirm:$false -Persist:$Persist -ErrorAction Stop | Out-Null;

    # Write to log.
    Write-Log ("Successfully mounted '{0}' on '{1}'" -f $FileShareUncPath, $MountName);
}
# Something went wrong mount file share.
catch
{
    # Throw execption.
    throw ("Could not mount file share, maybe because of computer policies, here is the execption:`r`n {0}" -f $_);
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Log ("Script finished at {0}" -f (Get-Date));

############### Finalize - End ###############
#endregion
