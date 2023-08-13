#requires -version 5.1

<#
.SYNOPSIS
  Remove meetings from a mailbox based on a search query.

.DESCRIPTION
  Run through each mailbox in Exchange and remove meetings matching the search query.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  13-08-2023
  Purpose/Change: Initial script development

.EXAMPLE
  # Remove meetings sent from at specific e-mail.
  .\Remove-ExchangeMeetings.ps1 -ExchServer "myexchangeserver.contoso.com" -ExchUsername "myUsername" -ExchPassword "mySecretPassword123" -FromEmail "user1@example.com";

.EXAMPLE
  # Remove meetings sent with a specific subject.
  .\Remove-ExchangeMeetings.ps1 -ExchServer "myexchangeserver.contoso.com" -ExchUsername "myUsername" -ExchPassword "mySecretPassword123" -Subject "The Meeting Subject Name";

.EXAMPLE
  # Remove meetings sent from at specific e-mail and subject.
  .\Remove-ExchangeMeetings.ps1 -ExchServer "myexchangeserver.contoso.com" -ExchUsername "myUsername" -ExchPassword "mySecretPassword123"  -FromEmail "user1@example.com" -Subject "The Meeting Subject Name";
#>

#region begin boostrap
############### Bootstrap - Start ###############

Param
(
    # Admin credentials for Exchange.
    [Parameter(Mandatory = $true)][string]$ExchServer,
    [Parameter(Mandatory = $true)][string]$ExchUsername,
    [Parameter(Mandatory = $true)][string]$ExchPassword,

    # Which mailbox to delete meetings from.
    [Parameter(Mandatory = $false)][string]$FromEmail,

    # If only delete meetings with a specific subject.
    [Parameter(Mandatory = $false)][string]$Subject

)

# Clear the screen.
#Clear-Host;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Exchange configuration.
$ExchangeConfiguration = @{
    ComputerName = $ExchServer;
    UserName     = $ExchUsername;
    Password     = $ExchPassword;
};

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Connect to Exchange PowerShell.
Function Connect-Exchange
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory = $true)][PSCredential]$Credential,
        [Parameter(Mandatory = $true)][string]$ComputerName
    )

    # Connect to remote computer.
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ComputerName/PowerShell/" -Authentication Kerberos -Credential $Credential;

    # Import session.
    Import-PSSession $Session -DisableNameChecking -AllowClobber | Out-Null;
}

# Creates a PS credential object.
Function New-PSCredential
{
    [cmdletbinding()]   
                         
    Param
    (
        [Parameter(Mandatory = $true)]$Username,
        [Parameter(Mandatory = $true)]$Password
    )

    # Convert the password to a secure string.
    $SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force;

    # Convert $Username and $SecurePassword to a credential object.
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePassword;

    # Return the credential object.
    Return $Credential;
}

# Log function.
Function Write-Log
{
    [cmdletbinding()]   
                         
    Param
    (
        [Parameter(Mandatory = $false)][string]$Text
    )

    #If the input is empty.
    If ([string]::IsNullOrEmpty($Text))
    {
        $Text = " ";
    }

    #Write to the console.
    Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# If required parameters is not specified.
if ([string]::IsNullOrEmpty($FromEmail) -and [string]::IsNullOrEmpty($Subject))
{
    # Throw execption.
    throw ("You must either provide the '-FromEmail <email address of meeting organizer>' or '-Subject <subject of meeting>' parameter for the script to run");
}

# Write to log.
Write-Log -Text ('Script started');

# Create AD credentials.
$ExchangeCrendetial = (New-PSCredential -Username $ExchangeConfiguration.UserName -Password $ExchangeConfiguration.Password);

# Write to log.
Write-Log -Text ('Connecting to Exchange on "{0}"' -f $ExchangeConfiguration.ComputerName);

# Connect to Exchange.
Connect-Exchange -Credential $ExchangeCrendetial -ComputerName $ExchangeConfiguration.ComputerName;

# Create search string.
$SearchQuery = ('kind:meetings');

# If a from mailbox is specified.
if (!([string]::IsNullOrEmpty($FromEmail)))
{
    # Write to log.
    Write-Log -Text ('Will search after meetings from "{0}"' -f $FromEmail);
    
    # Add from to search.
    $SearchQuery = $SearchQuery + (" from:{0}" -f $FromEmail);
}

# If a subject is specified.
if (!([string]::IsNullOrEmpty($Subject)))
{
    # Write to log.
    Write-Log -Text ('Will search after meetings with subject "{0}"' -f $Subject);

    # Add subject to search.
    $SearchQuery = $SearchQuery + (' subject:"{0}"' -f $Subject);
}

# Write to log.
Write-Log -Text ('Getting all mailboxes, this might take a few seconds');

# Get all mailboxes.
$Mailboxes = Get-Mailbox -ResultSize Unlimited -IgnoreDefaultScope:$true -WarningAction SilentlyContinue;

# Foreach exchange mailbox.
foreach ($Mailbox in $Mailboxes)
{
    # Write to log.
    Write-Log -Text ("Searching after meetings in the mailbox '{0}' with the query '{1}'" -f $Mailbox.PrimarySmtpAddress, $SearchQuery);

    # Search the mailbox.
    Search-Mailbox -Identity $Mailbox.PrimarySmtpAddress -SearchQuery $SearchQuery -SearchDumpsterOnly:$false -DeleteContent -Force;
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Log -Text ('Script stopped');

############### Finalize - End ###############
#endregion 
