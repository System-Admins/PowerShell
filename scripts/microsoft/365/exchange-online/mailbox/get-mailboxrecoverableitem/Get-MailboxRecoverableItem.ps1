#Requires -Version 5.1;
#Requires -Modules ExchangeOnlineManagement;

<#
.SYNOPSIS
  Get recoverable items from one or more mailboxes.

.DESCRIPTION
  This script retrieves recoverable items from one or more mailboxes in Exchange Online.
  It allows filtering based on a specified date range.

.PARAMETER Mailbox
  The mailbox(es) to retrieve recoverable items from.
  If not specified, all mailboxes in the organization will be used.
  Specify the UserPrincipalName(s) of the mailbox(es) to filter.

.PARAMETER FilterStartTime
  The start time for the filter. Default is 14 days ago.

.PARAMETER FilterEndTime
  The end time for the filter. Default is now.

.PARAMETER ExportFilePath
  The file path to export the results to.
  Default is the desktop with a timestamp.

.EXAMPLE
  # Get recoverable items from the last 14 days.
   .\Get-MailboxRecoverableItem.ps1;

.EXAMPLE
  # Get recoverable items from the last 30 days.
   .\Get-MailboxRecoverableItem.ps1 -FilterStartTime (Get-Date).AddDays(-30) -FilterEndTime (Get-Date).AddDays(-1) -ExportFilePath "C:\Temp\RecoverableItems.csv";

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  16-04-2025
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]
param
(
  # Mailbox to get recoverable items from.
  [Parameter(Mandatory = $false, Position = 0)]
  [string[]]$Mailbox,

  # Start time for the filter.
  [Parameter(Mandatory = $false, Position = 1)]
  [datetime]$FilterStartTime = (Get-Date).AddDays(-14),

  # End time for the filter.
  [Parameter(Mandatory = $false, Position = 2)]
  [datetime]$FilterEndTime = (Get-Date),

  # Export file path for results.
  [Parameter(Mandatory = $false, Position = 3)]
  [string]$ExportFilePath = ("{0}\Exchange-RecoverableItem-{1:yyyyMMdd-HHmmss}.csv" -f ([Environment]::GetFolderPath("Desktop")), (Get-Date))
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

# Write to log.
Write-Information -MessageData ('Script started - {0}' -f (Get-Date)) -InformationAction Continue;

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Information -MessageData ('Please login to Exchange Online with an Exchange administrator account (the prompt may be hidden)') -InformationAction Continue;

# Connect to Exchange Online.
$null = Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop;

# Get connection information.
$connectionInformation = Get-ConnectionInformation;

# Get user.
$user = Get-User -Identity $connectionInformation.UserPrincipalName -ErrorAction Stop;

# Mailbox import export role assignment.
$roleMailboxImportExportAssignments = Get-ManagementRoleAssignment -GetEffectiveUsers -Role 'Mailbox Import Export' -ErrorAction Stop;

# Get if the user has the role.
$roleMailboxImportExportAssignment = $roleMailboxImportExportAssignments | Where-Object { $_.EffectiveUsername -eq $user.Name };

# If the user does not have the role.
if ($null -eq $roleMailboxImportExportAssignment)
{
  # Write to log.
  Write-Warning -Message ("User '{0}' is missing role assignment 'Mailbox Import Export'" -f $connectionInformation.UserPrincipalName);
  Write-Warning -Message ('Run the following command, and then run the script again:' -f $connectionInformation.UserPrincipalName);
  Write-Warning -Message ('New-ManagementRoleAssignment –Role "Mailbox Import Export" –User "{0}"' -f $connectionInformation.UserPrincipalName);

  # Throw exception.
  throw ("User '{0}' dont have the Exchange Online management role 'Mailbox Import Export'" -f $connectionInformation.UserPrincipalName);
}

# Write to log.
Write-Information -MessageData ('Getting mailbox(es) in the organization, this might take a while') -InformationAction Continue;

# Get all mailboxes in the organization.
$exoMailboxes = Get-Mailbox -ResultSize Unlimited;

# Result.
$results = @();

# Foreach mailbox.
foreach ($exoMailbox in $exoMailboxes)
{
  # If mailboxes is specified.
  if ($Mailbox.Count -ne 0)
  {
    # If the mailbox is not in the list, skip it.
    if ($Mailbox -notcontains $exoMailbox.UserPrincipalName)
    {
      # Write to log.
      Write-Information -MessageData ('Getting mailbox(es) in the organization, this might take a while') -InformationAction Continue;

      # Continue to next mailbox.
      continue;
    }
  }

  # Variable to store recovery items.
  $recoveryItems = @();

  # Get recovery items for the mailbox (DeletedItems, RecoverableItems and PurgedItems).
  $recoveryItems += Get-RecoverableItems `
    -Identity $exoMailbox.Guid `
    -ResultSize Unlimited `
    -FilterStartTime $filterStartTime `
    -FilterEndTime $filterEndTime;

  # Get recovery items for the mailbox (DiscoveryHoldsItems).
  $recoveryItems += Get-RecoverableItems `
    -Identity $exoMailbox.Guid `
    -ResultSize Unlimited `
    -FilterStartTime $filterStartTime `
    -FilterEndTime $filterEndTime `
    -SourceFolder DiscoveryHoldsItems;

  # Write to log.
  Write-Information -MessageData ('[{0}] Mailbox total recovery item(s) is {1}' -f $exoMailbox.UserPrincipalName, $recoveryItems.Count) -InformationAction Continue;

  # Foreach recovery item.
  foreach ($recoveryItem in $recoveryItems)
  {
    # Create result object.
    $result = [PSCustomObject]@{
      MailboxIdentity              = $exoMailbox.Identity;
      MailboxPrimarySmtpAddress    = $exoMailbox.PrimarySmtpAddress;
      MailboxUserPrincipalName     = $exoMailbox.UserPrincipalName;
      MailboxAlias                 = $exoMailbox.Alias;
      MailboxDisplayName           = $exoMailbox.DisplayName;
      MailboxType                  = $exoMailbox.RecipientTypeDetails;
      MailboxRetentionPolicy       = $exoMailbox.RetentionPolicy;
      MailboxAuditEnabled          = $exoMailbox.AuditEnabled;
      MailboxLitigationHoldEnabled = $exoMailbox.LitigationHoldEnabled;
      MailboxRetentionHoldEnabled  = $exoMailbox.RetentionHoldEnabled;
      EntryID                      = $recoveryItem.EntryID;
      LastParentPath               = $recoveryItem.LastParentPath;
      LastParentFolderID           = $recoveryItem.LastParentFolderID;
      ItemClass                    = $recoveryItem.ItemClass;
      Subject                      = $recoveryItem.Subject;
      PolicyTag                    = $recoveryItem.PolicyTag;
      SourceFolder                 = $recoveryItem.SourceFolder;
      LastModifiedTime             = $recoveryItem.LastModifiedTime;
    };

    # Add to results.
    $results += $result;
  }
}

# Write to log.
Write-Information -MessageData ("Total recoverable item(s) for mailbox(es) is {0}" -f $results.Count) -InformationAction Continue;
Write-Information -MessageData ("Exporting results to '{0}'" -f $ExportFilePath) -InformationAction Continue;

# Export results to CSV.
$null = $results | Export-Csv `
  -Path $ExportFilePath `
  -NoTypeInformation `
  -Force `
  -Encoding UTF8;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Information -MessageData ('Script finished - {0}' -f (Get-Date)) -InformationAction Continue;

############### Finalize - End ###############
#endregion
