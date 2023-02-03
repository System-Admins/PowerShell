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
    Write-Host ("Getting latest release from repository '{0}'" -f $ReleasesUri);

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
            Write-Host ("Downloading release from file '{0}' to path '{1}'" -f $DownloadUrl, $DownloadPath);

            # Start download.
            Invoke-WebRequest -Uri $DownloadUrl -Out $DownloadPath -ErrorAction Stop;

            # Return path.
            Return $DownloadPath;
        }
        catch
        {
            # Write to log.
            Write-Host ($_);
            
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

# Download latest release.
Get-GitHubRepositoryRelease -Profile 'tporadowski' -Repository 'redis' -FileName 'Redis-x64*.zip';
