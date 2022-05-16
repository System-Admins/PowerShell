#requires -version 3

<#
.SYNOPSIS
  Get all mailbox rule that forwards and creates an CSV on the desktop.

.DESCRIPTION
  Loops through each mailbox and get mailbox rules and adds them to a list if the rule are forwarding.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  20-04-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Clear the screen.
#Clear-Host;

Param
(
    [string]$ExchUsername,
    [string]$ExchPassword,
    [string]$ExchServer
)

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Exchange configuration.
$ExchangeConfiguration = @{
    ComputerName = $ExchServer;
    UserName = $ExchUsername;
    Password = $ExchPassword;
};

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Connect to Exchange PowerShell.
Function Connect-Exchange
{
    Param
    (
        [Parameter(Mandatory=$true)][PSCredential]$Credential,
        [Parameter(Mandatory=$true)][string]$ComputerName
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

# Log function.
Function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Text
    )
 
    #If the input is empty.
    If([string]::IsNullOrEmpty($Text))
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

# Write to log.
Write-Log -Text ('Script started');

# Create AD credentials.
$ExchangeCrendetial = (New-PSCredential -Username $ExchangeConfiguration.UserName -Password $ExchangeConfiguration.Password);

# Write to log.
Write-Log -Text ('Connecting to Exchange on "{0}"' -f $ExchangeConfiguration.ComputerName);

# Connect to Exchange.
Connect-Exchange -Credential $ExchangeCrendetial -ComputerName $ExchangeConfiguration.ComputerName;

# Write to log.
Write-Log -Text ('Getting all mailboxes');
$ExchangeMailboxes = Get-Mailbox -ResultSize Unlimited -WarningAction SilentlyContinue;

# Get number of mailboxes.
$ExchangeMailboxesCount = $ExchangeMailboxes.Count

# Write to log.
Write-Log -Text ('Found {0} mailboxes' -f $ExchangeMailboxesCount);

# Set loop counter.
$Counter = 0;

# Object array.
$ForwardRules = @();

# Foreach mailbox.
Foreach($ExchangeMailbox in $ExchangeMailboxes)
{
    # Add to counter.
    $Counter++;

    # Write to log.
    Write-Log -Text ("{0}/{1}: {2}" -f $Counter, $ExchangeMailboxesCount, $ExchangeMailbox.PrimarySmtpAddress);

    # Get mailbox rules.
    $MailboxRules = Get-InboxRule -Mailbox $ExchangeMailbox.PrimarySmtpAddress -BypassScopeCheck -WarningAction SilentlyContinue;

    # Write to log.
    Write-Log -Text ('Found {0} mailbox rules' -f $MailboxRules.Count);

    # Foreach mailbox rule.
    Foreach($MailboxRule in $MailboxRules)
    {
        # If the rule (enabled) is set to forward to. 
        If($MailboxRule.ForwardTo -and $MailboxRule.Enabled)
        {
            # Write to log.
            Write-Log -Text ('Rule "{0}" is forwarding to {1}' -f $MailboxRule.Name, $MailboxRule.ForwardTo);

            # Add to object array.
            $ForwardRules += [PSCustomObject]@{
                "primarySmtpAddress" = $ExchangeMailbox.PrimarySmtpAddress;
                "alias" = $ExchangeMailbox.Alias;
                "displayName" = $ExchangeMailbox.DisplayName;
                "ruleName" = $MailboxRule.Name;
                "forwardTo" = $MailboxRule.ForwardTo;
            };
        }
    }

    # Write to log.
    Write-Host "";
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Export to CSV.
$ForwardRules | Export-Csv -Path ("{0}\MailboxForwardRules.csv" -f [Environment]::GetFolderPath("Desktop")) -Encoding UTF8 -Delimiter ";" -NoTypeInformation -Force;

# Write to log.
Write-Log -Text ('Script stopped');

############### Finalize - End ###############
#endregion
