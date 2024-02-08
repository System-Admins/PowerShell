#Requires -Version 5.1;
#Requires -Modules ExchangeOnlineManagement;

<#
.SYNOPSIS
  Get mailbox information from Exchange Online.

.DESCRIPTION
  This script will get mailbox information from Exchange Online such as size, archive enabled, permissions for send as, send of behalf and full access.

.Parameter Path
  (Optional) Path for the file that will be generated.
  Otherwise it will place the file on the desktop of the logged in user.

.Example
   .\Get-MailboxInformation.ps1 -Path "C:\temp\mailboxinfo.csv";

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  08-02-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

Param
(
  # Path for the output CSV file.
  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$Path
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

# If path is not specified.
if ([string]::IsNullOrEmpty($Path))
{
  # Set default path.
  $Path = ('{0}\{1}_mailboxinfo.csv' -f [Environment]::GetFolderPath('Desktop'), (Get-Date).ToString('yyyyMMdd'));
}

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

function Write-Log
{
  <#
    .SYNOPSIS
        Writes a message to a log file and optionally to the console.
    .DESCRIPTION
        Write error, warning, information or debug messages to a log file with some additional parameters.
    .PARAMETER Message
        Message to write to the log.
    .PARAMETER Path
        (Optional) Path to log file.
    .PARAMETER Level
        (Optional) Log level such as debug, information, error etc.
    .PARAMETER NoDateTime
        (Optional) If date and time should not be added to the log message.
    .PARAMETER NoAppend
        (Optional) If the log message should not be appended to the log file.
    .PARAMETER NoLogLevel
        (Optional) If the log level should not be logged.
    .PARAMETER NoConsole
        (Optional) If the log message should not be output to the console.
    .EXAMPLE
        # Write a information message to the console.
        Write-Log -Message 'This is an information message'
    .EXAMPLE
        # Write a debug message to a log file and console.
        Write-Log -Message 'This is an debug message' -Path 'C:\Temp\log.txt' -Level 'Debug'
    .EXAMPLE
        # Write a error message to a log file but not to the console.
        Write-Log -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level 'Error' -NoConsole
    .EXAMPLE
        # Write a information message to a log file but not to the console and do not append to the log file.
        Write-Log -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level 'Debug' -NoConsole -NoAppend
    #>
  [CmdletBinding()]
  Param
  (
    
    # Message to write to log.
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,

    # If category should be included.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$Category,
    
    # (Optional) Path to log file.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$Path,
        
    # (Optional) Log level.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('Error', 'Warning', 'Information', 'Debug')]
    [string]$Level = 'Information',
        
    # (Optional) If date and time should not be added to the log message.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch]$NoDateTime,

    # (Optional) If the log message should not be appended to the log file.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch]$NoAppend,

    # (Optional) If the log level should not be logged.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch]$NoLogLevel,

    # (Optional) If the log message should not be output to the console.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch]$NoConsole,

    # (Optional) If the log message should not be added to a file.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch]$NoLogFile
  )
    
  BEGIN
  {
    # Store original preferences.
    $originalInformationPreference = $InformationPreference;
    $originalWarningPreference = $WarningPreference;

    # Output to file.
    [bool]$outputToFile = $false;
  }
  PROCESS
  { 
    # If log file path is specified.
    if (!([string]::IsNullOrEmpty($Path)))
    {
      # If the message should saved to the log file.
      if ($false -eq $NoLogFile)
      {
        # Do not output to file.
        $outputToFile = $true;
      }
            
      # If log file dont exist.
      if (!(Test-Path -Path $Path -PathType Leaf))
      {
        # Get folder path.
        [string]$folderPath = Split-Path -Path $Path -Parent;

        # If folder path dont exist.
        if (!(Test-Path -Path $folderPath -PathType Container))
        {
          # Create folder path.
          New-Item -Path $folderPath -ItemType Directory -Force | Out-Null;
        }

        # Create log file.
        New-Item -Path $Path -ItemType File -Force | Out-Null;
      }
      # If log file exist.
      else
      {
        # If log file should not be appended.
        if ($true -eq $NoAppend)
        {
          # Clear log file.
          Clear-Content -Path $Path -Force | Out-Null;
        }
      }
    }        

    # Construct log message.
    [string]$logMessage = '';

    # If date and time should be added to log message.
    if ($false -eq $NoDateTime)
    {
      # Add date and time to log message.
      $logMessage += ('[{0}]' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'));
    }

    # If log level should be added to log message.
    if ($false -eq $NoLogLevel)
    {
      # Add log level to log message.
      $logMessage += ('[{0}]' -f $Level.ToUpper());
    }

    # If category should be added to log message.
    if ($false -eq [string]::IsNullOrEmpty($Category))
    {
      # Add category to log message.
      $logMessage += ('[{0}]' -f $Category);
    }

    # Add message to log message.
    $logMessage = ('{0} {1}' -f $logMessage, $Message);
  
    switch ($Level)
    {
      'Error'
      {
        Write-Error -Message $logMessage;
      }
      'Warning'
      {
        $WarningPreference = 'Continue';
        Write-Warning -Message $logMessage;
      }
      'Information'
      {
        $InformationPreference = 'Continue';
        Write-Information -MessageData $logMessage;
      }
      'Debug'
      {
        Write-Debug -Message $logMessage;
      }
    }

    # If output should be written to file.
    if ($true -eq $outputToFile)
    {
      # Construct splat parameters.
      $params = @{
        'Path'     = $Path;
        'Force'    = $true;
        'Encoding' = 'utf8';
      }

      # If log file should be appended.
      if ($false -eq $NoAppend)
      {
        # Add append parameter.
        $params.Add('Append', $true);
      }
            

      # Write log message to file.
      $logMessage | Out-File @params | Out-Null;
    }
  }
  END
  {
    # Restore original preferences.
    $InformationPreference = $originalInformationPreference;
    $WarningPreference = $originalWarningPreference;
  }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Try to connect to Exchange Online.
try
{
  # Write to log.
  Write-Log -Category 'Authentication' -Message 'Trying to connect Exchange Online' -Level 'Debug';

  # Connect to Exchange Online.
  #Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop;

  # Write to log.
  Write-Log -Category 'Authentication' -Message 'Successfully connected to Exchange Online' -Level 'Debug';
}
# Something went wrong connecting to Exchange Online.
catch
{
  # Throw execption.
  Write-Log -Category 'Authentication' -Message $_.Exception.Message -Level 'Error';
}

# Get organization information.
$organizationConfig = Get-OrganizationConfig;

# Write to log.
Write-Log -Category 'Mailbox' -Message ("Getting all Exchange Online mailboxes from tenant '{0}'" -f $organizationConfig.OrganizationalUnitRoot) -Level 'Debug';

# Get all mailboxes.
$mailboxes = Get-Mailbox -ResultSize Unlimited;

# Object array to store mailbox information.
$report = New-Object System.Collections.ArrayList;

# Mailbox counter.
[int]$mailboxCounter = 0;

# Foreach mailbox.
foreach ($mailbox in $mailboxes)
{
  # Write progress.
  Write-Progress -Activity 'Getting mailbox information' -Status ('Processing mailbox ({0}) {1} of {2}' -f $mailbox.UserPrincipalName, ++$mailboxCounter, $mailboxes.Count) -PercentComplete ($mailboxCounter / $mailboxes.Count * 100);

  # Variables.
  [bigint]$mailboxSizeInBytes = 0;
  [bigint]$archiveSizeInBytes = 0;
  [bool]$mailboxArchiveEnabled = $false;
  
  # Get recipient information.
  $recipient = Get-Recipient -Identity $mailbox.UserPrincipalName;

  # Write to log.
  Write-Log -Category $mailbox.UserPrincipalName -Message ('Getting mailbox statistics') -Level 'Debug';

  # Get mailbox statistics.
  $mailboxStatistics = Get-MailboxStatistics -Identity $mailbox.UserPrincipalName;

  # Get mailbox size in bytes.
  $mailboxSizeInBytes = ($mailboxStatistics.TotalItemSize.Value -replace '.*\(| bytes\).*|,');

  # If archive is enabled.
  if ($mailbox.ArchiveStatus -eq 'Active')
  {
    # Set archive enabled.
    $mailboxArchiveEnabled = $true;

    # Write to log.
    Write-Log -Category $mailbox.UserPrincipalName -Message ('Getting archive statistics') -Level 'Debug';

    # Get mailbox statistics.
    $archiveStatistics = Get-MailboxStatistics -Identity $mailbox.UserPrincipalName -Archive;

    # Get mailbox size in bytes.
    $archiveSizeInBytes = ($archiveStatistics.TotalItemSize.Value -replace '.*\(| bytes\).*|,');
  }

  # Write to log.
  Write-Log -Category $mailbox.UserPrincipalName -Message ('Getting full access permissions') -Level 'Debug';

  # Get mailbox permissions.
  $mailboxPermissions = Get-MailboxPermission -Identity $mailbox.UserPrincipalName | Where-Object { -not ($_.User -match 'NT AUTHORITY') -and ($_.IsInherited -eq $false) };

  # Get "full access" permissions.
  $mailboxFullAccess = ($mailboxPermissions | Where-Object { $_.AccessRights -eq 'FullAccess' }).User;

  # Write to log.
  Write-Log -Category $mailbox.UserPrincipalName -Message ('Getting send as permissions') -Level 'Debug';

  # Get recipient permissions.
  $recipientPermission = Get-RecipientPermission -Identity $mailbox.UserPrincipalName | Where-Object { -not ($_.Trustee -match 'NT AUTHORITY') -and ($_.IsInherited -eq $false) };

  # Get "send as" permissions.
  $mailboxSendAs = ($recipientPermission | Where-Object { $_.AccessRights -eq 'SendAs' }).Trustee;

  # Get "send on behalf" permissions.
  $mailboxSendOnBehalf = $mailbox.GrantSendOnBehalfTo;

  # Write to log.
  Write-Log -Category $mailbox.UserPrincipalName -Message ('Getting language configuration') -Level 'Debug';

  # Get mailbox language and region.
  $mailboxLanguage = Get-MailboxRegionalConfiguration -Identity $mailbox.UserPrincipalName;

  # Add mailbox information to report.
  $report += [PSCustomObject]@{
    'UserPrincipalName'                     = $mailbox.UserPrincipalName;
    'PrimarySmtpAddress'                    = $mailbox.PrimarySmtpAddress;
    'Alias'                                 = $mailbox.Alias;
    'LegacyExchangeDN'                      = $mailbox.LegacyExchangeDN;
    'FirstName'                             = $recipient.FirstName;
    'LastName'                              = $recipient.LastName;
    'DisplayName'                           = $mailbox.DisplayName;
    'UsageLocation'                         = $mailbox.UsageLocation;
    'Language'                              = $mailboxLanguage.Language;
    'Region'                                = $mailboxLanguage.Region;
    'DateFormat'                            = $mailboxLanguage.DateFormat;
    'TimeFormat'                            = $mailboxLanguage.TimeFormat;
    'TimeZone'                              = $mailboxLanguage.TimeZone;
    'DefaultFolderNameMatchingUserLanguage' = $mailboxLanguage.DefaultFolderNameMatchingUserLanguage;
    'MailboxSizeInGB'                       = $mailboxSizeInBytes / 1GB;
    'MailboxItems'                          = $mailboxStatistics.ItemCount;
    'ArchiveSizeInGB'                       = $archiveSizeInBytes / 1GB;
    'ArchiveItems'                          = $archiveStatistics.ItemCount;
    'ArchiveEnabled'                        = $mailboxArchiveEnabled;
    'FullAccess'                            = $mailboxFullAccess -join '|';
    'SendAs'                                = $mailboxSendAs -join '|';
    'SendOnBehalf'                          = $mailboxSendOnBehalf -join '|';
    'HiddenFromAddressListsEnabled'         = $mailbox.HiddenFromAddressListsEnabled;
    'EmailAddresses'                        = $mailbox.EmailAddresses -join '|';
    'RecipientTypeDetails'                  = $mailbox.RecipientTypeDetails;
    'IsDirSynced'                           = $mailbox.IsDirSynced;
  };
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Export CSV.
$report | Export-Csv -Path $Path -NoTypeInformation -Force -Encoding UTF8 -Delimiter ';';

############### Finalize - End ###############
#endregion
