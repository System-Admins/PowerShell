#Requires -Version 5.1;
#Requires -Module ExchangeOnlineManagement;

<#
.SYNOPSIS
  Generates an CSV file with information about all distribution groups in Exchange Online.

.DESCRIPTION
  Returns members, owners and some other vital information about all distribution groups in Exchange Online.
  Requires the Exchange Online PowerShell module.
  To install the module run the following command:
  Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser;

.Parameter Path
  Path for the CSV that will be generated.
  This parameter is optional and will default to the desktop.

.Example
   .\Get-DistributionGroupInformation.ps1 -Path "C:\Path\To\My\Csv\DistributionGroups.csv";

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  02-02-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

Param
(
    # Path to the CSV file that will be generated.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path = ('{0}\{1}_{2}' -f ([Environment]::GetFolderPath('Desktop')), (Get-Date).ToString('yyyyMMdd'), 'DistributionGroups.csv')
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

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
        Write-Log -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level 'Information' -NoConsole -NoAppend
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

# Object array to store results.
$report = New-Object System.Collections.ArrayList;

# Try to connect to Exchange Online.
try
{
    # Write to log.
    Write-Log -Message ('Trying to connect to Exchange Online') -Level 'Information';

    # Connect to Exchange Online.
    #Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop | Out-Null;

    # Write to log.
    Write-Log -Message ('Successfully connected to Exchange Online') -Level 'Information';
}
# Something went wrong while connecting to Exchange Online.
catch
{
    # Throw execption.
    Write-Log -Message ('Failed to connect to Exchange Online') -Level 'Error';
}

# Get all distribution groups.
$distributionGroups = Get-DistributionGroup -ResultSize Unlimited;

# Foreach distribution group.
foreach ($distributionGroup in $distributionGroups)
{
    # List of member with primary smtp address.
    $membersPrimarySmtpAddresses = New-Object System.Collections.ArrayList;
    $ownersPrimarySmtpAddresses = New-Object System.Collections.ArrayList;

    # Bool to check if external senders are allowed.
    [bool]$allowExternalSenders = $false;

    # Get all members of the distribution group.
    $distributionGroupMembers = Get-DistributionGroupMember -Identity $distributionGroup.PrimarySmtpAddress -ResultSize Unlimited;

    # Foreach member of the distribution group.
    foreach ($distributionGroupMember in $distributionGroupMembers)
    {
        # Email address of the member.
        [string]$emailAddress = '';

        # If the member is a user.
        if ($distributionGroupMember.RecipientTypeDetails -eq 'User')
        {
            # Get the email address of the user.
            $emailAddress = $distributionGroupMember.WindowsLiveID;
        }
        # Else use primary smtp address.
        else
        {
            # Get the email address of the mail contact.
            $emailAddress = $distributionGroupMember.PrimarySmtpAddress;
        }

        # Write to log.
        Write-Log -Category ($distributionGroup.PrimarySmtpAddress) -Message ("'{0}' is a member" -f $emailAddress) -Level 'Information';
    
        # Add primary smtp address to list.
        $membersPrimarySmtpAddresses.Add($emailAddress) | Out-Null;
    }

    # Foreach owner.
    foreach ($distributionGroupOwner in $distributionGroup.ManagedBy)
    {
        # if managed by is empty.
        if ([string]::IsNullOrEmpty($distributionGroupOwner))
        {
            # Skip.
            continue;
        }

        # Get recipient.
        $recipient = Get-Recipient -Identity $distributionGroupOwner -ResultSize 1 -ErrorAction SilentlyContinue;

        # If recipient is not found.
        if ($null -eq $recipient)
        {
            # Skip.
            continue;
        }

        # Write to log.
        Write-Log -Category ($distributionGroup.PrimarySmtpAddress) -Message ("'{0}' is a owner" -f $recipient.PrimarySmtpAddress) -Level 'Information';

        # Add to list.
        $ownersPrimarySmtpAddresses.Add($recipient.PrimarySmtpAddress) | Out-Null;
    }

    # If external senders are allowed.
    if ($distributionGroup.RequireSenderAuthenticationEnabled -eq $false)
    {
        # Write to log.
        Write-Log -Category ($distributionGroup.PrimarySmtpAddress) -Message ('External senders is allowed to email this distribution group') -Level 'Information';

        # Bool to check if external senders are allowed.
        $allowExternalSenders = $true;
    }

    # Write to log.
    Write-Log -Category ($distributionGroup.PrimarySmtpAddress) -Message ("Distribution group type is '{0}'" -f $distributionGroup.GroupType) -Level 'Information';
    Write-Log -Category ($distributionGroup.PrimarySmtpAddress) -Message ("Hide distribution group from address list set to '{0}'" -f $distributionGroup.HiddenFromAddressListsEnabled) -Level 'Information';
    Write-Log -Category ($distributionGroup.PrimarySmtpAddress) -Message ("Members depart restricted is set to '{0}'" -f $distributionGroup.MemberDepartRestriction) -Level 'Information';
    Write-Log -Category ($distributionGroup.PrimarySmtpAddress) -Message ("Members join restricted is set to '{0}'" -f $distributionGroup.MemberJoinRestriction) -Level 'Information';
    Write-Log -Category ($distributionGroup.PrimarySmtpAddress) -Message ("Distribution group membership visibility isset to be '{0}'" -f $distributionGroup.HiddenGroupMembershipEnabled) -Level 'Information';

    # Add to report.
    $report += [PSCustomObject]@{
        'PrmarySmtpAddress'            = $distributionGroup.PrimarySmtpAddress;
        'AllowExternalSenders'         = $allowExternalSenders;
        'Type'                         = $distributionGroup.GroupType;
        'HiddenFromAddressList'        = $distributionGroup.HiddenFromAddressListsEnabled;
        'MemberDepartRestriction'      = $distributionGroup.MemberDepartRestriction;
        'MemberJoinRestriction'        = $distributionGroup.MemberJoinRestriction;
        'HiddenGroupMembershipEnabled' = $distributionGroup.HiddenGroupMembershipEnabled;
        'EmailAddresses'               = $distributionGroup.EmailAddresses -join '|'
        'Members'                      = $membersPrimarySmtpAddresses -join '|';
        'Owners'                       = $ownersPrimarySmtpAddresses -join '|';
    };
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Export to CSV.
$report | Export-Csv -Path $Path -Encoding utf8 -Delimiter ';' -NoTypeInformation -Force;

############### Finalize - End ###############
#endregion
