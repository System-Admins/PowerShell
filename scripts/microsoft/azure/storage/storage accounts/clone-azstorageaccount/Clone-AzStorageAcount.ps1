# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Must have the following modules installed.
#Requires -Module Az.Resources;
#Requires -Module Az.Storage;
#Requires -Module Az.Accounts;

# You can install the modules by running the following:
#Install-Module -Name Az.Resources -SkipPublisherCheck -Force -Scope CurrentUser;
#Install-Module -Name Az.Accounts -SkipPublisherCheck -Force -Scope CurrentUser;
#Install-Module -Name Az.Storage -SkipPublisherCheck -Force -Scope CurrentUser;

<#
.SYNOPSIS
  Clone a Azure storage with/without data.

.DESCRIPTION
  This script clones a Azure storage account with or without data.
  The script is split in two in order to use seperated Azure context.

  First step is to export info from the source storage account like so.
  .\Clone-AzStorageAccount.ps1 -Action "Export" -ResourceGroupName "MySourceResourceGroup" -StorageAccountName "MySourceStorageAccount";

  Now we need to create/update the target storage account.
  .\Clone-AzStorageAccount.ps1 -Action "Import" -ResourceGroupName "MyTargetResourceGroup" -StorageAccountName "MyTargetStorageAccount" -CopyData $true;

  You can also add/remove firewall rule.
  .\Clone-AzStorageAccount.ps1 -Action "FirewallAdd" -ResourceGroupName "MyResourceGroup" -StorageAccountName "MyStorageAccount";
  .\Clone-AzStorageAccount.ps1 -Action "FirewallRemove" -ResourceGroupName "MyResourceGroup" -StorageAccountName "MyStorageAccount";

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  03-10-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
Param
(
    # Action.
    [Parameter(Mandatory=$true)][ValidateSet("Export", "Import", "FirewallAdd", "FirewallRemove")][string]$Action,

    # Resource group name.
    [Parameter(Mandatory=$true)][string]$ResourceGroupName,

    # Storage account.
    [Parameter(Mandatory=$true)][string]$StorageAcccountName,

    # Copy data.
    [Parameter(Mandatory=$false)][bool]$CopyData = $true,

    # Template temp folder path.
    [Parameter(Mandatory=$false)][string]$TemplatePath = ("{0}\storage-account-clone" -f $env:TEMP)
)

# Clear host.
#Clear-Host;

# Import module(s).
Import-Module -Name Az.Resources -Force -DisableNameChecking;
Import-Module -Name Az.Accounts -Force -DisableNameChecking;
Import-Module -Name Az.Storage -Force -DisableNameChecking;

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
        [Parameter(Mandatory=$false)][string]$Text
    )
  
    # If text is not present.
    If([string]::IsNullOrEmpty($Text))
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

# Download and install AzCopy.
Function Install-AzCopy
{
    # Download url.
    $DownloadUrl = 'https://aka.ms/downloadazcopy-v10-windows';
    
    # Folder path for AzCopy.
    $DownloadPath = ("{0}\azcopy" -f $env:TEMP);

    # Archive path.
    $ArchivePath = ("{0}\azcopy.zip" -f $DownloadPath);

    # If download folder already exist.
    If(Test-Path -Path $DownloadPath -PathType Container)
    {
        # Write to log.
        Write-Log ("Cleaning the AzCopy folder '{0}'" -f $DownloadPath);

        # Remove folder.
        Remove-Item -Path $DownloadPath -Recurse -Force;
    }

    # Write to log.
    Write-Log ("Creating AzCopy folder '{0}'" -f $DownloadPath);

    # Create new folder.
    New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null;

    # Write to log.
    Write-Log ("Downloading AzCopy from '{0}' to '{1}'" -f $DownloadUrl, $ArchivePath);

    # Downlod AzCopy.
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchivePath -Method Get;

    # Write to log.
    Write-Log ("Unzipping zip file '{0}' to '{1}'" -f $ArchivePath, $DownloadPath);

    # Unzip archive.
    Expand-Archive -Path $ArchivePath -DestinationPath $DownloadPath -Force | Out-Null;

    # Get azcopy.exe path.
    $AzCopyExecutable = Get-ChildItem -Path $DownloadPath -Filter "azcopy.exe" -Recurse -Force | Select-Object -First 1;

    # Return path.
    Return $AzCopyExecutable.FullName;
}

