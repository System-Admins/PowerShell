# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Modules.
#Requires -Module ActiveDirectory;

<#
.SYNOPSIS
  Get mailbox details in on-premise Exchange. Creates an CSV on the desktop of the logged-in user.

.DESCRIPTION
  Get last sent/recieved, mailbox size, enabled, last logon/logoff, database and much more.
  Run this script on the Exchange server.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  15-06-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Import script.
. ('{0}bin\RemoteExchange.ps1' -f $env:ExchangeInstallPath) | Out-Null;

# Import Active Directory module.
Import-Module -Name "ActiveDirectory" -Force -DisableNameChecking;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Output path for CSV.
$ReportFilePath = ("{0}\MailboxUsageReport.csv" -f [Environment]::GetFolderPath("Desktop"));

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
        Write-Output("");
    }
    Else
    {
        # Write to the console.
        Write-Output("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text);
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log ("Connecting to Exchange");

# Connect to Exchange server.
Connect-ExchangeServer -auto -ClientApplication:ManagementShell -AllowClobber:$true | Out-Null;

# Write to log.
Write-Log ("Getting all Active Directory users");

# Get all Active Directory users.
$AdUsers = Get-ADUser -Filter * -Properties LastLogonTimestamp;

# Write to log.
Write-Log ("Found {0} Active Directory users" -f $AdUsers.Count);
Write-Log ("Getting all Exchange mailboxes");

# Get all mailboxes.
$Mailboxes = Get-Mailbox -ResultSize Unlimited -WarningAction SilentlyContinue;

# Get number of mailboxes and set counter.
$MailboxesCount = $Mailboxes.Count;
$MailboxCounter = 1;

# Write to log.
Write-Log ("Found {0} mailboxes" -f $MailboxesCount);
Write-Log ("Getting sent and received logs, this may take some time");

# Get all sent and received messages.
$ReceivedMessages = Get-MailboxServer -ErrorAction SilentlyContinue | Get-MessageTrackingLog -EventId RECEIVE -Source SMTP -ResultSize Unlimited;
$SentMessages = Get-MailboxServer -ErrorAction SilentlyContinue | Get-MessageTrackingLog -EventId send -Source SMTP -ResultSize Unlimited;

# Write to log.
Write-Log ("Preparing report file '{0}'" -f $ReportFilePath);

# Delete CSV file.
Remove-Item -Path $ReportFilePath -Force -ErrorAction SilentlyContinue | Out-Null;

# Report object.
$Results = @();

# Foreach mailbox.
Foreach($Mailbox in $Mailboxes)
{
    # Write to log.
    Write-Log ("{0} ({1}/{2})" -f $Mailbox.UserPrincipalName, $MailboxCounter, $MailboxesCount);

    # Get AD object.
    $AdUser = $AdUsers | Where-Object {$_.UserPrincipalName -eq $Mailbox.UserPrincipalName};

    # Get mailbox statistics.
    $MailboxStatistics = $Mailbox | Get-MailboxStatistics;

    # Get mailbox size.
    If($MailboxStatistics.TotalItemSize)
    {
        # Get mailbox size in MB.
        [int]$TotalMailboxSize = $MailboxStatistics.TotalItemSize.Value.ToMB();
    }
    # No mailbox size.
    Else
    {
        # Empty.
        [int]$TotalMailboxSize = 0;
    }

    # Get mailbox size.
    If($MailboxStatistics.TotalDeletedItemSize)
    {
        # Get mailbox size in MB.
        [int]$TotalMailboxDeletedItemSize = $MailboxStatistics.TotalDeletedItemSize.Value.ToMB();
    }
    # No mailbox size.
    Else
    {
        # Empty.
        [int]$TotalMailboxDeletedItemSize = 0;
    }

    # Get received messages for mailbox.
    If($ReceivedMessage = $ReceivedMessages | Where-Object {$_.Recipients -contains $Mailbox.PrimarySmtpAddress})
    {
        # Get latest received message.
        $LastReceivedMessage = $ReceivedMessage | Sort-Object Timestamp -Descending | Select-Object -ExpandProperty Timestamp -First 1;
    }
    # No info.
    Else
    {
        # Set to empty.
        [string]$LastReceivedMessage = "";
    }

    # Get sent messages for mailbox.
    If($SentMessage = $SentMessages | Where-Object {$_.Sender -contains $Mailbox.PrimarySmtpAddress})
    {
        # Get latest received message.
        $LastSentMessage = $SentMessage | Sort-Object Timestamp -Descending | Select-Object -ExpandProperty  Timestamp -First 1;
    }
    # No info.
    Else
    {
        # Set to empty.
        [string]$LastSentMessage = "";
    }

    # If AD last logon.
    If($AdUser.LastLogonTimestamp)
    {
        # Convert to datetime.
        $AdLastLogon = [DateTime]::FromFileTime($AdUser.LastLogonTimestamp);
    }
    # No login info.
    Else
    {
        # Convert to datetime.
        [string]$AdLastLogon = "";
    }
    
    # Create object.
    $Result = [PSCustomObject]@{
        UserPrincipalName = $Mailbox.UserPrincipalName;
        PrimarySmtpAddress = $Mailbox.PrimarySmtpAddress;
        DisplayName = $Mailbox.DisplayName;
        MailboxType = $Mailbox.RecipientTypeDetails;
        ActiveDirectoryEnabled = $AdUser.Enabled;
        ActiveDirectoryLastLogon = $AdLastLogon;
        ActiveDirectoryOu = [regex]::match($AdUser.DistinguishedName,'(?=OU)(.*\n?)(?<=.)').Value;
        ExchangeLastLogon = $MailboxStatistics.LastLogonTime;
        ExchangeLastLogoff = $MailboxStatistics.LastLogoffTime;
        TotalMailboxSize = $TotalMailboxSize;
        TotalMailboxDeletedItemSize = $TotalMailboxDeletedItemSize;
        LastReceivedMessage = $LastReceivedMessage;
        LastSentMessage = $LastSentMessage;
        Database = $Mailbox.Database.Name;
    };

    # Export to CSV.
    $Result | Export-Csv -Path $ReportFilePath -Encoding UTF8 -Delimiter ";" -NoTypeInformation -Confirm:$false -Force -Append;

    # Add to object array.
    $Results += $Result;

    # Add to counter.
    $MailboxCounter++;
}

# Write to log.
Write-Log ("Report is available at '{0}'" -f $ReportFilePath);

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion
