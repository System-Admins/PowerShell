#Requires -version 5.1;

<#
.SYNOPSIS
  Return permissions for a folder or file.

.DESCRIPTION
  This script will return (advanced) permissions (ntfs and share) for folders or/and files.

.Parameter Path
  Path of the folder or file to return advanced permissions from.

.Parameter Recurse
  (Optional) Include subfolders and files.

.Parameter OutputPath
  (Optional) Output path for a CSV file.

.EXAMPLE
  Get-FileSystemPermission -Path "C:\Temp";

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  20-06-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]
[OutputType([System.Collections.ArrayList])]
param
(
    # Path of the folder or file to return advanced permissions from.
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$Path = "C:\Users\AlexHansen\OneDrive - System Admins\Desktop\test",

    # Include subfolders and files.
    [switch]$Recurse,

    # Export to CSV.
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -IsValid })]
    [string]$OutputPath
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Information -MessageData ('[{0}]: Collecting data from "{1}"' -f (Get-Date -Format 'dd-MM-yyyy hh:mm:ss'), $Path, $items.Count) -InformationAction Continue;

# Items array.
$items = @();

# If recursive search.
if ($true -eq $Recurse)
{
    # Get items using recursive search.
    $items += Get-ChildItem -Path $Path -Recurse -Force;
    $items += Get-Item -Path $Path;
}
# Else dont use recusive search.
else
{
    # Get item.
    $items += Get-Item -Path $Path;
}

# Get all non-system shares.
$shares = Get-SmbShare | Where-Object { $_.Special -eq $false };

# Write to log.
Write-Information -MessageData ('[{0}]: Found {1} item(s) from "{2}"' -f (Get-Date -Format 'dd-MM-yyyy hh:mm:ss'), $items.Count, $Path) -InformationAction Continue;

# Get file system rights enum.
$enumFileSystemRight = [System.Security.AccessControl.FileSystemRights];

# Hash table to store the rights.
$permissionDictionary = @{};

# Foreach permission name in enum.
foreach ($permissionName in [enum]::GetNames($enumFileSystemRight))
{
    # Convert the permission name to a numeric value.
    $numericValue = $permissionName -as $enumFileSystemRight -as [int];

    # If the numeric value is not a power of 2, then it's a combination of rights.
    if ($numericValue -band ($numericValue - 1))
    {
        # Skip this entry.
        continue;
    }

    # If the numeric value is not in the hash table.
    if (-not $permissionDictionary.ContainsKey($numericValue))
    {
        # Add it to the hash table.
        $permissionDictionary[$numericValue] = @();
    }

    # Add the permission name to the hash table entry.
    $permissionDictionary[$numericValue] += $permissionName;
}

# Sort the hash table by key.
$sortedPermissions = $permissionDictionary.GetEnumerator() | Sort-Object Name -Descending;

# Create script block.
$scriptBlockDetailedPermissions = {
    # Get the file system rights.
    $remainingAccessMask = [int]$this.FileSystemRights;

    # Array to store the detailed permissions.
    $detailedPermissions = @();

    # Foreach right entry in sorted permissions.
    foreach ($permissionEntry in $sortedPermissions)
    {
        # If the remaining access mask is 0, then break.
        if ($remainingAccessMask -eq 0)
        {
            break;
        }

        # If the permission entry name is in the remaining access mask.
        if ($remainingAccessMask -band $permissionEntry.Name)
        {
            # Add the permission entry value to the detailed permissions array.
            $detailedPermissions += $permissionEntry.Value -join '/';

            # Remove the permission entry name from the remaining access mask.
            $remainingAccessMask = $remainingAccessMask -bxor $permissionEntry.Name;
        }
    }

    # If the remaining access mask is not 0.
    if ($remainingAccessMask -ne 0)
    {
        # Add the remaining access mask to the detailed permissions array.
        $detailedPermissions += "Unknown ($remainingAccessMask)"
    }

    # Reverse the detailed permissions array.
    [array]::Reverse($detailedPermissions);

    # Join the detailed permissions array with a comma.
    $detailedPermissions -join ', '
};

# Result array.
$results = New-Object System.Collections.ArrayList;

# Foreach item.
foreach ($item in $items)
{
    # Write to log.
    Write-Verbose -Message ('Enumerating item "{0}"' -f $item.FullName);

    # Variable if item is folder.
    [bool]$isFolder = $false;

    # Variable if item is shared.
    [bool]$isShared = $false;

    # Share name.
    $shareName = $null;

    # Parent folder.
    $parentFolder = Split-Path -Path $item.FullName -Parent;

    # Get ACL.
    $acl = Get-Acl -Path $item.FullName;

    # If item is folder.
    if ($item -is [System.IO.DirectoryInfo])
    {
        # Set folder flag.
        $isFolder = $true;
    }

    # Get shares.
    $share = $shares | Where-Object { $item.FullName -like ('{0}*' -f $_.Path) }

    # If item is in a share.
    if ($null -ne $share)
    {
        # Set shared flag.
        $isShared = $true;

        # Set share name.
        $shareName = $share.Name;
    }

    # Foreach ACL (NTFS).
    foreach ($access in $acl.Access)
    {
        # Add detailed permissions to access object.
        $null = Add-Member -InputObject $access -MemberType ScriptProperty -Name DetailedPermissions -Value $scriptBlockDetailedPermissions;

        # Split file system rights.
        $fileSystemRights = $access.DetailedPermissions -split ',';

        # Foreach file system rights.
        foreach ($fileSystemRight in $fileSystemRights)
        {
            # Add to results.
            $result = [PSCustomObject]@{
                'Path'         = $item.FullName;
                'IsFolder'     = $isFolder;
                'Owner'        = $acl.Owner;
                'Identity'     = $access.IdentityReference;
                'ControlType'  = $access.AccessControlType;
                'Permission'   = $fileSystemRight.Trim();
                'IsInherited'  = $access.IsInherited;
                'IsShared'     = $isShared;
                'ShareName'    = $shareName;
                'ParentFolder' = $parentFolder;
                'Type'         = 'NTFS';
            };

            # Add to results.
            $null = $results.Add($result);
        }
    }

    # If item is shared.
    if ($true -eq $isShared)
    {
        # Get share permissions.
        $sharePermissions = Get-SmbShareAccess -Name $shareName;

        # Foreach share permission.
        foreach ($sharePermission in $sharePermissions)
        {
            # Add to results.
            $result = [PSCustomObject]@{
                'Path'         = $item.FullName;
                'IsFolder'     = $isFolder;
                'Owner'        = $acl.Owner;
                'Identity'     = $sharePermission.AccountName;
                'ControlType'  = $sharePermission.AccessControlType;
                'Permission'   = $sharePermission.AccessRight;
                'IsInherited'  = $null;
                'IsShared'     = $isShared;
                'ShareName'    = $shareName;
                'ParentFolder' = $parentFolder;
                'Type'         = 'Share';
            };

            # Add to results.
            $null = $results.Add($result);
        }
    }
}

# Write to log.
Write-Information -MessageData ('[{0}]: Finished collecting data from "{1}"' -f (Get-Date -Format 'dd-MM-yyyy hh:mm:ss'), $Path, $items.Count) -InformationAction Continue;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# If output path is specified.
if (-not [string]::IsNullOrEmpty($OutputPath))
{
    # Get the output path folder.
    $outputFolder = Split-Path -Path $OutputPath -Parent;

    # Create the output folder if it does not exist.
    if (-not (Test-Path -Path $outputFolder))
    {
        # Create the output folder.
        $null = New-Item -Path $outputFolder -ItemType Directory -Force;
    }

    # Try to export results to CSV.
    try
    {
        # Write to log.
        Write-Information -MessageData ('[{0}]: Exporting results to CSV file "{1}"' -f (Get-Date -Format 'dd-MM-yyyy hh:mm:ss'), $OutputPath) -InformationAction Continue;

        # Export results to CSV.
        $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Delimiter ';' -Force;
    }
    # Something went wrong exporting results to CSV.
    catch
    {
        # New output file path.
        $newOutputPath = ('{0}\{1}.csv' -f $outputFolder, (New-Guid).Guid);

        # Write to log.
        Write-Information -MessageData ('[{0}]: Something went wrong export to CSV file "{1}"' -f (Get-Date -Format 'dd-MM-yyyy hh:mm:ss'), $OutputPath) -InformationAction Continue;
        Write-Information -MessageData ('[{0}]: Trying new file name. Exporting results to CSV file "{1}"' -f (Get-Date -Format 'dd-MM-yyyy hh:mm:ss'), $newOutputPath) -InformationAction Continue;

        # Export results to CSV.
        $results | Export-Csv -Path $newOutputPath -NoTypeInformation -Encoding UTF8 -Delimiter ';' -Force;
    }
}
# Else return output.
else
{
    # Return results.
    return $results;
}

############### Finalize - End ###############
#endregion
