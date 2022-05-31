# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Must have the following modules installed.
#Requires -Module ExchangeOnlineManagement;

# Make sure that you have installed the following modules:
#Install-Module -Name ExchangeOnlineManagement -SkipPublisherCheck -Force -Scope CurrentUser;

<#
.SYNOPSIS
  Output all forward mailbox rules to an CSV file on the desktop.

.DESCRIPTION
  Get all mailboxes and run through each mailbox rule, then outputs the result to an CSV file on the desktop name "YearMonthDate_MailboxForwardRules.csv".

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  31-05-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Clear host.
#Clear-Host;

# Import module(s).
Import-Module -Name ExchangeOnlineManagement -Force -DisableNameChecking;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# CSV output file path.
$CsvFile = ("{0}\{1}_MailboxForwardRules.csv" -f ([Environment]::GetFolderPath("Desktop")), ((Get-Date).ToString("yyyyMMdd")));

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
        # Write to the console.
        Write-Host("");
    }
    Else
    {
        # Write to the console.
        Write-Host("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text);
    }
}

# Get mailbox forward rules.
Function Get-MailboxForwardRules
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$Mailbox
    )

    # Mailbox counter.
    $MailboxCount = $Mailbox.Count;
    $MailboxCounter = 1;

    # Write to log.
    Write-Log ("Found {0} mailboxes to enumerate" -f $MailboxCount);
  
    # Result object array.
    $Results = @();

    # Foreach mailbox.
    Foreach($Mailbox in $Mailboxes)
    {
        # Write to log.
        Write-Log ("Getting rules in '{0}' ({1}/{2})" -f $Mailbox.PrimarySmtpAddress, $MailboxCounter, $MailboxCount);

        # Get inbox rules.
        $InboxRules = Get-InboxRule -Mailbox $Mailbox.UserPrincipalName -IncludeHidden -BypassScopeCheck -WarningAction SilentlyContinue -ErrorAction SilentlyContinue;

        # Foreach inbox rule.
        Foreach($InboxRule in $InboxRules)
        {
            # If the inbox rule ForwardTo is set.
            If($InboxRule.ForwardTo -or $InboxRule.RedirectTo -or $InboxRule.ForwardAsAttachmentTo)
            {
                # Write to log.
                Write-Log ("Found mailbox ({0}) rule '{1}' is set to forward" -f $Mailbox.PrimarySmtpAddress, $InboxRule.Name);

                # Add to object array.
                $Results += [PSCustomObject]@{
                    Mailbox = $Mailbox.PrimarySmtpAddress;
                    Name = $InboxRule.Name;
                    RuleId = $InboxRule.RuleIdentity;
                    Enabled = $InboxRule.Enabled;
                    ForwardTo = $InboxRule.ForwardTo -join "|";
                    RedirectTo = $InboxRule.RedirectTo -join "|";
                    ForwardAsAttachmentTo = $InboxRule.ForwardAsAttachmentTo -join "|";
                };
            }
        }

        # Add to counter.
        $MailboxCounter++;
    }

    # Return results.
    Return $Results;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log ("Connecting to Exchange Online");

# Connect to Exchange Online.
Connect-ExchangeOnline -ShowBanner:$false;

# Write to log.
Write-Log ("Getting all mailboxes");

# Get all mailboxes.
$Mailboxes = Get-Mailbox -ResultSize Unlimited;

# Get mailbox forward rules.
$ForwardRules = Get-MailboxForwardRules -Mailbox $Mailboxes;

# Export to CSV.
$ForwardRules | Export-Csv -Path $CsvFile -Encoding UTF8 -Delimiter ";" -NoTypeInformation -Force;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion