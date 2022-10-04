#requires -version 5.1

<#
.SYNOPSIS
  Gets software icon from package id otherwise.

.DESCRIPTION
  Uses wininstall.app repository of logos otherwise grabs favicon from project website.

.Parameter PackageId
  The package id of the software from WinGet.

.Parameter ProjectUrl
  (Optional) The software project URL.

.Parameter OutputPath
  (Optional) Destination folder for the image file. When this parameter is not set, it will save it to "SoftwareLogo" under the TEMP directory.

.Example
   .\Get-SoftwareLogo.ps1 -PackageId "7Zip.7Zip" -ProjectUrl "https://www.7-zip.org/" -OutputPath "C:\MyLogos";

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
    # Package Id.
    [Parameter(Mandatory=$true)][string]$PackageId,

    # Project Url.
    [Parameter(Mandatory=$false)][string]$ProjectUrl,

    # Output path for the logo file.
    [Parameter(Mandatory=$false)][string]$OutputPath = ("{0}\SoftwareLogo" -f $env:TEMP)
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

# Download image.
Function Download-Image
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Url = 'https://api.winstall.app/icons/Typora.Typoora.png',
        [Parameter(Mandatory=$false)][string]$FolderPath = 'C:\Users\xalth\OneDrive - PensionDanmark\Skrivebord\Repositories\Microsoft 365\powershell\endpoint-manager\automate-win32app',
        [Parameter(Mandatory=$false)][string]$FileName = 'icon.png'
    )

    # If output path doesnt exist.
    If(!(Test-Path -Path $FolderPath))
    {
        # Write to log.
        Write-Log ("Creating folder '{0}'" -f $FolderPath);

        # Create folder.
        New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null;
    }

    # File full name.
    $FullName = ("{0}\{1}" -f $FolderPath, $FileName);

    # Try to download image.
    Try
    {
        # Write to log.
        Write-Log ("Trying to download from '{0}' to file '{1}'" -f $Url, $FullName);

        # Temp file path
        $TempFilePath = ("{0}\{1}.png" -f $env:TEMP, (New-Guid).Guid);

        # Download image.
        Invoke-WebRequest -Uri $Url -Method Get -OutFile $TempFilePath -ErrorAction Stop;

        # If file exist.
        If(Test-Path -Path $FullName)
        {
            # Write to log.
            Write-Log ("Removing existing file '{0}'" -f $FullName);

            # Remove file.
            Remove-Item -Path $FullName -Force | Out-Null;
        }

        # Move file.
        Move-Item -Path $TempFilePath -Destination $FullName -Force -Confirm:$false;

        # Write to log.
        Write-Log ("Downloaded file to '{0}'" -f $FullName);

        # Return full path of file.
        Return $FullName;
    }
    # Something went wrong.
    Catch
    {
        # Get response code.
        $ResponseCode = $Error[0].Exception.Response.StatusCode;

        # Write to log.
        Write-Log ("Something went wrong while downloading from '{0}', the website returned '{1}'" -f $Url, $ResponseCode);

        # Return false.
        Return $false;
    }
}

# Get software logo.
Function Get-SoftwareLogo
{
    [cmdletbinding()]	
		
    Param
    (
        # Package Id.
        [Parameter(Mandatory=$true)][string]$PackageId,

        # Project Url.
        [Parameter(Mandatory=$false)][string]$ProjectUrl,

        # Output path for the logo file.
        [Parameter(Mandatory=$true)][string]$OutputPath = $env:TEMP
    )

    # URI.
    $PrimaryUri = 'https://api.winstall.app/icons/{0}.png' -f $PackageId;

    # If download image is not OK.
    If(!($File = Download-Image -Url $PrimaryUri -FolderPath $OutputPath -FileName "icon.png"))
    {
        # If project URL is set.
        If(!([string]::IsNullOrEmpty($ProjectUrl)))
        {
            # Get domain of project url.
            $Domain = ([System.Uri]$ProjectUrl).Host;

            # ICO service.
            $AlternativeUri = 'https://icon.horse/icon/{0}' -f $Domain;

            # Write to log.
            Write-Log ("Using alternative source '{0}'" -f $AlternativeUri);

            # If download image from project url is not OK.
            If(!($File = Download-Image -Url $AlternativeUri -FolderPath $OutputPath -FileName "icon.png"))
            {
                # Throw error.
                Throw("Primary and alternative download sources is not available, aborting.");

                # Exit script.
                Exit 1;
            }
            # Else download is OK.
            Else
            {
                # Return file name.
                Return $File;
            }   
        }
        Else
        {
            # Throw error.
            Throw("Primary download sources is not available, aborting.");

            # Exit script.
            Exit 1;
        }
    }
    # Else download is OK.
    Else
    {
        # Return file name.
        Return $File;
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get software logo.
$SoftwareLogoPath = Get-SoftwareLogo -PackageId $PackageId -ProjectUrl $ProjectUrl -OutputPath $OutputPath;

# Return path.
Return $SoftwareLogoPath;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
