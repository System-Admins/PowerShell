# Get all room mailboxes.
$RoomMailboxes = Get-Mailbox -RecipientTypeDetails RoomMailbox;

# Foreach mailbox.
Foreach($RoomMailbox in $RoomMailboxes)
{
    # Set default permission.
    Set-MailboxFolderPermission -Identity ('{0}:\Calendar' -f $RoomMailbox.PrimarySmtpAddress) -User Default -AccessRights LimitedDetails;
}

# Get all room mailboxes.
$EquipmentMailboxes = Get-Mailbox -RecipientTypeDetails EquipmentMailbox;

# Foreach mailbox.
Foreach($EquipmentMailbox in $EquipmentMailboxes)
{
    # Set default permission.
    Set-MailboxFolderPermission -Identity ('{0}:\Calendar' -f $EquipmentMailbox.PrimarySmtpAddress) -User Default -AccessRights LimitedDetails;
} 