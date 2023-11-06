# Object array to store mailboxes.
$mailboxTypes = @('RoomMailbox', 'EquipmentMailbox', 'UserMailbox', 'SharedMailbox');

# Access rights.
$accessRights = @("LimitedDetails");

# Get all mailboxes.
$mailboxes = Get-Mailbox -RecipientTypeDetails $MailboxTypes -ResultSize Unlimited;

# Foreach mailbox.
foreach ($mailbox in $mailboxes)
{
    # Try to get calendar folder.
    try
    {
        # Get calendar folder.
        $calendarFolder = Get-MailboxFolderStatistics -Identity $mailbox.Alias -FolderScope Calendar | Where-Object { $_.FolderType -eq 'Calendar' };
    }
    # Not calendar folder.
    catch
    {
        # Continue to next mailbox.
        continue;
    }
    
    # Write to log.
    Write-Host ("[{0}] Setting '{1}' on the calendar folder '{2}'" -f $mailbox.PrimarySmtpAddress, ($accessRights -join "|"), $calendarFolder.Name)

    # Set default permission.
    Set-MailboxFolderPermission -Identity ('{0}:\{1}' -f $mailbox.PrimarySmtpAddress, $calendarFolder.Name) -User Default -AccessRights $accessRights | Out-Null;
}
