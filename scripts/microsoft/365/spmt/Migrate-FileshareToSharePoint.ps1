# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Require SPMT module.
#Requires -Module Microsoft.SharePoint.MigrationTool.PowerShell;

<#
.SYNOPSIS
  .

.DESCRIPTION
  .

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  06-10-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]	
		
Param
(
    [Parameter(Mandatory=$false)][string]$FileShareSource = 'C:\Temp',
    [Parameter(Mandatory=$false)][string]$TargetSiteUrl = 'https://contoso.sharepoint.com/sites/MySharePointSite',
    [Parameter(Mandatory=$false)][string]$TargetList = "Documents",
    [Parameter(Mandatory=$false)][string]$TargetListRelativePath = "Test",
    [Parameter(Mandatory=$false)][string]$Username = "myuser@contoso.onmicrosoft.com",
    [Parameter(Mandatory=$false)][string]$Password = "MySecretPasswordHere"
)

# Clear host.
#Clear-Host;

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

# Creates a PS credential object.
Function New-PSCredential
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$Username,
        [Parameter(Mandatory=$true)]$Password
    )
 
    # Convert the password to a secure string.
    $SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force;
 
    # Convert $Username and $SecurePassword to a credential object.
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username,$SecurePassword;
 
    # Return the credential object.
    Return $Credential;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Remove all registered sessions (if any).
Unregister-SPMTMigration -ErrorAction SilentlyContinue;

# Write to log.
Write-Log ("Starting to copy files from '{0}' to '{1}' (with user '{2}')" -f $FileShareSource, $TargetSiteUrl, $Username);

# Create SPO credentials.
$SpoCredential = New-PSCredential -Username $Username -Password $Password;

# Register the SPMT session with SPO credentials.
Register-SPMTMigration -SPOCredential $SpoCredential -DuplicatePageBehavior SKIP -Force;

# Create parameters.
$SpmtTaskParameters = @{
    FileShareSource = $FileShareSource;
    TargetSiteUrl = $TargetSiteUrl;
    TargetList = $TargetList;
};

# If relative path is set.
If(!([string]::IsNullOrEmpty($TargetListRelativePath)))
{
    # Add to parameters.
    $SpmtTaskParameters.Add("TargetListRelativePath", $TargetListRelativePath);

    # Write to log.
    Write-Log ("Will use relative list path '{0}'" -f $TargetListRelativePath);
}

# Add migration task.
Add-SPMTTask @SpmtTaskParameters;

# Start migration.
Start-SPMTMigration;

# Write to log.
Write-Log ("Finished copying files from '{0}' to '{1}'" -f $FileShareSource, $TargetSiteUrl);

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion