# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

<#
.SYNOPSIS
  Download GitHub repository to local filesystem without the Git client.

.DESCRIPTION
  This script downloads GitHub repository to the local filesystem.

.EXAMPLE
  .\Download-GitHubRepository.ps1 -GitHubUrl "https://github.com/system-admins/PowerShell" -Branch "main"

.EXAMPLE
  .\Download-GitHubRepository.ps1 -GitHubUrl "https://github.com/system-admins/PowerShell" -Branch "main" -OutputFolderPath "C:\My\Repo\Location\Folder"

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  20-10-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
[cmdletbinding()]

Param
(
    # GitHub URL "https://github.com/<author>/<repository>".
    [Parameter(Mandatory=$true)][string]$GitHubUrl,

    # Output folder path.
    [Parameter(Mandatory=$false)][string]$OutputFolderPath = ("{0}\github\{1}" -f $env:TEMP, (New-Guid).ToString()),

    # Git Branch.
    [Parameter(Mandatory=$true)][string]$Branch = 'master',

    # Download path for ZIP file.
    [Parameter(Mandatory=$false)][string]$DownloadFilePath = ("{0}\{1}.zip" -f $env:TEMP, (New-Guid).ToString())
)

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
  
    # If text is not present.
    If([string]::IsNullOrEmpty($Text))
    {
        # Write to log.
        Write-Host("");
    }
    Else
    {
        # Write to log.
        Write-Host("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text);
    }
}

# Download public repository from GitHub.
Function Download-GitHubRepository
{
    [cmdletbinding()]

    Param
    (
        # GitHub URL https://github.com/<author>/<repository>.
        [Parameter(Mandatory=$true)][string]$GitHubUrl,

        # Output folder path.
        [Parameter(Mandatory=$false)][string]$OutputFolderPath = ("{0}\github\{1}" -f $env:TEMP, (New-Guid).ToString()),

        # Git Branch.
        [Parameter(Mandatory=$true)][string]$Branch = 'master',

        # Download path for ZIP file.
        [Parameter(Mandatory=$false)][string]$DownloadFilePath = ("{0}\{1}.zip" -f $env:TEMP, (New-Guid).ToString())
    )

    # Write to log.
    Write-Log ("Script started");

    # Construct download url.
    $GitHubRepoUrl = ('{0}/archive/refs/heads/{1}.zip' -f $GitHubUrl, $Branch);

    # If download file exist.
    If(Test-Path -Path $DownloadFilePath -PathType Leaf)
    {
        # Write to log.
        Write-Log ("Removing existing file '{0}'" -f $DownloadFilePath);

        # Remove file.
        Remove-Item -Path $DownloadFilePath -Force;
    }

    # Try to download.
    Try
    {
        # Write to log.
        Write-Log ("Downloading repo from '{0}' (branch '{1}') to '{2}', this might take some time" -f $GitHubRepoUrl, $Branch, $DownloadFilePath);

        # Download repo.
        Invoke-RestMethod -Uri $GitHubRepoUrl -OutFile $DownloadFilePath -Method Get -ErrorAction Stop;
    }
    # Something went wrong.
    Catch
    {
        # Throw exception.
        Throw("Download from '{0}' failed, aborting" -f $GitHubRepoUrl);
    }

    # If download file dont exist.
    If(!(Test-Path -Path $DownloadFilePath -PathType Leaf))
    {
        # Throw exception.
        Throw("File '{0}' dont exist, aborting" -f $DownloadFilePath);
    }

    # If output folder exist.
    If(Test-Path -Path $OutputFolderPath -PathType Container)
    {
        # Write to log.
        Write-Log ("Removing existing output folder '{0}'" -f $OutputFolderPath);

        # Remove folder.
        Remove-Item -Path $OutputFolderPath -Recurse -Force;
    }

    # Write to log.
    Write-Log ("Creating output folder '{0}'" -f $OutputFolderPath);

    # Create output folder path.
    New-Item -Path $OutputFolderPath -ItemType Directory -Force -Confirm:$false | Out-Null;

    # Write to log.
    Write-Log ("Expanding archive '{0}' to '{1}', this might take some time" -f $DownloadFilePath, $OutputFolderPath);

    # Expand archive file to output folder.
    Expand-Archive -Path $DownloadFilePath -DestinationPath $OutputFolderPath -Force;

    # Get top level folder.
    $RootFolder = Get-ChildItem -Path $OutputFolderPath;

    # Move all folders and files inside root folder to output folder path.
    Move-Item -Path ("{0}\*" -f $RootFolder.FullName) -Destination $OutputFolderPath;

    # Remove root folder.
    Remove-Item -Path $RootFolder.FullName -Recurse -Force;

    # Remove zip file.
    Remove-Item -Path $DownloadFilePath -Force;

    # Write to log.
    Write-Log ("Script stopped");

    # Return output folder path.
    Return $OutputFolderPath;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Download public repository from GitHub.
Download-GitHubRepository -GitHubUrl $GitHubUrl -OutputFolderPath $OutputFolderPath -Branch $Branch -DownloadFilePath $DownloadFilePath;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
