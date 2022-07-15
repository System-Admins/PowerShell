#requires -version 5.1

<#
.SYNOPSIS
  Download software (for Windows) from the WinGet repository with all necessary details to push into an software deployment system such as SCCM or Endpoint Manager.

.DESCRIPTION
  Searches the WinGet manifest files, gets all the info such as silent install commandline, publisher, architecture, version language and so on.
  It will create an folder with the following syntax "C:\MyPath\Publisher\Program\Architecture\Version" (default is desktop).
  An installation and metadata (JSON) file will be generated in the above folder.
  To find package id, the easist way is to use the homepage "https://winget.run".

.Parameter PackageId
  The package id from WinGet. You can find an ID through WinGet utility or https://winget.run

.Parameter Architecture
  If the program should be 64 (x64) or 32-bit (x86).

.Parameter Version
  If the program should be a specific version.

.Parameter OutputPath
  Where the files should be downloaded/generated. Default is the desktop in the running context.

.Parameter AccessToken
  Personal access token (PAT) for the GitHub API. This is only required if you hit API throttle limitation.

.Example
   # Download latest version of Slack. 
   .\Download-WinGetPackage.ps1 -PackageId "SlackTechnologies.Slack" -Architecture "x86";

.Example
   # Download specific version of Slack. 
   .\Download-WinGetPackage.ps1 -PackageId "SlackTechnologies.Slack" -Architecture "x64" -Version "4.23.0";

.Example
   # Download latest version of Slack to a specific folder. 
   .\Download-WinGetPackage.ps1 -PackageId "SlackTechnologies.Slack" -Architecture "x64" -OutputPath "C:\MyPackages";

.NOTES
  Version:        0.1
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  14-07-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]

Param
(
    # Package id.
    [Parameter(Mandatory=$true)][string]$PackageId,

    # Architecture (x86 or x64).
    [Parameter(Mandatory=$true)][ValidateSet("x64", "x86")][string]$Architecture,

    # Version.
    [Parameter(Mandatory=$false)][string]$Version,

    # Folder path for output files.
    [Parameter(Mandatory=$false)][string]$OutputPath = ('{0}\Packages' -f $env:TEMP),

    # GitHub API access token.
    [Parameter(Mandatory=$false)][string]$AccessToken
)

# Clear screen.
#Clear-Host;

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
        [Parameter(Mandatory=$false)][string]$Text
    )
 
    # If the input is empty.
    If([string]::IsNullOrEmpty($Text))
    {
        Write-Host "";
    }
    Else
    {
        # Write to the console.
        Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
}

# Check if module is installed.
Function Check-Module
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Name
    )
 
    # If module is installed.
    If(Get-Module -ListAvailable | Where-Object {$_.Name -eq $Name})
    {
        # Write to log.
        Write-Log ("Importing module '{0}'" -f $Name);

        # Import module.
        Import-Module -Name $Name -Force -DisableNameChecking | Out-Null;
    }
    # Module not installed.
    Else
    {
        # Check if PS gallery is not trusted.
        If(Get-PSRepository -Name "PSGallery" | Where-Object {$_.InstallationPolicy -ne "Trusted"})
        {
            # Trust PSGallery.
            Set-PSGalleryRepository -Trusted -ErrorAction SilentlyContinue;
        }

        # Try to install.
        Try
        {
            # Write to log.
            Write-Log ("Trying to install module '{0}'" -f $Name);

            # Install module.
            Install-Module -Name $Name -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force;

            # Write to log.
            Write-Log ("Installed module '{0}'" -f $Name);

            # Return true.
            Return $true;
        }
        Catch
        {
            # Exception.
            Throw ("Failed installing module '{0}'" -f $Name);
        }
    }
}

# Get all WinGet package manifests.
Function Get-WinGetRepo
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Master = 'https://api.github.com/repos/microsoft/winget-pkgs/git/trees/master',
        [Parameter(Mandatory=$false)][string]$AccessToken,
        [Parameter(Mandatory=$false)][string]$CacheFilePath = ('{0}\WinGet\Manifest\manifests.json' -f $env:TEMP)
    )

    # If cache file is specified, exists and is not too old.
    If(!([string]::IsNullOrEmpty($CacheFilePath)) -and (Test-Path -Path $CacheFilePath) -and (Get-Item -Path $CacheFilePath -ErrorAction SilentlyContinue).LastWriteTime -ge (Get-Date).AddHours(-4))
    {
        # Write to log.
        Write-Log ("Importing manifest cache from '{0}'" -f $CacheFilePath);

        # Get manifest from cache file.
        $Manifests = Get-Content -Path $CacheFilePath -Encoding UTF8 -Force -Raw | ConvertFrom-Json;
    }
    Else
    {
        # If access token is set.
        If(!([string]::IsNullOrEmpty($AccessToken)))
        {
            # Write to log.
            Write-Log ("Using personal access token for the GitHub API '{0}'" -f $AccessToken);

            # Convert to BASE64.
            $Base64 = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($AccessToken)"));

            # Add parameters.
            $Parameters = @{
                Headers = @{
                    authorization = "Basic $Base64"
                };
            };
        }
   
        # Try to get SHA.
        Try
        {
            # Write to log.
            Write-Log ("Getting SHA from '{0}'" -f $Master);

            # If access token is not set.
            If([string]::IsNullOrEmpty($AccessToken))
            {
                # Get SHA.
                $Sha = (Invoke-RestMethod -Method Get -Uri $Master -ContentType "application/json" -ErrorAction Stop).tree | Where-Object {$_.path -eq "manifests"} | Select-Object -ExpandProperty sha;
            }
            Else
            {
                # Get SHA.
                $Sha = (Invoke-RestMethod -Method Get -Uri $Master -ContentType "application/json" @Parameters -ErrorAction Stop).tree | Where-Object {$_.path -eq "manifests"} | Select-Object -ExpandProperty sha;
            }
        }
        # Something went wrong.
        Catch
        {
            # Write to log.
            Write-Log ("Something went wrong while getting SHA from '{0}', here is the error" -f $Master);
            Write-Host ($Error[0]);

            # Exit.
            Exit 1;
        }
    
        # Try to get root folders.
        Try
        {
            # Manifest URL from master.
            $Repository = ('https://api.github.com/repos/microsoft/winget-pkgs/git/trees/{0}' -f $Sha);

            # Write to log.
            Write-Log ("Using SHA '{0}' and getting manifests from '{1}'" -f $Sha, $Repository);

            # If access token is not set.
            If([string]::IsNullOrEmpty($AccessToken))
            {
                # Get root folders.
                $RootFolders = (Invoke-RestMethod -Method Get -Uri $Repository -ContentType "application/vnd.github+json").tree;
            }
            Else
            {
                # Get root folders.
                $RootFolders = (Invoke-RestMethod -Method Get -Uri $Repository @Parameters -ContentType "application/vnd.github+json").tree;
            }
        }
        # Something went wrong.
        Catch
        {
            # Write to log.
            Write-Log ("Something went wrong while getting root folders from '{0}', here is the error" -f $Master);
            Write-Host ($Error[0]);

            # Exit.
            Exit 1;
        }

        # Object array.
        $Manifests = @();

        # Foreach folder.
        Foreach($RootFolder in $RootFolders)
        {
            # Try to get folders items.
            Try
            {
                # Construct URL for recursive.
                $SubFoldersUrl = ('{0}?recursive=1' -f $RootFolder.url);

                # If access token is not set.
                If([string]::IsNullOrEmpty($AccessToken))
                {
                    # Get manifests.
                    $SubManifests = (Invoke-RestMethod -Method Get -Uri $SubFoldersUrl -ContentType "application/vnd.github+json").tree;
                }
                Else
                {
                    # Get manifests.
                    $SubManifests = (Invoke-RestMethod -Method Get -Uri $SubFoldersUrl @Parameters -ContentType "application/vnd.github+json").tree;
                }

                # Foreach manifest.
                Foreach($SubManifest in $SubManifests)
                {
                    # Update path to include root folder.
                    $SubManifest.path = ("{0}/{1}" -f $RootFolder.path, $SubManifest.path)
                }

                # Add to object array.
                $Manifests += $SubManifests;
            }
            # Something went wrong.
            Catch
            {
                # Write to log.
                Write-Log ("Something went wrong while getting sub folders from '{0}', here is the error" -f $SubFoldersUrl);
                Write-Host ($Error[0]);

                # Exit.
                Exit 1;
            }
        }

        # Write to log.
        Write-Log ("Creating folder '{0}'" -f  (Split-Path -Path $CacheFilePath).ToString());

        # Create output folder.
        New-Item -Path (Split-Path -Path $CacheFilePath).ToString() -ItemType Directory -Force | Out-Null;

        # If cache file exist.
        If(Test-Path -Path $CacheFilePath)
        {
            # Write to log.
            Write-Log ("Removing existing cache file '{0}'" -f $CacheFilePath);

            # Remove cache file.
            Remove-Item -Path $CacheFilePath -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null;
        }
        
        # Write to log.
        Write-Log ("Exporting manifest to cache file '{0}'" -f $CacheFilePath);

        # Export to cache file.
        $Manifests | ConvertTo-Json -Depth 99 | Out-File -FilePath $CacheFilePath -Encoding UTF8 -Force;
    }

    # Return manifests.
    Return ($Manifests | Where-Object {$_.type -eq "blob"} | Select-Object Path, Url);
}

# Convert string to version.
Function ConvertTo-Version
{
    [cmdletbinding()]	
		
    Param
    (
        # String to convert.
        [Parameter(Mandatory=$true)][string]$InputString
    )

    # Try to convert.
    Try
    {
        # Replace all other chars than numbers into a dot.
        $Data = $InputString -replace "([^0-9])", ".";

        # Convert string to System.Version.
        $Version = [System.Version]::Parse($Data);
    }
    # Cant convert.
    Catch
    {
        # Replace all other chars than numbers into a dot.
        $Version = $InputString -replace "([^0-9])", ".";
    }

    # Return.
    Return $Version;
}

# Get specific package manifest latest version.
Function Get-WinGetPackage
{
    [cmdletbinding()]	
		
    Param
    (
        # Manifests.
        [Parameter(Mandatory=$true)]$WinGetManifests,

        # Package id.
        [Parameter(Mandatory=$true)][string]$PackageId,

        # Package id.
        [Parameter(Mandatory=$false)][string]$Version
    )

    # Packages.
    $Packages = @();

    # Foreach manifest.
    Foreach($WinGetManifest in $WinGetManifests)
    {
        # Get package id from YAML file.
        $PackageIdentifier = (($WinGetManifest.path -split "/")[-1] -replace ".yaml","");

        # If package matches parameter id.
        If($PackageIdentifier -eq $PackageId)
        {
            # Get version from YAML file.
            $PackageVersion = ($WinGetManifest.path -split "/")[($WinGetManifest.path -split "/").Count-2];
            
            # Convert to version (if possible).
            $PackageVersion = ConvertTo-Version -InputString $PackageVersion;

            # Write to log.
            #Write-Log ("Found package id '{0}' with version '{1}'" -f $PackageIdentifier, $PackageVersion);

            # Add to packages.
            $Packages += [PSCustomObject]@{
                Id = $PackageIdentifier;
                Version = $PackageVersion;
                Path = $WinGetManifest.path;
                Url = $WinGetManifest.url;
            };
        }
    }

    # If versions is populated.
    If($Packages)
    {
        # If package version is specified.
        If(!([string]::IsNullOrEmpty($Version)))
        {
            # Get latest version.
            $Package = $Packages | Where-Object {$_.Version -eq $Version} | Sort-Object Version | Select-Object -First 1;

            # If package exist.
            If($Package)
            {
                # Write to log.
                Write-Log ("Using package id '{0}' with specified version '{1}'" -f $Package.Id, $Package.Version);

                # Return result.
                Return $Package;
            }
            # Else package dont exist.
            Else
            {
                # Throw error.
                Throw ("Package id '{0}' with version '{1}' dont exist, aborting" -f $PackageId, $Version);
            }
        }
        # No package version specified.
        Else
        {
            # Write to log.
            Write-Log ("Using latest version" -f $PackageIdentifier, $PackageVersion);

            # Get latest version.
            $Package = $Packages | Sort-Object Version -Descending | Select-Object -First 1;

            # Write to log.
            Write-Log ("Using package id '{0}' with version '{1}'" -f $Package.Id, $Package.Version);

            # Return result.
            Return $Package;
        }
    }
    # No results.
    Else
    {
        # Write to log.
        Write-Log ("No package found with id '{0}'" -f $PackageId);

        # Throw execption.
        Throw ("No package found with id '{0}'" -f $PackageId);
    }
}

# Download file.
Function Download-File
{
    [cmdletbinding()]	
		
    Param
    (
        # URL to file.
        [Parameter(Mandatory=$true)][string]$Url,

        # Output folder.
        [Parameter(Mandatory=$true)][string]$Path,

        # Filename.
        [Parameter(Mandatory=$false)][string]$FileName
    )

    # If directory dont exist.
    If(!(Test-Path -Path $Path))
    {
        # Write to log.
        Write-Log ("Creating output folder '{0}'" -f $Path);

        # Create output path.
        New-Item -Path $Path -ItemType Directory -Force -Confirm:$false | Out-Null;
    }

    # If filename is not set.
    If(!($FileName))
    {
        # Get filename from URL.
        $FileName = ($Uri -split "/")[-1];
    }

    # Output path.
    $Output = ("{0}\{1}" -f $Path, $FileName);

    # Check if the file already exist in output folder.
    If(Test-Path -Path $Output)
    {
        # Write to log.
        Write-Log ("File already exist at '{0}', will now delete" -f $Output);
        
        # Remove file prior to downloading.
        Remove-Item -Path $Output -Force -Confirm:$false -ErrorAction SilentlyContinue;
    }

    # Write to log.
    Write-Log ("Downloading file from '{0}' to '{1}'" -f $Url, $Output);

    # Download binary file.
    Invoke-WebRequest -Uri $Url -OutFile $Output;
}

# Get package manifests.
Function Get-WinGetPackageManifest
{
    [cmdletbinding()]	
		
    Param
    (
        # Manifests.
        [Parameter(Mandatory=$true)]$WinGetManifests,

        # URL to YAML.
        [Parameter(Mandatory=$true)][string]$Path
    )

    # Get path for manifests.
    $SearchFilter = $Path -replace ".yaml","";

    # Get all manifests with specific path.
    Return $WinGetManifests | Where-Object {$_.Path -like ("{0}*" -f $SearchFilter)};
}

# Download package manifests.
Function Download-WinGetPackageManifest
{
    [cmdletbinding()]	
		
    Param
    (
        # Manifests.
        [Parameter(Mandatory=$true)]$WinGetManifests,

        # Output path.
        [Parameter(Mandatory=$true)][string]$Path
    )

    # Foreach manifest.
    Foreach($WinGetManifest in $WinGetManifests)
    {
        # Get file name.
        $FileName = ($WinGetManifest.path -split "/")[-1];

        # Download YAML file.
        Download-File -Url ("https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/{0}" -f $WinGetManifest.path) -Path $Path -FileName $FileName;
    }
}

# Load package manifest to memory.
Function Load-WinGetPackageManifest
{
    [cmdletbinding()]	
		
    Param
    (
        # Output path.
        [Parameter(Mandatory=$true)][string]$Path
    )

    # Get all manifests.
    $ManifestFiles = Get-ChildItem -Path $Path -Filter "*.yaml";

    # Object array.
    $Manifests = @();

    # Foreach manifest file.
    Foreach($ManifestFile in $ManifestFiles)
    {
        # Try to load and convert to object.
        Try
        {
            # Write to log.
            Write-Log ("Loading file '{0}'" -f $ManifestFile.FullName);

            # Get content from manifest and remove no-break space.
            $ManifestObject = (Get-Content -Path $ManifestFile.FullName -Encoding UTF8 -Raw) -replace [char]0xfeff,"" | ConvertFrom-Yaml -AllDocuments | ConvertTo-Json -Depth 99 | ConvertFrom-Json; 
            
            # Check if WinGet manifest file.
            If($ManifestObject.ManifestType)
            {
                # Manifest.
                $Manifests += [PSCustomObject]@{
                    ManifestType = $ManifestObject.ManifestType;
                    Resource = $ManifestObject
                };
            }
            # Not a manifest file.
            Else
            {
                # Write to log.
                Write-Log ("File '{0}' is not a WinGet manifest file" -f $ManifestFile.FullName);

            }
        }
        Catch
        {
            # Exception.
            Throw ("Cant convert file '{0}' from YAML" -f $ManifestFile.FullName);
        }
    }

    # Write to log.
    #Write-Log ("Removing temporary manifest files");

    # Remove manifest files.
    #$ManifestFiles | Remove-Item -Force -Confirm:$false;

    # Return.
    Return $Manifests;
}

# Get package details.
Function Get-PackageDetails
{
    [cmdletbinding()]	
		
    Param
    (
        # Manifest.
        [Parameter(Mandatory=$true)]$Manifests
    )

    # Package metadata.
    $Package = [PSCustomObject]@{  
        Name = "";
        Version = "";
        Publisher = "";
        ProjectUrl = "";
        Description = "";
        License = "";
        Locale = "";

    };

    # Foreach manifest.
    Foreach($Manifest in $Manifests)
    {
        # If manifest is default locale or singleton.
        If($Manifest.ManifestType -eq "defaultLocale" -or $Manifest.ManifestType -eq "singleton")
        {
            # Add to object.
            $Package.Name = $Manifest.Resource.PackageName;
            $Package.Version = $Manifest.Resource.PackageVersion;
            $Package.Publisher = $Manifest.Resource.Publisher;
            $Package.ProjectUrl = $Manifest.Resource.PackageUrl;
            $Package.Description = $Manifest.Resource.ShortDescription;
            $Package.License = $Manifest.Resource.License;
            $Package.Locale = $Manifest.Resource.PackageLocale;
        }
    }

    # Return details.
    Return $Package;
}

# Get package installer switches.
Function Get-PackageInstallerSwitches
{
    [cmdletbinding()]	
		
    Param
    (
        # Installer type.
        [Parameter(Mandatory=$true)][ValidateSet("msix", "msi", "appx", "exe", "zip", "inno", "nullsoft", "wix", "burn", "pwa", "portable")][string]$InstallerType
    )

    # Set executable to wildcard.
    $Executable = '{0}';

    # MSI or WIX.
    If($InstallerType -eq "msi" -or $InstallerType -eq "wix")
    {
        # Install switch.
        $InstallSwitch = ('msiexec /i {0} /qn' -f $Executable);
    }
    # MSIX or AppX.
    If($InstallerType -eq "msix" -or $InstallerType -eq "appx")
    {
        # Install switch.
        $InstallSwitch = ('Add-AppXPackage -Path "{0}" -AllowUnsigned:$true -Confirm:$false -ForceApplicationShutdown -ForceUpdateFromAnyVersion' -f $Executable);
    }
    # Inno.
    ElseIf($InstallerType -eq "inno")
    {
        # Install switch.
        $InstallSwitch = ('{0} /FORCECLOSEAPPLICATIONS /VERYSILENT /SP- /NOCANCEL /NORESTART /RESTARTAPPLICATIONS' -f $Executable);
    }
    # Nullsoft.
    ElseIf($InstallerType -eq "nullsoft")
    {
        # Install switch.
        $InstallSwitch = ('{0} /S' -f $Executable);
    }
    # Exe.
    ElseIf($InstallerType -eq "exe")
    {
        # Install switch.
        $InstallSwitch = ('{0} /S' -f $Executable);
    }

    # Return installer switch.
    Return $InstallSwitch;
}

# Get package installers.
Function Get-PackageInstallers
{
    [cmdletbinding()]	
		
    Param
    (
        # Manifest.
        [Parameter(Mandatory=$true)]$Manifests,

        # Manifest.
        [Parameter(Mandatory=$false)][ValidateSet("x64", "x86")][string]$Architecture
    )

    # Object array.
    $PackageInstallers = @();

    # If there is a installer/singleton manifest.
    If($Manifest = $Manifests | Where-Object {$_.ManifestType -eq "installer" -or $_.ManifestType -eq "singleton"})
    {
        # Get locale info.
        $Locale = ($Manifests | Where-Object {$_.ManifestType -eq "defaultLocale" -or $_.ManifestType -eq "locale"} | Select-Object -First 1).Resource;

        # Foreach installer.
        Foreach($Installer in $Manifest.Resource.Installers)
        {
            # Clear variables.
            $InstallerArchitecture,
            $InstallerUrl,
            $InstallerFileName,
            $InstallerType,
            $InstallerLocale,
            $InstallerCmdLine,
            $InstallerSwitchSilent,
            $InstallerSwitchCustom,
            $Scope = $null;

            # If architecture is set.
            If($Installer.PSobject.Properties.name -match 'Architecture')
            {
                # Set variable.
                $InstallerArchitecture = $Installer.Architecture;
            }

            # If installer url is set.
            If($Installer.PSobject.Properties.name -match 'InstallerUrl')
            {
                # Set variable.
                $InstallerUrl = $Installer.InstallerUrl;

                # Installer filename.
                $InstallerFileName = [uri]::UnescapeDataString(($Installer.InstallerUrl -split "/")[-1]);
            }

            # If installer type is set.
            If($Installer.PSobject.Properties.name -match 'InstallerType')
            {
                # Set variable.
                $InstallerType = $Installer.InstallerType;
            }
            # Else if the installer type is at root level
            ElseIf($Manifest.Resource.PSobject.Properties.name -match 'InstallerType')
            {
                # Set variable.
                $InstallerType = $Manifest.Resource.InstallerType;
            }

            # If installer locale is set.
            If($Installer.PSobject.Properties.name -match 'InstallerLocale')
            {
                # Set variable.
                $InstallerLocale = $Installer.InstallerLocale;
            }
            # Else package locale is set.
            ElseIf($Manifest.Resource.PSobject.Properties.name -match 'PackageLocale')
            {
                # Set variable.
                $InstallerLocale = $Installer.PackageLocale;
            }
            # Else if the installer locale is at root level
            ElseIf($Manifest.Resource.PSobject.Properties.name -match 'InstallerLocale')
            {
                # Set variable.
                $InstallerLocale = $Manifest.Resource.InstallerLocale;
            }
            # Else if the installer locale is at root level
            ElseIf($Locale.PSobject.Properties.name -match 'PackageLocale')
            {
                # Set variable.
                $InstallerLocale = $Locale.PackageLocale;
            }

            # If installer switches is set.
            If($Installer.PSobject.Properties.name -match 'InstallerSwitches')
            {

                # Check if there is a custom switch.
                If($Installer.InstallerSwitches.PSobject.Properties.name -match 'Custom')
                {
                    # Set variable.
                    $InstallerSwitchCustom = $Installer.InstallerSwitches.Custom;
                }
                
            }
            # Else if the installer switch is at root level
            ElseIf($Manifest.Resource.PSobject.Properties.name -match 'InstallerSwitches')
            {
                # Check if there is a custom switch.
                If($Manifest.Resource.InstallerSwitches.PSobject.Properties.name -match 'Custom')
                {
                    # Set variable.
                    $InstallerSwitchCustom = $Manifest.Resource.InstallerSwitches.Custom;
                }
            }

            # If scope is set.
            If($Installer.PSobject.Properties.name -match 'Scope')
            {
                # If scope is machine.
                If($Installer.Scope -eq "machine")
                {
                    # Set variable.
                    $Scope = "system";   
                }
                # Else if the scope is user.
                ElseIf($Installer.Scope -eq "user")
                {
                    # Set variable.
                    $Scope = "user";   
                }
            }
            # Else if the scope is at root level
            ElseIf($Manifest.Resource.PSobject.Properties.name -match 'Scope')
            {
                # If scope is machine.
                If($Manifest.Resource.Scope -eq "machine")
                {
                    # Set variable.
                    $Scope = "system";   
                }
                # Else if the scope is user.
                ElseIf($Manifest.Resource.Scope -eq "user")
                {
                    # Set variable.
                    $Scope = "user";   
                }
            }

            # Check if there is a custom switch.
            If($Installer.InstallerSwitches.PSobject.Properties.name -match 'Silent')
            {
                # Set variable.
                $InstallerSwitchSilent = $Installer.InstallerSwitches.Silent;
            }
            # Else if the scope is at root level.
            ElseIf($Manifest.Resource.InstallerSwitches.PSobject.Properties.name -match 'Silent')
            {
                # Set variable.
                $InstallerSwitchSilent = $Manifest.Resource.InstallerSwitches.Silent;
            }

            # If installer type is set.
            If(!([string]::IsNullOrEmpty($InstallerType)))
            {
                # If silent switch is set.
                If($InstallerSwitchSilent)
                {
                    # Set install cmdline.
                    $InstallerCmdLine = ("{0} {1}" -f $InstallerFileName, $InstallerSwitchSilent);
                }
                Else
                {             
                    # Get generic install switch.
                    $InstallerCmdLine = ((Get-PackageInstallerSwitches -InstallerType $InstallerType).ToString() -f $InstallerFileName);
                }
            }
            Else
            {             
                # Get generic install switch.
                $InstallerCmdLine = ((Get-PackageInstallerSwitches -InstallerType $InstallerType).ToString() -f $InstallerFileName);
            }

            # If custom is set.
            If($InstallerSwitchCustom)
            {
                # Add custom to cmdline
                $InstallerCmdLine = ("{0} {1}" -f $InstallerCmdLine, $InstallerSwitchCustom)
            }
        
            # Add to object array.
            $PackageInstallers += [PSCustomObject]@{
                Architecture = $InstallerArchitecture;
                InstallerFileName = $InstallerFileName;
                InstallerUrl = $InstallerUrl;
                InstallerType = $InstallerType;
                InstallerLocale = $InstallerLocale;
                InstallerCmdLine = $InstallerCmdLine;
                Scope = $Scope;
            };
        }
    }

    # If architecture is not set.
    If([string]::IsNullOrEmpty($Architecture))
    {
        # Write to log.
        Write-Log ("No architecture set, retrieving all");

        # Return installers.
        Return $PackageInstallers;   
    }
    # Else if architecture is set.
    ElseIf($PackageInstallers | Where-Object {$_.Architecture -eq $Architecture})
    {
        # Write to log.
        Write-Log ("Found matching architecture '{0}' for program" -f $Architecture);

        # Return installers.
        Return $PackageInstallers | Where-Object {$_.Architecture -eq $Architecture};
    }
    # No matching architecture found.
    Else
    {
        # Write to log.
        Write-Log ("Program architecture '{0}' is not found" -f $Architecture);

        # Foreach installer.
        Foreach($PackageInstaller in $PackageInstallers)
        {
            # Write to log.
            Write-Log ("Architecture '{0}' is available" -f $PackageInstaller.Architecture);
        }

        # Write to log.
        Write-Log ("Aborting" -f $Architecture);

        # Exit.
        Exit 1;
    }
}

# Exports package info to JSON.
Function Export-PackageInfo
{
    [cmdletbinding()]	
		
    Param
    (
        # Package.
        [Parameter(Mandatory=$true)]$Package,

        # Output file path.
        [Parameter(Mandatory=$false)][string]$FolderPath
    )

    # If export file path is not set.
    If([string]::IsNullOrEmpty($FolderPath))
    {
        # Construct file name.
        $FolderPath = ($env:TEMP);
    }

    # Construct file name.
    $FolderPath = ('{0}\{1}\{2}\{3}\{4}' -f $FolderPath, $Package.Publisher, $Package.Name, $Package.Installer.Architecture, $Package.Version);

    # Construct file path.
    $FilePath = ('{0}\{1}.json' -f $FolderPath, $Package.Installer.InstallerFileName);

    # Create folder.
    New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null;

    # Construct JSON for Intune upload.
    $Json = @{
        'displayName' = $Package.Name;
        'displayVersion' = $Package.Version;
        'description' = $Package.Description;
        'publisher' = $Package.Publisher;
        'privacyInformationUrl' = $Package.ProjectUrl;
        'informationUrl' = $Package.ProjectUrl;
        'owner' = $Package.Publisher;
        'developer' = $Package.Publisher;
        'installCommandLine' = $Package.Installer.InstallerCmdLine;
        'architecture' = $Package.Installer.Architecture;
        'scope' = $Package.Installer.Scope;
    } | ConvertTo-Json;

    # Export file.
    $Json | Out-File -FilePath $FilePath -Encoding utf8 -Force;

    # Write to log.
    Write-Log ("Exported package info to '{0}'" -f $FilePath);

    # Return file path.
    Return $FilePath;
}

# Download installation file.
Function Download-InstallFile
{
    [cmdletbinding()]	
		
    Param
    (
        # Package.
        [Parameter(Mandatory=$true)]$Package,

        # Output folder path.
        [Parameter(Mandatory=$false)][string]$FolderPath
    )

    # If export file path is not set.
    If([string]::IsNullOrEmpty($FolderPath))
    {
        # Construct file name.
        $FolderPath = ($env:TEMP);
    }

    # Construct file name.
    $FolderPath = ('{0}\{1}\{2}\{3}\{4}' -f $FolderPath, $Package.Publisher, $Package.Name, $Package.Installer.Architecture, $Package.Version);

    # Construct file path.
    $FilePath = ('{0}\{1}' -f $FolderPath, $Package.Installer.InstallerFileName);

    # Try to remove the file.
    Try
    {
        # If file already exist.
        If(Test-Path -Path $FilePath)
        {
            # Write to log.
            Write-Log ("Installation file '{0}' already exist, removing before download" -f $FilePath);
        
            # Remove file.
            Remove-Item -Path $FilePath -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null;
        }
    }
    # Something went wrong while removing file.
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while deleting file '{0}'" -f $FilePath);
    }
    
    # Get folder path from file path.
    $FolderPath = Split-Path -Path $FilePath

    # Create folder.
    New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null;

    # Add assembly.
    Add-Type -AssemblyName "System.Net" -IgnoreWarnings;

    # Write to log.
    Write-Log ("Downloading '{0}' with architecture '{1}', version '{2}' from '{3}' to '{4}', this might take a while" -f $Package.Name, $Package.Installer.Architecture, $Package.Version, $Package.Installer.InstallerUrl, $FilePath);

    # Create new object.
    $WebClient = New-Object System.Net.WebClient;

    # Download file.
    $WebClient.DownloadFile(
        ($Package.Installer.InstallerUrl),
        ($FilePath)
    );

    # Return file path.
    Return $FilePath;
}