# Archive JSON files.
Function Archive-JsonFiles
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Path
    )

    # Get date.
    $Ticks = (Get-Date).Ticks;

    # Get all JSON files in path.
    $Files = Get-ChildItem -Path $Path -Filter "*.json" -File -Force;

    # Foreach file.
    Foreach($File in $Files)
    {
        # Write to log.
        Write-Log ("Archiving (renaming) file '{0}'" -f $File.FullName, $Ticks);

        # Rename file.
        Rename-Item -Path $File.FullName -NewName ("{0}_{1}.archive" -f $Ticks, $File.Name) -Force -Confirm:$false | Out-Null;
    }
}

# Export ARM template.
Function Export-AzStorageAccountTemplate
{
    [cmdletbinding()]	
		
    Param
    (
        # Resource group name.
        [Parameter(Mandatory=$true)][string]$ResourceGroupName,

        # Storage account name.
        [Parameter(Mandatory=$true)][string]$Name,

        # Template temp folder path.
        [Parameter(Mandatory=$true)][string]$Path
    )
  
    # Get resource.
    $Resource = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $Name -ResourceType 'Microsoft.Storage/storageAccounts';

    # Export JSON template.
    $TemplateFile = Export-AzResourceGroup -ResourceGroupName $ResourceGroupName -Resource $Resource.ResourceId -Path $Path -WarningAction SilentlyContinue -Force -SkipAllParameterization;

    # If template file exist.
    If(Test-Path -Path $TemplateFile.Path -PathType Leaf)
    {  
        # Get template.
        $Template = Get-Content -Path $TemplateFile.Path -Force -Encoding UTF8;

        # Convert file from JSON to object array.
        $Template = $Template | ConvertFrom-Json;

        # Foreach resource in the template.
        Foreach($Resource in $Template.resources)
        {
            # Foreach property in the resource.
            Foreach($Property in $Resource.properties)
            {
                # If resource is a file services share.
                If($Resource.type -eq "Microsoft.Storage/storageAccounts/fileServices/shares")
                {
                    # If there is an "enabledProtocols" in properties.
                    If($Property.enabledProtocols)
                    {
                        # Remove the property.
                        $Property.PSObject.Properties.Remove('enabledProtocols');
                    }

                    # If there is an "accessTier" in properties.
                    If($Property.accessTier)
                    {
                        # Remove the property.
                        $Property.PSObject.Properties.Remove('accessTier');
                    }

                    # If there is an "shareQuota" in properties.
                    If($Property.shareQuota)
                    {
                        # Remove the property.
                        $Property.PSObject.Properties.Remove('shareQuota');
                    }
                }

                # If resource is a blob container.
                If($Resource.type -eq "Microsoft.Storage/storageAccounts/blobServices/containers")
                {
                    # If there is an "immutableStorageWithVersioning" in properties.
                    If($Property.immutableStorageWithVersioning)
                    {
                        # Remove the property.
                        $Property.PSObject.Properties.Remove('immutableStorageWithVersioning');
                    }
                }

                # If resource is a file service.
                If($Resource.type -eq "Microsoft.Storage/storageAccounts/fileServices")
                {
                    # If there is an "protocolSettings" in properties.
                    If($Property.protocolSettings)
                    {
                        # Remove the property.
                        $Property.PSObject.Properties.Remove('protocolSettings');
                    }
                }

                # If CORS property is exist.
                If($Property.cors)
                {
                    # Remove the property.
                    $Property.PSObject.Properties.Remove('cors');
            
                }
            }
        }

        # Convert object array to JSON again.
        $Template = $Template | ConvertTo-Json -Depth 99;

        # Save template.
        $Template | Set-Content -Path $TemplateFile.Path -Force -Encoding UTF8;

        # Return file path.
        Return [string]$TemplateFile.Path;
    }
}

# Replace string.
Function Find-StringReplace
{
    [cmdletbinding()]	
		
    Param
    (
        # Find string.
        [Parameter(Mandatory=$true)][string]$Find,

        # Replace string.
        [Parameter(Mandatory=$true)][string]$Replace,

        # File path.
        [Parameter(Mandatory=$true)][string]$Path
    )

    # If file exist.
    If(Test-Path -Path $Path -PathType Leaf)
    {
        # Write to log.
        Write-Log ("Find '{0}' in file '{1}' and replace with '{2}'" -f $Find, $Path, $Replace);

        # File content.
        $Content = Get-Content -Path $Path -Encoding UTF8 -Force;

        # Replace.
        $Content = $Content.Replace($Find, $Replace);

        # Save file.
        $Content |  Set-Content -Path $Path -Force -Encoding UTF8;
    }
    # Else no file.
    Else
    {
        # Write to log.
        Write-Log ("File '{0}' dont exist" -f $Path);
    }

}

# Copy Azure storage account data.
Function Copy-AzStorageAccountData
{
    [cmdletbinding()]	
		
    Param
    (
        # AzCopy path.
        [Parameter(Mandatory=$true)][string]$AzCopyPath,

        # Source.
        [Parameter(Mandatory=$true)][string]$SourceAccountName,
        [Parameter(Mandatory=$true)][string]$SourceSasToken,

        # Target.
        [Parameter(Mandatory=$true)][string]$TargetAccountName,
        [Parameter(Mandatory=$true)][string]$TargetSasToken
    )

    # Create argument.
    $AzCopyBlobArgument = ('copy "https://{0}.blob.core.windows.net/{1}" "https://{2}.blob.core.windows.net/{3}" --recursive --log-level ERROR' -f $SourceAccountName, $SourceSasToken, $TargetAccountName, $TargetSasToken);
    $AzCopyFileArgument = ('copy "https://{0}.file.core.windows.net/{1}" "https://{2}.file.core.windows.net/{3}" --recursive --log-level ERROR' -f $SourceAccountName, $SourceSasToken, $TargetAccountName, $TargetSasToken);

    # Write to log.
    Write-Log ("Starting copy from '{0}.blob.core.windows.net' to '{1}.blob.core.windows.net'" -f $SourceAccountName, $TargetAccountName);

    # Copy blob.
    Start-Process -FilePath $AzCopyPath -ArgumentList $AzCopyBlobArgument -NoNewWindow -Wait;

    # Write to log.
    Write-Log ("Starting copy from '{0}.file.core.windows.net' to '{1}.file.core.windows.net'" -f $SourceAccountName, $TargetAccountName);

    # Copy file shares.
    Start-Process -FilePath $AzCopyPath -ArgumentList $AzCopyFileArgument -NoNewWindow -Wait;
}

# Get public ip.
Function Get-PublicIpAddress
{
    # Get IP address.
    [string]$IpAddress = (Invoke-RestMethod -Uri http://ipinfo.io/json).ip;

    # Write to log.
    Write-Log ("Running from (public) IP {0}" -f $IpAddress);

    # Return IP.
    Return $IpAddress;
}

# Clone storage account.
Function Clone-AzStorageAccount
{
    [cmdletbinding()]	
		
    Param
    (
        # Action.
        [Parameter(Mandatory=$true)][ValidateSet("Export", "Import", "FirewallAdd", "FirewallRemove")][string]$Action,

        # Resource group name.
        [Parameter(Mandatory=$true)][string]$ResourceGroupName,

        # Storage account.
        [Parameter(Mandatory=$true)][string]$StorageAcccountName,

        # Copy data.
        [Parameter(Mandatory=$true)][bool]$CopyData,

        # Template temp folder path.
        [Parameter(Mandatory=$true)][string]$TemplatePath
    )

    # Get subscription info.
    $AzSubscription = (Get-AzContext).Subscription;

    # Get public IP.
    $PublicIp = "0.0.0.0/0" #Get-PublicIpAddress;

    # Path to config file.
    $ConfigFilePath = ("{0}\clone.config" -f $TemplatePath);

    # Get resource.
    $StorageAccount = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $StorageAcccountName -ResourceType 'Microsoft.Storage/storageAccounts' -ErrorAction SilentlyContinue;

    # If action is "Export".
    If($Action -eq "Export")
    {
        # If template temp folder path dont exist.
        If(!(Test-Path -Path $TemplatePath -PathType Container))
        {
            # Write to log.
            Write-Log ("Creating the folder '{0}'" -f $TemplatePath);

            # Create folder.
            New-Item -Path $TemplatePath -ItemType Directory -Force | Out-Null;
        }

        # Archive existing JSON files.
        Archive-JsonFiles -Path $TemplatePath;

        # If resource exist.
        If($StorageAccount)
        {
            # Write to log.
            Write-Log ("Storage account '{0}' in resource group '{1}' exist" -f $StorageAccount.Name, $StorageAccount.ResourceGroupName);

            # Export template to folder path.
            $TemplateFilePath = Export-AzStorageAccountTemplate -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.Name -Path $TemplatePath;

            # If config file already exist.
            If(Test-Path -Path $ConfigFilePath -PathType Leaf)
            {
                # Write to log.
                Write-Log ("Cleaning the config file '{0}'" -f $ConfigFilePath);

                # Remove file.
                Remove-Item -Path $ConfigFilePath -Force | Out-Null;
            }

            # Write to log.
            Write-Log ("Adding ip '{0}' in storage account firewall for '{0}'" -f $PublicIp, $StorageAcccountName);

            # Add firewall rule.
            Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $StorageAcccountName -IPAddressOrRange $PublicIp -ErrorAction SilentlyContinue | Out-Null;

            # Wait a few seconds.
            Start-Sleep -Seconds 10;

            # If data need to be migrated.
            If($CopyData)
            {
                # Try to create Azure storage account context.
                Try
                {
                    # Write to log.
                    Write-Log ("Creating SAS token for storage account '{0}'" -f $StorageAccount.Name);

                    # Get context.
                    $StorageAccountContext = (Get-AzStorageAccount -ResourceGroupName $StorageAccount.ResourceGroupName -AccountName $StorageAccount.Name -ErrorAction Stop).Context;

                    # Create SAS-token.
                    $SasToken = New-AzStorageAccountSASToken -Context $StorageAccountContext -Service Blob,File,Table,Queue -ResourceType Service,Container,Object -Permission "racwdlup" -StartTime ([System.DateTime]::UtcNow) -ExpiryTime ([System.DateTime]::UtcNow).AddDays(2) -ErrorAction Stop;

                    # Write to log.
                    Write-Log ("Successfully created SAS token for storage account '{0}'" -f $StorageAccount.Name);
                    Write-Log ("SAS token is '{0}'" -f $SasToken);
                }
                # Something went wrong.
                Catch
                {
                    # Write to log.
                    Write-Log ("Something went wrong creating SAS token for storage account '{0}'" -f $StorageAccount.Name);
                    
                    # Throw exception.
                    Throw($Error[0]);
                }
            }

            # Create object.
            $Config = [PSCustomObject]@{
                SubscriptionName = $AzSubscription.Name;
                SubscriptionId = $AzSubscription.Id;
                TenantId = $AzSubscription.TenantId;
                ResourceGroupName = $StorageAccount.ResourceGroupName;
                StorageAccountName = $StorageAccount.Name;
                ArmTemplateFilePath = $TemplateFilePath;
                SasToken = $SasToken;
            };

            # Write to log.
            Write-Log ("Updating the config file '{0}'" -f $ConfigFilePath);

            # Export the config file.
            $Config | ConvertTo-Json -Depth 99 | Out-File -FilePath $ConfigFilePath -Encoding utf8 -Force;
        }
        # Else resource dont exist.
        Else
        {
            # Throw error.
            Throw ("Storage account '{0}' in resource group '{1}' dont exist" -f $StorageAcccountName, $ResourceGroupName);
        }
    }
    # Else if action is "Import".
    ElseIf($Action -eq "Import")
    {
        # If config file already exist.
        If(Test-Path -Path $ConfigFilePath -PathType Leaf)
        {
            # Install AzCopy.
            $AzCopyPath = Install-AzCopy;

            # Import config data.
            $Config = Get-Content -Path $ConfigFilePath -Force -Encoding UTF8 | ConvertFrom-Json;

            # If resource dont exist.
            If(!($StorageAccount))
            {
                # Replace storage account name.
                Find-StringReplace -Path $Config.ArmTemplateFilePath -Find $Config.StorageAccountName -Replace $StorageAcccountName;

                # Try to create storage account.
                Try
                {
                    # Write to log.
                    Write-Log ("Trying to create storage account '{0}' in resource group '{1}'" -f $StorageAcccountName, $ResourceGroupName);
                    
                    # Create storage account.
                    New-AzResourceGroupDeployment -Name $StorageAcccountName -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $Config.ArmTemplateFilePath -SkipTemplateParameterPrompt -ErrorAction Stop | Out-Null;

                    # Write to log.
                    Write-Log ("Successfully created storage account '{0}' in resource group '{1}'" -f $StorageAcccountName, $ResourceGroupName);
                }
                # Something went wrong.
                Catch
                {
                    # Write to log.
                    Write-Log ("Something went wrong while creating storage account '{0}' in resource group '{1}'" -f $StorageAcccountName, $ResourceGroupName);

                    # Throw exception.
                    Throw ($Error[0]);
                }
            }
            # Else resource exist.
            Else
            {
                # Write to log.
                Write-Log ("Storage account '{0}' in resource group '{1}' already exist" -f $StorageAccount.Name, $StorageAccount.ResourceGroupName);
            }

            # Write to log.
            Write-Log ("Adding ip '{0}' in storage account firewall for '{0}'" -f $PublicIp, $StorageAcccountName);

            # Add firewall rule.
            Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $StorageAcccountName -IPAddressOrRange $PublicIp -ErrorAction SilentlyContinue | Out-Null;

            # Wait a few seconds.
            Start-Sleep -Seconds 10;

            # If data need to be migrated.
            If($CopyData)
            {
                # Get resource.
                $StorageAccount = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $StorageAcccountName -ResourceType 'Microsoft.Storage/storageAccounts' -ErrorAction SilentlyContinue;

                # If resource exist.
                If($StorageAccount)
                {
                    # Try to create Azure storage account context.
                    Try
                    {
                        # Write to log.
                        Write-Log ("Creating SAS token for storage account '{0}'" -f $StorageAcccountName);

                        # Get context.
                        $StorageAccountContext = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $StorageAcccountName -ErrorAction Stop).Context;

                        # Create SAS-token.
                        $SasToken = New-AzStorageAccountSASToken -Context $StorageAccountContext -Service Blob,File,Table,Queue -ResourceType Service,Container,Object -Permission "racwdlup" -StartTime ([System.DateTime]::UtcNow) -ExpiryTime ([System.DateTime]::UtcNow).AddDays(2) -ErrorAction Stop;

                        # Write to log.
                        Write-Log ("Successfully created SAS token for storage account '{0}'" -f $StorageAcccountName);
                        Write-Log ("SAS token is '{0}'" -f $SasToken);
                    }
                    # Something went wrong.
                    Catch
                    {
                        # Write to log.
                        Write-Log ("Something went wrong creating SAS token for storage account '{0}'" -f $StorageAcccountName);
                    
                        # Throw exception.
                        Throw($Error[0]);
                    }

                    # Copy data.
                    Copy-AzStorageAccountData -AzCopyPath $AzCopyPath -SourceAccountName $Config.StorageAccountName -SourceSasToken $Config.SasToken -TargetAccountName $StorageAcccountName -TargetSasToken $SasToken;
                }
                # Else resource dont exist.
                Else
                {
                    # Write to log.
                    Write-Log ("Storage account '{0}' dont exist" -f $StorageAcccountName);
                }
            }
        }
        # Else if config file dont exist.
        Else
        {
            # Throw.
            Throw ("The config file '{0}' (created during export) dont exist" -f $ConfigFilePath);
        }
    }
    # Else if action is "FirewallAdd".
    ElseIf($Action -eq "FirewallAdd")
    {
        # If resource exist.
        If($StorageAccount)
        {
            # Write to log.
            Write-Log ("Adding ip '{0}' in storage account firewall for '{0}'" -f $PublicIp, $StorageAcccountName);

            # Add firewall rule.
            Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $StorageAcccountName -IPAddressOrRange $PublicIp -ErrorAction SilentlyContinue | Out-Null;
        }
        # Else resource dont exist.
        Else
        {
            # Throw error.
            Throw ("Storage account '{0}' in resource group '{1}' dont exist" -f $StorageAcccountName, $ResourceGroupName);
        }
    }
    # Else if action is "FirewallRemove".
    ElseIf($Action -eq "FirewallRemove")
    {
        # If resource exist.
        If($StorageAccount)
        {
            # Write to log.
            Write-Log ("Removing ip '{0}' in storage account firewall for '{0}'" -f $PublicIp, $StorageAcccountName);
                        
            # Get firewall rule.# Remove rule.
            Remove-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $StorageAcccountName -IPAddressOrRange $PublicIp -ErrorAction SilentlyContinue | Out-Null;
        }
        # Else resource dont exist.
        Else
        {
            # Throw error.
            Throw ("Storage account '{0}' in resource group '{1}' dont exist" -f $StorageAcccountName, $ResourceGroupName);
        } 
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Clone storage account.
Clone-AzStorageAccount -Action $Action -ResourceGroupName $ResourceGroupName -StorageAcccountName $StorageAcccountName -CopyData $CopyData -TemplatePath $TemplatePath;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion
