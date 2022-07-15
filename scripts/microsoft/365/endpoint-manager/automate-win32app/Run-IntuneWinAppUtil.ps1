#requires -version 5.1

<#
.SYNOPSIS
  Download latest version of the Microsoft Win32 Content Prep Tool and create an IntuneWin file based on input.

.DESCRIPTION
  Download latest version of the Microsoft Win32 Content Prep Tool and create an IntuneWin file based on input.

.Parameter SourcePath
  The source directory of the containing the setup file for the software.

.Parameter SetupFile
  The setup file name in the source directory, usally this is an .MSI or .EXE file.

.Parameter OutputPath
  Destination folder for the IntuneWin file. When this parameter is not set, it will create in the source directory.

.Example
   .\Run-IntuneWinAppUtil.ps1 -SourcePath "C:\Path\To\My\Installation\Directory" -SetupFile "setup.exe";

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  14-07-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]

Param
(
    # Source directory of the installation software binaries.
    [Parameter(Mandatory=$true)][string]$SourcePath,

    # Setup file in the source directory.
    [Parameter(Mandatory=$true)][string]$SetupFile,

    # Output path for the intunewin file.
    [Parameter(Mandatory=$false)][string]$OutputPath = $SourcePath
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

# Download IntuneWin content prep tool from GitHub.
Function Download-IntuneWin
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$OutputPath = ("{0}\IntuneWinAppUtil" -f $env:Temp)
    )

    # Construct extract folder path.
    $ExtractPath = ('{0}\IntuneWinAppUtil' -f $env:TEMP);

    # Construct ZIP file path.
    $ZipFilePath = ('{0}\IntuneWinAppUtil.zip' -f $ExtractPath);

    # Write to log.
    Write-Log ("Creating folder '{0}'" -f $ExtractPath);

    # Create folder.
    New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null;

    # Write to log.
    Write-Log ("Removing all files in '{0}' (just in case)" -f $ExtractPath);

    # Delete all existing files.
    Remove-Item -Path ('{0}\*' -f $ExtractPath) -Force -Confirm:$false -ErrorAction SilentlyContinue -Recurse | Out-Null;
    
    # Download URL.
    $Url = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/heads/master.zip";

    # Add assembly.
    Add-Type -AssemblyName "System.Net" -IgnoreWarnings;

    # Write to log.
    Write-Log ("Downloading Microsoft Win32 Content Prep Tool from '{0}'" -f $Url);

    # Create new object.
    $WebClient = New-Object System.Net.WebClient;

    # Download file.
    $WebClient.DownloadFile(
        ($Url),
        ($ZipFilePath)
    );

    # Write to log.
    Write-Log ("Expanding '{0}' archive to '{1}'" -f $ZipFilePath, $ExtractPath);

    # Extract folder.
    Expand-Archive -Path $ZipFilePath -DestinationPath $ExtractPath -Force;

    # Get executable only.
    $Executable = Get-ChildItem -Path $ExtractPath -Filter "*.exe" -Force -Recurse;

    # Write to log.
    Write-Log ("Creating folder '{0}'" -f $OutputPath);

    # Create folder.
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null;

    # Write to log.
    Write-Log ("Copying '{0}' to '{1}'" -f $Executable.FullName, $OutputPath);

    # Copy executable to output path.
    Copy-Item -Path $Executable.FullName -Destination $OutputPath -Force;

    # Get tool.
    $Tool = Get-Item -Path ("{0}\{1}" -f $OutputPath, $Executable.Name);

    # Return path.
    Return $Tool.FullName;
}

# Invoke the content prep tool.
Function Invoke-ContentPrepTool
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$ToolPath,
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [Parameter(Mandatory=$true)][string]$SetupFile,
        [Parameter(Mandatory=$true)][string]$OutputPath
    )

    # Get intunewin file.
    $IntuneWinFiles = Get-ChildItem -Path $OutputPath -Filter "*.intunewin" -Force;

    # Foreach file.
    Foreach($IntuneWinFile in $IntuneWinFiles)
    {
        # Write to log.
        Write-Log ("Removing existing IntuneWin file '{0}'" -f $IntuneWinFile.FullName);

        # Remove file.
        Remove-Item -Path $IntuneWinFile.FullName -Force -Confirm:$false;
    }

    # Write to log.
    Write-Log ("Executing tool from '{0}'" -f $ToolPath);
    Write-Log ("Taken source directory from '{0}'" -f $SourcePath);
    Write-Log ("Setup file is '{0}'" -f $SetupFile);
    Write-Log ("Output path is '{0}'" -f $OutputPath);

    # Invoke tool.
    Start-Process -FilePath $ToolPath -ArgumentList ('-c "{0}" -s "{1}" -o "{2}" -q' -f $SourcePath, $SetupFile, $OutputPath) -Wait -NoNewWindow -RedirectStandardOutput ".\NUL";

    # Get intunewin file.
    $IntuneWinFile = Get-ChildItem -Path $OutputPath -Filter "*.intunewin" -Force -Recurse | Select-Object -First 1;

    # Write to log.
    Write-Log ("Finished running tool, file created '{0}'" -f $IntuneWinFile.FullName);

    # Return path.
    Return $IntuneWinFile.FullName;
}

# Run the content prep tool.
Function Run-IntuneWinAppUtil
{
    [cmdletbinding()]	
		
    Param
    (
        # Source directory of the installation software binaries.
        [Parameter(Mandatory=$true)][string]$SourcePath,

        # Setup file in the source directory.
        [Parameter(Mandatory=$true)][string]$SetupFile,

        # Output path for the intunewin file.
        [Parameter(Mandatory=$true)][string]$OutputPath
    )

    # Download and extract the content prep tool for IntuneWin
    $ToolPath = Download-IntuneWin;

    # Wrap install directory with the content prep tool.
    $IntuneWinFilePath = Invoke-ContentPrepTool -ToolPath $ToolPath -SourcePath $SourcePath -SetupFile $SetupFile -OutputPath $OutputPath;

    # Return file path for intunewin file.
    Return $IntuneWinFilePath;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Run the content prep tool.
Run-IntuneWinAppUtil -SourcePath $SourcePath -SetupFile $SetupFile -OutputPath $OutputPath;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion