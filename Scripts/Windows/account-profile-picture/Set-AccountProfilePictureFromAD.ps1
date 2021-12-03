#requires -version 3
<#
.SYNOPSIS
  Sets profile picture from Active Directory into the user profile account in Windows.

.DESCRIPTION
  Checks if the domain controller can be reached. If there is a thumbnail it downloads and install on the local user profile in Windows.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  17-11-2021
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Clear the screen.
#Clear-Host;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Organization name.
$OrganizationName = "System Admins";

# Transcript.
$TranscriptFolder = ("{0}\AppData\Local\{1}\UserProfilePicture\Logs" -f $env:USERPROFILE, $OrganizationName);

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Write to the console.
Function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Category,
        [Parameter(Mandatory=$false)][string]$Text
    )
 
    #If the input is empty.
    If([string]::IsNullOrEmpty($Text))
    {
        $Text = " ";
    }
 
    #If category is not present.
    If([string]::IsNullOrEmpty($Category))
    {
        #Write to the console.
        Write-Output("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text + ".");
    }
    Else
    {
        #Write to the console.
        Write-Output("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "][" + $Category + "]: " + $Text + ".");
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Create new log folder.
New-Item -Path $TranscriptFolder -ItemType Directory -Force | Out-Null;

# Get logon server.
$DomainController = (Resolve-DnsName -Name ($env:LOGONSERVER -replace "\\")).Name;

# Start transcript.
Start-Transcript -Path ("{0}\ProfilePicture-{1}.log" -f $TranscriptFolder, (Get-Date).ToString("dd-MM-yyyy_HH-mm-ss")) | Out-Null;

# Write to log.
Write-Log -Category ("Script") -Text ("Started");

# Test connection to domain controller.
If((Test-ComputerSecureChannel -Confirm:$false -Server $DomainController))
{
    # Set variables.
    $SamAccountName = $env:username;
    $ImageSizes = @(32, 40, 48, 96, 192, 200, 240, 448);

    # Write to log.
    Write-Log -Category ("Domain Controller") -Text ("There is a valid connection");
    Write-Log -Category ($SamAccountName) -Text ("Getting Active Directory user object attributes");

    # Get user data.
    $User = @{
        Attributes = ([ADSISearcher]"(&(objectCategory=User)(SAMAccountName=$SamAccountName))").FindOne().Properties;
        SID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value;
    };

    # If there is a photo.
    If($User.Attributes.thumbnailphoto)
    {
        # Write to log.
        Write-Log -Category ($SamAccountName) -Text ("User have a profile picture in Active Directory");

        # Set registry path for user.
        $RegistryKey = ("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\{0}" -f $User.SID);

        # If the registry key dont exist.
        If(!(Test-Path -Path $RegistryKey))
        {
            # Write to log.
            Write-Log -Category ($SamAccountName) -Text ("Creating registry key '{0}'" -f $RegistryKey);

            # Create registry key.
            New-Item -Path $RegistryKey -Force | Out-Null;
        }

        # Set image path.
        $ImageFolderPath = ("C:\Users\Public\AccountPictures\{0}" -f $User.SID);

        # If the folder path dont exist.
        If(!(Test-Path -Path $ImageFolderPath))
        {
            # Write to log.
            Write-Log -Category ($SamAccountName) -Text ("Creating folder '{0}'" -f $ImageFolderPath);

            # Create folder.
            New-Item -Path $ImageFolderPath -ItemType Directory -Force | Out-Null;
        }

        # Write to log.
        Write-Log -Category ($SamAccountName) -Text ("Hiding folder '{0}'" -f $ImageFolderPath);

        # Hide folder.
        (Get-Item -Path $ImageFolderPath -Force).Attributes = "Hidden";

        # Foreach image size.
        Foreach($ImageSize in $ImageSizes)
        {
            # Set image file name.
            $ImageFileName = ('{0}\Image{1}.jpg' -f $ImageFolderPath, $ImageSize);

            # Write to log.
            Write-Log -Category ($SamAccountName) -Text ("Saving profile picture to '{0}'" -f $ImageFileName);

            # Save photo from AD in a file.
            $User.Attributes.thumbnailphoto | Set-Content -Path $ImageFileName -Encoding Byte -Force;

            # Write to log.
            Write-Log -Category ($SamAccountName) -Text ("Setting registry key '{0}' with '{1}'" -f $RegistryKey, $ImageFileName);

            # Set registry key.
            New-ItemProperty -Path $RegistryKey -Name ("Image{0}" -f $ImageSize) -Value $ImageFileName -Force | Out-Null;
        }
    }
    Else
    {
        # Write to log.
        Write-Log -Category ($SamAccountName) -Text ("User do not have a profile picture in Active Directory");
    }
}
Else
{
    # Write to log.
    Write-Log -Category ("Domain Controller") -Text ("There is no valid connection to the domain controllers");
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Log -Category ("Script") -Text ("Stopped");

# Stop transcript
Stop-Transcript | Out-Null;

############### Finalize - End ###############
#endregion