# Download WinGet package installer and info.
Function Download-WinGetPackage
{
    [cmdletbinding()]	
		
    Param
    (
        # Package id.
        [Parameter(Mandatory=$false)][string]$PackageId = "Zoom.Zoom",

        # Architecture (x86 or x64).
        [Parameter(Mandatory=$false)][ValidateSet("x64", "x86")][string]$Architecture = "x64",

        # Version.
        [Parameter(Mandatory=$false)][string]$Version,

        # Folder path for output files.
        [Parameter(Mandatory=$false)][string]$OutputPath = ([Environment]::GetFolderPath("Desktop")),

        # GitHub API access token.
        [Parameter(Mandatory=$false)][string]$AccessToken
    )

    # Folder path for temporary manifest output.
    [string]$ManifestOutputPath = ('{0}\WinGet\Manifest\{1}\{2}' -f $env:TEMP, $PackageId, (New-Guid).Guid)

    # Set PowerShell to use TLS 1.2.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

    # If Nuget is not correct version.
    If(Get-PackageProvider -Name NuGet | Where-Object {$_.Version -lt 2.8.5.201})
    {
        # Install NuGet.
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -Confirm:$false | Out-Null;
    }

    # Install required PowerShell modules.
    Check-Module -Name powershell-yaml;

    # Get manifests.
    $WinGetManifests = Get-WinGetRepo -AccessToken $AccessToken;

    # Get package.
    $WinGetPackage = Get-WinGetPackage -WinGetManifests $WinGetManifests `
                                       -PackageId $PackageId `
                                       -Version $Version;

    # Get package manifests.
    $WinGetPackageManifest = Get-WinGetPackageManifest -WinGetManifests $WinGetManifests -Path $WinGetPackage.Path;

    # Download manifests files.
    Download-WinGetPackageManifest -WinGetManifests $WinGetPackageManifest -Path $ManifestOutputPath;

    # Load manifests.
    $Manifests = Load-WinGetPackageManifest -Path $ManifestOutputPath;

    # Get package details.
    $PackageDetails = Get-PackageDetails -Manifests $Manifests;

    # Get package installers.
    $PackageInstallers = Get-PackageInstallers -Manifests $Manifests -Architecture $Architecture;

    # New object.
    $Package = $PackageDetails;
    $Package | Add-Member -MemberType NoteProperty -Name "Installer" -Value ($PackageInstallers | Select-Object -First 1) -Force;

    # Export package info.
    $JsonTemplateFilePath = Export-PackageInfo -Package $Package -FolderPath $OutputPath;

    # Download install file.
    $InstallFilePath = Download-InstallFile -Package $Package -FolderPath $OutputPath;

    # Add to object.
    $Package | Add-Member -MemberType NoteProperty -Name "JsonTemplate" -Value ($JsonTemplateFilePath) -Force;
    $Package | Add-Member -MemberType NoteProperty -Name "InstallFilePath" -Value ($InstallFilePath) -Force;
    $Package | Add-Member -MemberType NoteProperty -Name "SourceDirectoryPath" -Value (Split-Path -Path $InstallFilePath) -Force;
    $Package | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value ('{0} ({1})' -f $Package.Name, $Package.Installer.Architecture) -Force;

    # Return package.
    Return $Package;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Download WinGet package installer and info.
Download-WinGetPackage -PackageId $PackageId `
                       -Architecture $Architecture `
                       -Version $Version `
                       -OutputPath $OutputPath `
                       -AccessToken $AccessToken;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion