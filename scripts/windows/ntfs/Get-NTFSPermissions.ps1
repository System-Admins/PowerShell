# CSV file for export.
$CSVFilePath = ("{0}\WeibelNTFSReport.csv" -f [Environment]::GetFolderPath("Desktop"));

# Get root items.
$Items = Get-ChildItem -Path "\\weibel.dk\files";

# Max parrallel threads.
$MaxThreads = 8;

# Foreach root item.
Foreach($Item in $Items)
{
    # Write to screen.
    Write-Host ("Checking item '{0}'" -f $Item.FullName);

    # Get items permissions.
    $Acls = Get-Acl -Path $Item.FullName;

    # Foreach permission.
    Foreach($Acl in $Acls)
    {
        # Foreach ACL.
        Foreach($Access in $Acl.Access)
        {
            # Check if the permission is inherited.
            If($Access.IsInherited -ne $true)
            {
                # Create custom object.
                [PSCustomObject]@{
                    "Path" = $Item.FullName;
                    "IsDirectory" = $Item.PSIsContainer;
                    "Identity" = $Access.IdentityReference;
                    "Permission" = $Access.FileSystemRights;
                    "IsInherited" = $Access.IsInherited;
                    "LastModifiedTime" = $Item.LastModifiedTime;
                    "LastAccessTime" = $Item.LastAccessTime;
                    "LastWriteTime" = $Item.LastWriteTime;
                } | Export-Csv -Path $CSVFilePath -Encoding UTF8 -NoTypeInformation -Append -Delimiter ";" -Force;
            }
        }
    }

    # Create script block.
    $ScriptBlock = {
        Param
        (
            $Item,
            $CSVFilePath
        )

        # Get all subfolders and files.
        $SubItems = Get-ChildItem -Path $Item.FullName -Recurse -Force;

        # Foreach sub item.
        Foreach($SubItem in $SubItems)
        {
            # Get items permissions.
            $Acls = Get-Acl -Path $SubItem.FullName;

            # Foreach permission.
            ForeacH($Acl in $Acls)
            {
                # Foreach ACL.
                Foreach($Access in $Acl.Access)
                {
                    # Check if the permission is inherited.
                    If($Access.IsInherited -ne $true)
                    {
                        # Create custom object.
                        [PSCustomObject]@{
                            "Path" = $SubItem.FullName;
                            "IsDirectory" = $SubItem.PSIsContainer;
                            "Identity" = $Access.IdentityReference;
                            "Permission" = $Access.FileSystemRights;
                            "IsInherited" = $Access.IsInherited;
                            "LastModifiedTime" = $SubItem.LastModifiedTime;
                            "LastAccessTime" = $SubItem.LastAccessTime;
                            "LastWriteTime" = $SubItem.LastWriteTime;
                        } | Export-Csv -Path $CSVFilePath -Encoding UTF8 -NoTypeInformation -Append -Delimiter ";" -Force;
                    }
                }
            }
        }
    };

    # If there is more than maximum jobs running.
    While ($(Get-Job -state running).count -ge $MaxThreads)
    {
        # Write to screen.
        Write-Host ("There is already {0} jobs running." -f $MaxThreads);

        # Sleep.
        Start-Sleep -Seconds 10;
    }

    # Start parallel job.
    Start-Job -ScriptBlock $ScriptBlock -ArgumentList $Item, $CSVFilePath | Out-Null;
}

# Wait for all jobs to finish.
While ($(Get-Job -State Running).count -gt 0)
{
    # Write to screen.
    Write-Host ("Jobs not finished yet, script not finished.");

    # Start sleep.
    Start-Sleep -Seconds 10;
}
