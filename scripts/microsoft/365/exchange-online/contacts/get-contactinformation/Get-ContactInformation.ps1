#Requires -Version 5.1;
#Requires -Modules ExchangeOnlineManagement;

<#
.SYNOPSIS
  Get all contacts and export to a CSV file.

.DESCRIPTION
  Connect to Exchange Online and retrieve all contacts. Export the contacts to a CSV file.

.Parameter Path
  This is the path of the CSV file.
  Is optional, if not provided the script will use the desktop.

.Example
   .\Get-ExchangeContacts.ps1 -Path "C:\MyPath\To\Contacts.csv";

.NOTES
  Version:        1.0
  Author:         Alex Hansen (aths@systemadmins.com)
  Creation Date:  07-02-2024
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
    [string]$Path = ('{0}\{1}_{2}' -f ([Environment]::GetFolderPath('Desktop')), (Get-Date).ToString('yyyyMMdd'), 'ExoContacts.csv')
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

# Try to connect to Exchange Online.
try
{
    # Connect to Exchange.
    Connect-ExchangeOnline -ShowProgress $true -ShowBanner:$false -ErrorAction Stop;
}
# Something went wrong connecting to Exchange Online.
catch
{
    # Throw execption.
    Write-Log -Category ('Authentication') -Message $_.Exception.Message -Level 'Error';
}

# Get all Exchange contacts.
$exoContacts = Get-Contact -ResultSize Unlimited;

# Object array to store contacts.
$contacts = New-Object System.Collections.ArrayList;

# Foreach contact.
foreach ($exoContact in $exoContacts)
{
    # Get recipient.
    $exoRecipient = Get-Recipient -Filter "PrimarySmtpAddress -eq '$($exoContact.WindowsEmailAddress)'";

    # Add contact to array.
    $contacts += [PSCustomObject]@{
        WindowsEmailAddress           = $exoContact.WindowsEmailAddress;
        DisplayName                   = $exoContact.DisplayName;
        FirstName                     = $exoContact.FirstName;
        LastName                      = $exoContact.LastName;
        Phone                         = $exoContact.Phone;
        MobilePhone                   = $exoContact.MobilePhone;
        City                          = $exoContact.City;
        Company                       = $exoContact.Company;
        CountryOrRegion               = $exoContact.CountryOrRegion;
        Department                    = $exoContact.Department;
        Initials                      = $exoContact.Initials;
        Office                        = $exoContact.Office;
        PostalCode                    = $exoContact.PostalCode;
        StateOrProvince               = $exoContact.StateOrProvince;
        StreetAddress                 = $exoContact.StreetAddress;
        Title                         = $exoContact.Title;
        IsDirSync                     = $exoContact.IsDirSynced;
        ExternalEmailAddress          = $exoRecipient.ExternalEmailAddress;
        PrimarySmtpAddress            = $exoRecipient.PrimarySmtpAddress;
        EmailAddresses                = ($exoRecipient.EmailAddresses -join '|');
        HiddenFromAddressListsEnabled = $exoRecipient.HiddenFromAddressListsEnabled;
        ManagedBy                     = ($exoRecipient.ManagedBy -join '|');
        RecipientTypeDetails          = $exoRecipient.RecipientTypeDetails;
    };
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Export contacts to CSV file.
$contacts | Export-Csv -Path $Path -NoTypeInformation -Encoding utf8 -Delimiter ';' -Force;

############### Finalize - End ###############
#endregion
