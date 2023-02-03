# Must be running PowerShell version 5.1.
#Requires -Version 5.1;
#Requires -Module Az.Resources;
#Requires -Module Az.RedisCache;

<#
.SYNOPSIS
  Reset Azure Redis Cache.

.DESCRIPTION
  The script requires the PowerShell modules "Az.Resources" and "Az.RedisCache".

  1. Download the redis-cli port created by "tporadowski" for Windows and extract the executable(s).
  2. Connects to the Azure Redis Cache to get hostname, port and access key.
  3. Uses redis-cli.exe to clear the cache.
  3. Restore the original value of the SSL requirement.

.EXAMPLE
  .\Clear-AzureRedisCache.ps1 -Name "<Azure Redis Cache resource name>";

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  03-02-2023
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
[cmdletbinding()]
param
(
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9-]{1,63}$')][string]$Name
)

# Import module(s).
Import-Module -Name Az.RedisCache -Force;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Redis CLI for Windows.
$RedisCliConfig = @{
    GitHubProfile    = 'tporadowski';
    GitHubRepository = 'redis';
    GitHubFileName   = 'Redis-x64*.zip';
    InstallationPath = ("{0}\{1}" -f $env:TEMP, (New-Guid).Guid);
    Executable       = 'redis-cli.exe';
};

############### Input - End ###############
#endregion

#region begin functions
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
        Write-Host("");
    }
    else
    {
        # Write to log.
        Write-Host("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text);
    }
}

# Download latest release from GitHub repository.
function Get-GitHubRepositoryRelease
{
    # Parameters.
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Profile,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Repository,
        [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()][string]$FileName = "*.zip",
        [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()][string]$Path = ("{0}\{1}" -f $env:TEMP, (New-Guid).Guid)
    )
    
    # Construct release URI.
    $ReleasesUri = ("https://api.github.com/repos/{0}/{1}/releases/latest" -f $Profile, $Repository);

    # Write to log.
    Write-Log ("Getting latest release from repository '{0}'" -f $ReleasesUri);

    # Get download URL.
    $DownloadUrl = ((Invoke-RestMethod -Method GET -UseBasicParsing -Uri $ReleasesUri).assets | Where-Object name -Like $FileName).browser_download_url | Select-Object -First 1;

    # If download url isnt empty.
    if ($null -ne $DownloadUrl)
    {
        # Create path.
        New-Item -Path $Path -ItemType Directory -Force | Out-Null;

        # Construct download path.
        $DownloadPath = Join-Path -Path $Path -ChildPath (Split-Path -Path $DownloadUrl -Leaf);

        # Try to download file.
        try
        {
            # Write to log.
            Write-Log ("Downloading release from file '{0}' to path '{1}'" -f $DownloadUrl, $DownloadPath);

            # Start download.
            Invoke-WebRequest -Uri $DownloadUrl -Out $DownloadPath -ErrorAction Stop;

            # Return path.
            Return $DownloadPath;
        }
        catch
        {
            # Write to log.
            Write-Log ($_);
            
            # Throw exception.
            throw ("Something went wrong while downloading release from file '{0}' to path '{1}'" -f $DownloadUrl, $DownloadPath);
        }
    }
    # Else file cant be find.
    else
    {
        throw ("Cant find release for '{0}'" -f $ReleasesUri);
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log ("Script started at '{0}'" -f (Get-Date));

# Get Azure resource.
$AzResource = Get-AzResource -ResourceType 'Microsoft.Cache/Redis' -Name $Name;

# If resource is not found.
if ($null -eq $AzResource)
{
    # Throw exception.
    throw ("Azure Redis Cache '{0}' is not found under the current Azure context" -f $Name);
}
else
{
    # Write to log.
    Write-Log ("Found Azure Redis Cache '{0}' in resource group '{1}'" -f $AzResource.Name, $AzResource.ResourceGroupName);
}

# Download redis cli for Windows from GitHub repository.
$RedisCliZipFile = Get-GitHubRepositoryRelease -Profile $RedisCliConfig.GitHubProfile `
    -Repository $RedisCliConfig.GitHubRepository `
    -FileName $RedisCliConfig.GitHubFileName;

# Write to log.
Write-Log ("Expanding '{0}' to '{1}'" -f $RedisCliZipFile, $RedisCliConfig.InstallationPath);

# Expand downloaded ZIP file from GitHub.
Expand-Archive -Path $RedisCliZipFile -DestinationPath $RedisCliConfig.InstallationPath -Force | Out-Null;

# Get full executable path.
$RedisCliExe = ("{0}\{1}" -f $RedisCliConfig.InstallationPath, $RedisCliConfig.Executable);

# If the executable exist.
if (Test-Path -Path $RedisCliExe -PathType Leaf)
{
    # Get version.
    $RedisCliVersion = (Get-Item -Path $RedisCliExe -Force).VersionInfo.ProductVersion;

    # Write to log.
    Write-Log ("Redis CLI '{0}' version is '{1}'" -f $RedisCliExe, $RedisCliVersion);
}
else
{
    # Throw exception.
    throw ("Redis CLI executable dont exist at path '{0}'" -f $RedisCliExe);
}


# Get Azure Redis Cache object.
$AzRedisCache = Get-AzRedisCache -ResourceGroupName $AzResource.ResourceGroupName -Name $AzResource.Name;

# Get current value of require SSL value.
New-Variable -Name OriginalEnableNonSslPort -Value $AzRedisCache.EnableNonSslPort -Option ReadOnly -ErrorAction SilentlyContinue;

# If require SSL is enabled.
if ($false -eq $AzRedisCache.EnableNonSslPort)
{
    # Write to log.
    Write-Log ("Disabling SSL-only connection for Azure Redis Cache '{0}'" -f $AzRedisCache.Name);

    # Disable SSL-only connections.
    Set-AzRedisCache -ResourceGroupName $AzRedisCache.ResourceGroupName -Name $AzRedisCache.Name -EnableNonSslPort $true -ErrorAction Stop | Out-Null;
}

# Get host name, port and access key for Azure Redis Cache.
$Hostname = $AzRedisCache.HostName;
$NonSslPort = $AzRedisCache.Port;
$PrimaryAccessKey = (Get-AzRedisCacheKey -ResourceGroupName $AzRedisCache.ResourceGroupName -Name $AzRedisCache.Name -ErrorAction Stop).PrimaryKey;
$RedisCliArguments = ("-h {0} -p {1} -a {2} flushall" -f $Hostname, $NonSslPort, $PrimaryAccessKey);

# Connect to Redis Cache and clear the cache.
$RedisCliResult = Start-Process -FilePath $RedisCliExe -ArgumentList $RedisCliArguments -PassThru -Wait -NoNewWindow;

# If exit code is OK.
if ($RedisCliResult.ExitCode -eq 0)
{
    # Write to log.
    Write-Log ("Sucessfully cleared cache on '{0}'" -f $AzRedisCache.Name);
}
# Something went wrong with clearing the cache.
else
{
    # Write to log.
    Write-Log ("Could not clear the cache on '{0}'" -f $AzRedisCache.Name);
}

# Write to log.
Write-Log ("Setting value for SSL-only connection for Azure Redis Cache '{0}' back to '{1}'" -f $AzRedisCache.Name, $OriginalEnableNonSslPort);

# Set the original value for "EnableNonSSLPort".
Set-AzRedisCache -ResourceGroupName $AzRedisCache.ResourceGroupName -Name $AzRedisCache.Name -EnableNonSslPort $OriginalEnableNonSslPort | Out-Null;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Log ("Script finished at '{0}'" -f (Get-Date));

############### Finalize - End ###############
#endregion
