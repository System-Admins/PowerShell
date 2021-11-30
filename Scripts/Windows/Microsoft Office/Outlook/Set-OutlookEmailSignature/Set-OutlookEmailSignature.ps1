#requires -version 3

<#
.SYNOPSIS
  Sets Microsoft Outlook email signature with information from Azure AD.

.DESCRIPTION
  Connects to Azure AD with logged in credential and get user information.
  Takes the HTML files in the template folder and replaces the info from Azure AD.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  30-11-2021
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

#Clear the screen.
Clear-Host;

# If script running in PowerSHell ISE.
If($psise)
{
    # Set script path.
    $ScriptPath = Split-Path $psise.CurrentFile.FullPath;
}
# Normal PowerShell session.
Else
{
    # Set script path.
    $ScriptPath = $global:PSScriptRoot;
}

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Organization info.
$Organization = @{
    Name = "System Admins";
};

# Transcript.
$LogFolder = ("{0}\{1}\Signatures\Log" -f $env:APPDATA, $Organization.Name);
$LogFile = ("{0}_signature.log" -f (Get-Date).ToString("yyyyMMdd"));

# Organization info.
$Template = @{
    NewHtml = ("{0}\template\New.htm" -f $ScriptPath);
    NewImages = ("{0}\template\images" -f $ScriptPath);
    ReplyHtml = ("{0}\template\Reply.htm" -f $ScriptPath);
    ReplyImages = ("{0}\template\images" -f $ScriptPath);
};

# Path to signatures.
$SignatureDirectoryPath = ("{0}\Microsoft\Signatures" -f $env:APPDATA);

# New signature.
$SignatureNewName = ("{0} - New" -f $Organization.Name);
$SignatureNewFile = ("{0}\{1}.htm" -f $SignatureDirectoryPath, $SignatureNewName);
$SignatureNewImageDirectory = ("{0}\{1}_files" -f $SignatureDirectoryPath, $SignatureNewName);

# Reply signature.
$SignatureReplyName = ("{0} - Reply" -f $Organization.Name);
$SignatureReplyFile = ("{0}\{1}.htm" -f $SignatureDirectoryPath, $SignatureReplyName);
$SignatureReplyImageDirectory = ("{0}\{1}_files" -f $SignatureDirectoryPath, $SignatureReplyName);

# Path to Outlook profile.
$OutlookRegistryPath = 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles';

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
        [Parameter(Mandatory=$false)][string]$Text
    )
 
    # If text is not present.
    If([string]::IsNullOrEmpty($Text))
    {
        #Write to the console.
        Write-Host("");
    }
    # Otherwise output time/date format.
    Else
    {
        #Write to the console.
        Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text + ".");
    }
}

# Get registry outlook profile path.
Function Get-OutlookProfiles
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory=$true)][string]$Path
    )

    # Get Outlook profiles names.
    $OutlookDefaultProfiles = (Get-ChildItem -Path $Path).PSChildName;

    # More than one profile.
    If($OutlookDefaultProfiles -eq $null -or $OutlookDefaultProfiles.Count -ne 1)
    {
        # Set profile path.
        $OutlookProfilePath = 'HKCU:\Software\Microsoft\Office\16.0\Common\MailSettings';
    }
    # Default profile.
    Else
    {
        # Set default profile path.
        $OutlookProfilePath = ("HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles\{0}\9375CFF0413111d3B88A00104B2A6676\00000002" -f $OutlookDefaultProfiles);
    }

    # Write to log.
    Write-Log ("Outlook profile path is '{0}'" -f $OutlookProfilePath);

    # Return path.
    Return $OutlookProfilePath;
}

# Check internet connection.
Function Check-InternetConnectivity
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$ComputerName = "8.8.8.8"
    )

    # Check connection.
    If(Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)
    {
        # Write to log.
        Write-Log ("Internet connection is OK");

        # OK.
        Return $true;
    }
    Else
    {
        # Write to log.
        Write-Log ("No internet connection");

        # No internet connection.
        Return $false;
    }
}

# Loads a file and replaces content from a hash table.
Function Replace-Content
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][hashtable]$ReplaceTable
    )

    # Write to log.
    Write-Log ("Getting content from '{0}'" -f $Path);

    # Get content.
    $Content = Get-Content -Path $Path -Encoding UTF8 -Force;

    # Write to log.
    Write-Log ("Replacing values in the new signature");
    
    # Foreach line in the content.
    Foreach($Line in $Content)
    {
        # Foreach value in the replace table.
        Foreach($Replace in $ReplaceTable.GetEnumerator())
        {
            # Replace data.
            $Content = $Content -replace [Regex]::Escape($Replace.Name), $Replace.Value;
        }
    }

    # Return content.
    Return $Content;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Create log folder.
New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null;

# Start transcript.
Start-Transcript -Path ($LogFolder + "\" + $LogFile) -Append -Force;

# Test connection to the internet.
If(Check-InternetConnectivity)
{
    # Write to log.
    Write-Log ("Installing Azure AD PowerShell module");

    # Install Azure AD module in current user scope.
    Install-Module -Name "AzureAD" -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force -Confirm:$false -WarningAction SilentlyContinue;

    # Write to log.
    Write-Log ("Importing Azure AD PowerShell module");

    # Import module.
    Import-Module -Name "AzureAD" -Force -DisableNameChecking;

    # Check if module is imported.
    If($Module = Get-Module -Name "AzureAD")
    {
        # Get current user UPN.
        $UPN = whoami /upn;

        # Connect to Azure AD with logged in credentials.
        Connect-AzureAD -Confirm:$false -AccountId $UPN | Out-Null;

        # Get Azure AD info.
        If($AzureADUser = Get-AzureADUser -ObjectId $UPN)
        {
            # Write to log.
            Write-Log ("Fetched user information for {0}" -f $UPN);
            
            # New signature replace table.
            $SignatureNewReplace = @{
                '%%displayname%%' = $AzureADUser.DisplayName;
                '%%title%%' = $AzureADUser.JobTitle;
                '%%phonenumber%%' = $AzureADUser.TelephoneNumber;
                '%%mobilephone%%' = $AzureADUser.Mobile;
                '%%email%%' = $AzureADUser.Mail;
                '[ImageDirectory]' = ("{0}_files" -f $SignatureNewName);
            };

            # Reply signature replace table.
            $SignatureReplyReplace = @{
                '%%displayname%%' = $AzureADUser.DisplayName;
                '%%title%%' = $AzureADUser.JobTitle;
                '%%mobilephone%%' = $AzureADUser.Mobile;
                '%%email%%' = $AzureADUser.Mail;
                '[ImageDirectory]' = ("{0}_files" -f $SignatureReplyName);
            };

            # Get Outlook profile registry path.
            $OutlookProfilePath = Get-OutlookProfiles -Path $OutlookRegistryPath;

            # Create signatures from template.
            $HtmlNew = Replace-Content -Path $Template.NewHtml -ReplaceTable $SignatureNewReplace;
            $HtmlReply = Replace-Content -Path $Template.ReplyHtml -ReplaceTable $SignatureReplyReplace;

            # Write to log.
            Write-Log ("Removing image directory '{0}'" -f $SignatureNewImageDirectory);
            Write-Log ("Removing signature file '{0}'" -f $SignatureNewFile);

            # Delete existing signature.
            Remove-Item -Path $SignatureNewImageDirectory -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue;
            Remove-Item -Path $SignatureNewFile -Force -Confirm:$false -ErrorAction SilentlyContinue;

            # Write to log.
            Write-Log ("Creating folder '{0}'" -f $SignatureNewImageDirectory);
            Write-Log ("Creating folder '{0}'" -f $SignatureReplyImageDirectory);

            # Create new folders.
            New-Item -Path $SignatureNewImageDirectory -ItemType Directory -Force | Out-Null;
            New-Item -Path $SignatureReplyImageDirectory -ItemType Directory -Force | Out-Null;

            # Write to log.
            Write-Log ("Copying files from '{0}' to '{1}'" -f $Template.NewImages, $SignatureNewImageDirectory);
            Write-Log ("Copying files from '{0}' to '{1}'" -f $Template.ReplyImages, $SignatureReplyImageDirectory);

            # Copy template to the signature folder.
            $HtmlNew | Out-File -FilePath $SignatureNewFile -Encoding utf8 -Force -Confirm:$false;
            $HtmlReply | Out-File -FilePath $SignatureReplyFile -Encoding utf8 -Force -Confirm:$false;

            # Write to log.
            Write-Log ("Setting new & reply as default for the Outlook profile");

            # Set as default signature.
            Get-Item -Path $OutlookProfilePath | New-Itemproperty -Name "New Signature" -value $SignatureNewName -Propertytype string -Force | Out-Null;
            Get-Item -Path $OutlookProfilePath | New-Itemproperty -Name "Reply-Forward Signature" -value $SignatureReplyName -Propertytype string -Force | Out-Null;

            # Exit with success.
            Exit 0;
        }
        Else
        {
            # Write to log.
            Write-Log ("Cant get user information for {0}" -f $UPN);

            # Exit with error.
            Exit 1;
        }
    }
    # Cant import AzureAD module.
    Else
    {
        # Write to log.
        Write-Log ("Cant import Azure AD PowerShell module");

        # Exit with error.
        Exit 1;
    }
}
# No internet connection.
Else
{
    # Exit with error.
    Exit 1;
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Stop transcript.
Stop-Transcript;

############### Finalize - End ###############
#endregion