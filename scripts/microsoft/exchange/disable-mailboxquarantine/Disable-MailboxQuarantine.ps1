# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

<#
.SYNOPSIS
  Run through all mailboxes and disable quarantine in Exchange (on-premises)
  Need to be run from one of the Exchange servers.

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

# Disable all mailbox quarantine.
Function Disable-MailboxQuarantine
{
    # Write to log.
    Write-Log ("Importing Exchange cmdlets");
    
    # Import Exchange cmdlets.
    . ('{0}\bin\RemoteExchange.ps1' -f $env:ExchangeInstallPath) | Out-Null;

    # Write to log.
    Write-Log ("Connecting to Exchange");

    # Connect to the Exchange Server.
    Connect-ExchangeServer -auto -ClientApplication:ManagementShell | Out-Null;

    # Write to log.
    Write-Log ("Getting all mailboxes, this might take a while");

    # Get all mailboxes.
    $Mailboxes = Get-Mailbox -ResultSize Unlimited;

    # Foreach mailbox.
    Foreach($Mailbox in $Mailboxes)
    {
        # Get mailbox statistics.
        $MailboxStatistics = Get-MailboxStatistics -Identity $Mailbox.SamAccountName -IncludeQuarantineDetails -WarningAction SilentlyContinue -ErrorAction SilentlyContinue;

        # If IsQuarantined is true.
        If($MailboxStatistics.IsQuarantined -eq $true)
        {
            # Write to log.
            Write-Log ("{0}: Mailbox is in quarantine, disabling now" -f $Mailbox.PrimarySmtpAddress);

            # Disable mailbox quarantine.
            Disable-MailboxQuarantine –Identity $Mailbox.Alias -Confirm:$false;
        }
        # Else is not in qurantine.
        Else
        {
            # Write to log.
            Write-Log ("{0}: Mailbox is NOT in quarantine, skipping" -f $Mailbox.PrimarySmtpAddress);
        }
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Disable all mailbox quarantine.
Disable-MailboxQuarantine;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion
