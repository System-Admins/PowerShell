#Requires -Version 5.1;
#Requires -Modules ADCSAdministration;
#Requires -RunAsAdministrator;

<#
.SYNOPSIS
  Maintainance automation for a Active Directory Certificate Services.

.DESCRIPTION
  This script is used to clean-up (defragmentation in offline mode and remove expired certificates) the Active Directory Certificate Services database on Windows Server.
  - Make sure to run this script with elevated permissions.
  - If you choose to defrag the database, it will bring down the ADCS service and restart it after the defragmentation is done.
  - It's possible to backup the database before the cleanup, and the script will check if there is enough free space on the drive before starting the backup.
  - The CRL publication intervals will be saved to a temporary file before the defragmentation and restored after the defragmentation.
  - CRL will be extended to 7 days (default, but could be changed) before the defragmentation and reverted after the defragmentation.

.Parameter Backup
  (Optional) If backup should be taken.

.Parameter BackupPath
  (Optional) Backup path. Default is "C:\Users\<user>\AppData\Local\Temp\ADCSBackup_<date>".

.Parameter BackupPrivateKey
  (Optional) Backup private key as well.

.Parameter RemoveExpiredCertificate
  (Optional) If expired certificates should be removed.

.Parameter ExpiredCertificateDayThreshold
  (Optional) Number of days when the expired certificates should be deleted to. Default is 90 days.

.Parameter DefragmentDatabase
  (Optional) If the database should be defragmented.

.Parameter ExtendCrlLifeTime
  (Optional) If CRL should be extended (will be reverted after defragmentation). Only works if the database is defragmented.

.Parameter ExtendCrlDays
  (Optional) How long the CRL should be extended. Default is 7 days. Only works if the database is defragmented.

.EXAMPLE
  # Take a backup (including private key) to "C:\Temp\backup" and remove expired certificates up to 30 days. Defragment the database and extend the CRL lifetime with 7 days.
  .\Invoke-ADCSDatabaseCleanup.ps1 -Backup -BackupPath 'C:\Temp\backup' -BackupPrivateKey -RemoveExpiredCertificate -Days 30 -DefragmentDatabase -ExtendCrlLifeTime -ExtendCrlDays 7;

.EXAMPLE
  # Take a backup (withot private key) to "C:\Temp\backup" and remove expired certificates up to 90 days. Defragment the database without extending CRL.
  .\Invoke-ADCSDatabaseCleanup.ps1 -Backup -BackupPath 'C:\Temp\backup' -RemoveExpiredCertificate -Days 90 -DefragmentDatabase;

.EXAMPLE
  # Remove only expired certificates up to 90 days.
  .\Invoke-ADCSDatabaseCleanup.ps1 -RemoveExpiredCertificate -Days 90 -DefragmentDatabase;

.EXAMPLE
  # Backup the database to "C:\Temp\backup".
  .\Invoke-ADCSDatabaseCleanup.ps1 -Backup -BackupPath 'C:\Temp\backup';

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  31-05-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]

param
(
    # If backup should be taken.
    [Parameter(Mandatory = $false)]
    [switch]$Backup,

    # Backup path. Default is "C:\Users\<user>\AppData\Local\Temp\ADCSBackup_<date>".
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BackupPath = ('{0}\ADCSBackup_{1}' -f $env:TEMP, (Get-Date -Format 'yyyyMMdd')),

    # Backup private key as well.
    [Parameter(Mandatory = $false)]
    [switch]$BackupPrivateKey,

    # If expired certificates should be removed.
    [Parameter(Mandatory = $false)]
    [switch]$RemoveExpiredCertificate,

    # Number of days when the expired certificates should be deleted to. Default is 90 days.
    [Parameter(Mandatory = $false)]
    [ValidateScript({ $_ -ge 0 })]
    [int]$ExpiredCertificateDayThreshold = 90,

    # If the database should be defragmented.
    [Parameter(Mandatory = $false)]
    [switch]$DefragmentDatabase,

    # If CRL should be extended (will be reverted after defragmentation). Only works if the database is defragmented.
    [Parameter(Mandatory = $false)]
    [switch]$ExtendCrlLifeTime,

    # How long the CRL should be extended. Default is 7 days. Only works if the database is defragmented.
    [Parameter(Mandatory = $false)]
    [ValidateScript({ $_ -gt 0 })]
    [int]$ExtendCrlDays = 7
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

# Temporary path for CRL publication intervals.
[string]$crlPublicationConfigPath = ('{0}\CRLPublicationIntervals_{1}.csv' -f $env:TEMP, (New-Guid).Guid);

# Log file path.
[string]$Global:logFilePath = ('{0}\{1}_{2}.log' -f $env:TEMP, (Get-Date).ToString('yyyyMMdd'), $MyInvocation.MyCommand.Name);

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

function Test-CertUtilPresent
{
    <#
    .SYNOPSIS
        Test if the certutil.exe utility is available.
    .DESCRIPTION
        Certutil.exe is placed in the path "C:\Windows\System32\certutil.exe".
    .EXAMPLE
        Test-CertUtilPresent;
    #>
    [cmdletbinding()]
    [OutputType([bool])]
    param
    (
    )

    BEGIN
    {
        # Certutil path.
        [string]$certutilPath = 'C:\Windows\System32\certutil.exe';

        # Boolean to check if certutil is available.
        [bool]$isValid = $false;
    }
    PROCESS
    {
        # If certutil.exe is present.
        if (Test-Path -Path $certutilPath -PathType Leaf)
        {
            # Set valid.
            $isValid = $true;
        }
    }
    END
    {
        # Return bool.
        return $isValid;
    }
}

function Test-EsentUtilPresent
{
    <#
    .SYNOPSIS
        Test if the esentutl.exe utility is available.
    .DESCRIPTION
        Certutil.exe is placed in the path "C:\Windows\System32\esentutl.exe".
    .EXAMPLE
       Test-EsentUtilPresent;
    #>
    [cmdletbinding()]
    [OutputType([bool])]
    param
    (
    )

    BEGIN
    {
        # Certutil path.
        [string]$esentutlPath = 'C:\Windows\System32\esentutl.exe';

        # Boolean to check if esentutl is available.
        [bool]$isValid = $false;
    }
    PROCESS
    {
        # If esentutl.exe is present.
        if (Test-Path -Path $esentutlPath -PathType Leaf)
        {
            # Set valid.
            $isValid = $true;
        }
    }
    END
    {
        # Return bool.
        return $isValid;
    }
}

function Test-IsLocalAdmin
{
    <#
    .SYNOPSIS
        Test if the current user is a local administrator.
    .DESCRIPTION
        Test if the current user is a member of the local "administrators" group.
    .EXAMPLE
        Test-IsLocalAdmin;
    #>
    [cmdletbinding()]
    [OutputType([bool])]
    param
    (
    )

    BEGIN
    {
        # Boolean to check if the user is a local admin.
        [bool]$isLocalAdmin = $false;

        # Get the current user.
        [Security.Principal.WindowsIdentity]$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent();

        # Write to console.
        Write-Console -Message ("Checking if user '{0}' is local administrator" -f $currentIdentity.Name) -Color 'White';
    }
    PROCESS
    {
        # Is running as administrator.
        if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
        {
            # Write to log.
            Write-CustomLog -Message ("User '{0}' is local administrator" -f $currentIdentity.Name) -Level Verbose;

            # Write to console.
            Write-Console -Message ("User '{0}' is local administrator" -f $currentIdentity.Name) -Color 'White' -IndentLevel 1;

            # Set valid.
            $isLocalAdmin = $true;
        }
        # Else not running as administrator.
        else
        {
            # Write to log.
            Write-CustomLog -Message ("User '{0}' is not a local administrator" -f $currentIdentity.Name) -Level Verbose;

            # Write to console.
            Write-Console -Message ("User '{0}' is local administrator" -f $currentIdentity.Name) -Color 'Red' -IndentLevel 1;
        }
    }
    END
    {
        # Return bool.
        return $isLocalAdmin;
    }
}

function Write-CustomLog
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
    .PARAMETER NoLogFile
        (Optional) If the log message should not be added to a file.
    .EXAMPLE
        # Write a information message to the console.
        Write-MyLog -Message 'This is an information message'
    .EXAMPLE
        # Write a debug message to a log file and console.
        Write-CustomLog -Message 'This is a debug message' -Path 'C:\Temp\log.txt' -Level Verbose
    .EXAMPLE
        # Write an error message to a log file but not to the console.
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level Error -NoConsole
    .EXAMPLE
        # Write an information message to a log file but not to the console and do not append to the log file.
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level 'Information' -NoConsole -NoAppend
    #>
    [cmdletbinding()]
    param
    (

        # Message to write to log.
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        # If category should be included.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Category,

        # If subcategory should be included.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Subcategory,

        # (Optional) Path to log file.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Path,

        # (Optional) Log level.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Error', 'Warning', 'Information', 'Debug', 'Verbose')]
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

        # (Optional) If the log message should not be added to a file.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoLogFile
    )

    BEGIN
    {
        # Store original preferences.
        $originalInformationPreference = $InformationPreference;
    }
    PROCESS
    {
        # If path is not specified and output to file is set.
        if ([string]::IsNullOrEmpty($Path))
        {
            # If global log file is not set.
            if ([string]::IsNullOrEmpty($Global:logFilePath))
            {
                # Set global path.
                $Global:logFilePath = ('{0}\{1}.log' -f $env:TEMP, (New-Guid).Guid);
            }

            # Set path.
            $Path = $Global:logFilePath;
        }

        # If log file don't exist.
        if (!(Test-Path -Path $Path -PathType Leaf))
        {
            # Get folder path.
            [string]$folderPath = Split-Path -Path $Path -Parent;

            # If folder path don't exist.
            if (!(Test-Path -Path $folderPath -PathType Container))
            {
                # Create folder path.
                $null = New-Item -Path $folderPath -ItemType Directory -Force;
            }

            # Create log file.
            $null = New-Item -Path $Path -ItemType File -Force;
        }
        # If log file exist.
        else
        {
            # If log file should not be appended.
            if ($true -eq $NoAppend)
            {
                # Clear log file.
                $null = Clear-Content -Path $Path -Force;
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

        # If subcategory should be added to log message.
        if ($false -eq [string]::IsNullOrEmpty($Subcategory))
        {
            # Add category to log message.
            $logMessage += ('[{0}]' -f $Subcategory);
        }

        # If log message is not empty.
        if (!([string]::IsNullOrEmpty($logMessage)))
        {
            # Add message to log message.
            $logMessage = ('{0} {1}' -f $logMessage, $Message);
        }
        # Else log message is empty.
        else
        {
            # Add message to log message.
            $logMessage = ('{0}' -f $Message);
        }


        # Based on the level.
        switch ($Level)
        {
            'Error'
            {
                Write-Error -Message $logMessage;
            }
            'Warning'
            {
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
            'Verbose'
            {
                Write-Verbose -Message $logMessage;
            }
        }

        # If output should be written to file.
        if ($false -eq $NoLogFile)
        {
            # Construct splat parameters.
            $params = @{
                'FilePath' = $Path;
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
            $null = $logMessage | Out-File @params;
        }

        # If output is Error, throw execption.
        if ($Level -eq 'Error')
        {
            throw ($logMessage);
        }
    }
    END
    {
        # Restore original preferences.
        $InformationPreference = $originalInformationPreference;
    }
}

function Write-Console
{
    <#
    .SYNOPSIS
        Write to the console (host) with different levels.
    .DESCRIPTION
        Write to console using [+] and [-] different levels with colour.
    .PARAMETER Message
        Message to write to the console.
    .PARAMETER IndentLevel
        (Optional) Indent level.
    .PARAMETER Color
        (Optional) Color of the message.
    .EXAMPLE
        Write-Console -Message 'This is a message' -IndentLevel 2 -Color 'Green';
    #>
    [cmdletbinding()]
    param
    (

        # Message to write to log.
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        # Indent level.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]$IndentLevel = 0,

        # Color.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Green', 'Red', 'Yellow', 'White')]
        [string]$Color = 'White'
    )

    BEGIN
    {
        # Prefix meessage.
        [string]$prefixMessage = '';
    }
    PROCESS
    {
        # For each indent level.
        for ($i = 0; $i -lt $IndentLevel; $i++)
        {
            # Add indent.
            $prefixMessage += '  ';
        }

        # If indent level is greater than 0.
        if ($IndentLevel -gt 0)
        {
            # Add message.
            $prefixMessage += ('{0}[-] ' -f $prefixMessage);
        }
        # Else indent level is 0.
        else
        {
            # Add message.
            $prefixMessage += ('{0}[+] ' -f $prefixMessage);
        }
    }
    END
    {
        # Write to console.
        Write-Host -Object $prefixMessage -NoNewline;
        Write-Host -Object $Message -ForegroundColor $Color;
    }
}

function Stop-ADCSService
{
    <#
    .SYNOPSIS
        Stops the Active Directory Certificate Services service.
    .DESCRIPTION
        Stops the Active Directory Certificate Services service.
    .EXAMPLE
        Stop-ADCSService;
    #>
    [cmdletbinding()]
    [OutputType([void])]
    param
    (
    )

    BEGIN
    {
        # Service name.
        [string]$serviceName = 'CertSvc';
    }
    PROCESS
    {
        # Try to get the service.
        try
        {
            # Get the service.
            [System.ServiceProcess.ServiceController]$service = Get-Service -Name $serviceName -ErrorAction Stop;

            # If service is running.
            if ($service.Status -eq 'Running')
            {
                # Try to stop the service.
                try
                {
                    # Stop the service.
                    $null = Stop-Service -Name $serviceName -ErrorAction Stop;

                    # Write to log.
                    Write-CustomLog -Message ("Service '{0}' stopped" -f $serviceName) -Level Verbose;

                    # Write to console.
                    Write-Console -Message ("Service '{0}' stopped" -f $serviceName) -Color 'White' -IndentLevel 1;
                }
                # Something went wrong.
                catch
                {
                    # Write to console.
                    Write-Console -Message ("Failed to stop service '{0}'" -f $serviceName) -Color 'Red' -IndentLevel 1;

                    # Throw execption.
                    Write-CustomLog -Level Error -Message ("Failed to stop service '{0}'. {1}" -f $serviceName, $_.Exception.Message);
                }
            }
            # Else service is not running.
            else
            {
                # Write to log.
                Write-CustomLog -Message ("Service '{0}' is already stopped" -f $serviceName) -Level Verbose;

                # Write to console.
                Write-Console -Message ("Service '{0}' is already stopped" -f $serviceName) -Color Yellow -IndentLevel 1;
            }
        }
        # Something went wrong.
        catch
        {
            # Write to console.
            Write-Console -Message ("Server '{0}' dont exist" -f $serviceName) -Color 'Red' -IndentLevel 1;

            # Throw execption.
            Write-CustomLog -Level Error -Message ("Server '{0}' dont exist. {1}" -f $serviceName, $_.Exception.Message);
        }
    }
    END
    {
        # Return.
        return;
    }
}

function Get-ADCSService
{
    <#
    .SYNOPSIS
        Get the Active Directory Certificate Services service status.
    .DESCRIPTION
        Get status if the service is up or down.
    .EXAMPLE
        Get-ADCSService;
    #>
    [cmdletbinding()]
    [OutputType([string])]
    param
    (
    )

    BEGIN
    {
        # Service name.
        [string]$serviceName = 'CertSvc';
    }
    PROCESS
    {
        # Try to get the service.
        try
        {
            # Get the service.
            [System.ServiceProcess.ServiceController]$service = Get-Service -Name $serviceName -ErrorAction Stop;

            # Write to console.
            Write-Console -Message ("Service is '{0}'" -f $service.Status) -Color White -IndentLevel 1;
        }
        # Something went wrong.
        catch
        {
            # Write to console.
            Write-Console -Message ("Service '{0}' dont exist" -f $serviceName) -Color Red -IndentLevel 1;

            # Throw execption.
            Write-CustomLog -Level Error -Message ("Service '{0}' dont exist. {1}" -f $serviceName, $_.Exception.Message);
        }
    }
    END
    {
        # Return status.
        return [string]$service.Status;
    }
}

function Start-ADCSService
{
    <#
    .SYNOPSIS
        Start the Active Directory Certificate Services service.
    .DESCRIPTION
        Start the Active Directory Certificate Services service.
    .EXAMPLE
        Start-ADCSService;
    #>
    [cmdletbinding()]
    [OutputType([void])]
    param
    (
    )

    BEGIN
    {
        # Service name.
        [string]$serviceName = 'CertSvc';
    }
    PROCESS
    {
        # Try to get the service.
        try
        {
            # Get the service.
            [System.ServiceProcess.ServiceController]$service = Get-Service -Name $serviceName -ErrorAction Stop;

            # If service is running.
            if ($service.Status -eq 'Running')
            {
                # Write to log.
                Write-CustomLog -Message ("Service '{0}' is already running" -f $serviceName) -Level Verbose;

                # Write to console.
                Write-Console -Message ('The ADCS service is already running' -f $currentIdentity.Name) -Color 'Yellow' -IndentLevel 1;
            }
            # Else service is not running.
            else
            {
                # Try to stop the service.
                try
                {
                    # Stop the service.
                    $null = Start-Service -Name $serviceName -ErrorAction Stop;

                    # Write to log.
                    Write-CustomLog -Message ("Service '{0}' started" -f $serviceName) -Level Verbose;

                    # Write to console.
                    Write-Console -Message ('The ADCS service is started' -f $currentIdentity.Name) -Color 'White' -IndentLevel 1;
                }
                # Something went wrong.
                catch
                {
                    # Write to console.
                    Write-Console -Message ('Failed to start the ADCS service' -f $currentIdentity.Name) -Color 'Red' -IndentLevel 1;

                    # Throw execption.
                    Write-CustomLog -Level Error -Message ("Failed to start service '{0}'. {1}" -f $serviceName, $_.Exception.Message);
                }
            }
        }
        # Something went wrong.
        catch
        {
            # Write to console.
            Write-Console -Message ("Service '{0}' dont exist" -f $serviceName) -Color Red -IndentLevel 1;

            # Throw execption.
            Write-CustomLog -Level Error -Message ("Server '{0}' dont exist. {1}" -f $serviceName, $_.Exception.Message);
        }
    }
    END
    {
        # Return.
        return;
    }
}

function Invoke-CertUtility
{
    <#
    .SYNOPSIS
        Invokes the certutil.exe utility on Windows.
    .DESCRIPTION
        Call the certutil utility with arguments.
    .PARAMETER Arguments
        Arguments to pass to the certutil utility.
    .EXAMPLE
        Invoke-CertUtility -Arguments '-backupdb C:\Temp\backup';
    #>
    [cmdletbinding()]
    [OutputType([string])]
    param
    (
        # Arguments to pass to the certutil utility.
        [Parameter(Mandatory = $null, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Arguments
    )

    BEGIN
    {
        # Certutil path.
        [string]$certutilPath = 'C:\Windows\System32\certutil.exe';
    }

    PROCESS
    {
        # If certutil path don't exist.
        if (!(Test-Path -Path $certutilPath -PathType Leaf))
        {
            # Throw execption.
            Write-CustomLog -Level Error -Message ("Cant find the certutil.exe program at '{0}'" -f $certutilPath);
        }

        # Create process object.
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo;
        $processStartInfo.FileName = $certutilPath;
        $processStartInfo.RedirectStandardError = $true;
        $processStartInfo.RedirectStandardOutput = $true;
        $processStartInfo.UseShellExecute = $false;
        $processStartInfo.CreateNoWindow = $true;

        # If arguments is specified.
        if (!([string]::IsNullOrEmpty($Arguments)))
        {
            # Set arguments.
            $processStartInfo.Arguments = $Arguments;
        }

        # Try to run certutil.exe with arguments.
        try
        {
            # Write to log.
            Write-CustomLog -Message ("Trying to execute certutil.exe with arguments '{0}'" -f $Arguments) -Level Verbose;

            # Start the certutil process.
            $process = New-Object System.Diagnostics.Process;
            $process.StartInfo = $processStartInfo;
            $null = $process.Start();
            $process.WaitForExit();

            # If exit code is not 0 (success).
            if ($process.ExitCode -eq 0)
            {
                # Get output.
                $standardOutput = $process.StandardOutput.ReadToEnd();

                # Write to log.
                Write-CustomLog -Message ("Succesfully executed certutil.exe with arguments '{0}'" -f $Arguments) -Level Verbose;
            }
            # Else if the exit code is 939523027 (success, but throttled).
            elseif ($process.ExitCode -eq 939523027)
            {
                # Write to log.
                Write-CustomLog -Message ("Succesfully executed certutil.exe with arguments '{0}', but code exit code 939523027 (which mean throttled). Will retry operation" -f $Arguments) -Level Verbose;

                # Retry the process.
                $null = Invoke-CertUtility -Arguments $Arguments;
            }
            # Else exit code is not 0 (mayby an error).
            else
            {
                # Get error.
                $standardError = $process.StandardError.ReadToEnd();

                # Throw execption.
                Write-CustomLog -Level Error -Message ('Failed to run certutil.exe. {0}' -f $standardError);
            }
        }
        catch
        {
            # Throw execption.
            Write-CustomLog -Level Error -Message("Something went wrong while executing certutil.exe with arguments '{0}'. {1}" -f $Arguments, $_);
        }
    }
    END
    {
        # Write to log.
        Write-CustomLog -Message ("Output from certutil.exe: `r`n{0}" -f $standardOutput) -Level Verbose;

        # Return output.
        return [string]$standardOutput;
    }
}

function Invoke-EsentUtility
{
    <#
    .SYNOPSIS
        Invokes the esentutl.exe utility on Windows.
    .DESCRIPTION
        Call the esentutl utility with arguments.
    .PARAMETER Arguments
        Arguments to pass to the esentutl utility.
    .EXAMPLE
        Invoke-EsentUtility -Arguments '-d "C:\Windows\System32\CertLog\<ca name>.edb"';
    #>
    [cmdletbinding()]
    [OutputType([string])]
    param
    (
        # Arguments to pass to the Esentutil utility.
        [Parameter(Mandatory = $null, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Arguments
    )

    BEGIN
    {
        # Esentutil path.
        [string]$esentutilPath = 'C:\Windows\System32\esentutl.exe';
    }

    PROCESS
    {
        # If certutil path don't exist.
        if (!(Test-Path -Path $esentutilPath -PathType Leaf))
        {
            # Throw execption.
            Write-CustomLog -Level Error -Message ("Cant find the esentutl.exe program at '{0}'" -f $esentutilPath);
        }

        # Create process object.
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo;
        $processStartInfo.FileName = $esentutilPath;
        $processStartInfo.RedirectStandardError = $true;
        $processStartInfo.RedirectStandardOutput = $true;
        $processStartInfo.UseShellExecute = $false;
        $processStartInfo.CreateNoWindow = $true;

        # If arguments is specified.
        if (!([string]::IsNullOrEmpty($Arguments)))
        {
            # Set arguments.
            $processStartInfo.Arguments = $Arguments;
        }

        # Try to run esentutl.exe with arguments.
        try
        {
            # Write to log.
            Write-CustomLog -Message ("Trying to execute esentutil.exe with arguments '{0}'" -f $Arguments) -Level Verbose;

            # Start the certutil process.
            $process = New-Object System.Diagnostics.Process;
            $process.StartInfo = $processStartInfo;
            $null = $process.Start();
            $process.WaitForExit();

            # If exit code is not 0 (success).
            if ($process.ExitCode -eq 0)
            {
                # Get output.
                $standardOutput = $process.StandardOutput.ReadToEnd();

                # Write to log.
                Write-CustomLog -Message ("Succesfully executed esentutl.exe with arguments '{0}'" -f $Arguments) -Level Verbose;
            }
            # Else exit code is not 0 (mayby an error).
            else
            {
                # Get error.
                $standardError = $process.StandardError.ReadToEnd();

                # Throw execption.
                Write-CustomLog -Level Error -Message ('Failed to run esentutl.exe. {0}' -f $standardError);
            }
        }
        catch
        {
            # Throw execption.
            Write-CustomLog -Level Error -Message("Something went wrong while executing esentutl.exe with arguments '{0}'. {1}" -f $Arguments, $_);
        }
    }
    END
    {
        # Write to log.
        Write-CustomLog -Message ("Output from esentutil.exe: `r`n{0}" -f $standardOutput) -Level Verbose;

        # Return output.
        return [string]$standardOutput;
    }
}

function Backup-ADCSDatabase
{
    <#
    .SYNOPSIS
        Backup the Active Directory Certificate Services database.
    .DESCRIPTION
        Creates a folder and backup the Active Directory Certificate Services database to the folder.
    .PARAMETER Path
        (Optional) Backup path for the database.
    .PARAMETER PrivateKey
        (Optional) Include private key in the backup.
    .EXAMPLE
        Backup-ADCSDatabase;
    .EXAMPLE
        Backup-ADCSDatabase -Path 'C:\Temp\backup';
    .EXAMPLE
        Backup-ADCSDatabase -Path 'C:\Temp\backup' -PrivateKey;
    #>
    [cmdletbinding()]
    [OutputType([string])]
    param
    (
        # Backup path.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path = ('{0}\ADCSBackup_{1}' -f $env:TEMP, (Get-Date -Format 'yyyyMMdd')),

        # Private key backup.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$PrivateKey
    )

    BEGIN
    {
        # Write to log.
        Write-CustomLog -Message ("Creating backup path '{0}' for the ADCS database (if it dont exist)" -f $Path) -Level Verbose;

        # Write to console.
        Write-Console -Message ('Starting backup of ADCS database') -Color 'White';

        # Create backup path.
        $null = New-Item -Path $Path -ItemType Directory -Force;

        # Get backup path drive letter.
        [string]$driveLetter = $Path.Substring(0, 1);

        # Get the free space on the drive.
        $diskspace = Get-DiskSpace -Drive $driveLetter;

        # Get the size of the database.
        $databaseSize = Get-ADCSDatabaseSize;

        # If the free space is less than the database size.
        if ($diskspace.FreeSpace -lt $databaseSize)
        {
            # Write to console.
            Write-Console -Message ("Not enough free space on drive '{0}' to backup the database. Free space: {1} GB, Database size: {2} GB" -f $driveLetter, ($diskspace.FreeSpace / 1GB), ($databaseSize / 1GB)) -Color 'Red' -IndentLevel 1;

            # Throw execption.
            Write-CustomLog -Level Error -Message ("Not enough free space on drive '{0}' to backup the database. Free space: {1} GB, Database size: {2} GB" -f $driveLetter, ($diskspace.FreeSpace / 1GB), ($databaseSize / 1GB));
        }
    }
    PROCESS
    {
        # If private key should be included.
        if ($true -eq $PrivateKey)
        {
            # Write to console.
            Write-Console -Message ('Private key will be included in the backup if possible') -Color 'White' -IndentLevel 1;

            # Try to backup the database.
            try
            {
                # Write to log.
                Write-CustomLog -Message ("Trying to backup the ADCS database to '{0}' (including private key), this might take a few moments" -f $Path) -Level Verbose;

                # Backup the database.
                Backup-CARoleService -Path $Path -KeepLog -Force -ErrorAction Stop;

                # Write to log.
                Write-CustomLog -Message ("Succesfully backup ADCS database to '{0}'" -f $Path) -Level Verbose;

                # Write to console.
                Write-Console -Message ("Succesfully backup ADCS database to '{0}'" -f $Path) -Color 'White' -IndentLevel 1;
            }
            # Something went wrong while backing up the database.
            catch
            {
                # Write to log.
                Write-CustomLog -Message ('Backup failed. Maybe due to the private key is not exportable. {0}' -f $_) -Level Verbose;

                # Write to console.
                Write-Console -Message ('Backup failed. Maybe due to the private key is not exportable') -Color 'Red' -IndentLevel 1;

                # Try to backup the database.
                try
                {
                    # Write to log.
                    Write-CustomLog -Message ('Trying to backup the database without private key' -f $Path) -Level Verbose;

                    # Write to console.
                    Write-Console -Message ('Trying to backup the database without private key') -Color 'White' -IndentLevel 2;

                    # Backup the database.
                    Backup-CARoleService -Path $Path -DatabaseOnly -KeepLog -Force -ErrorAction Stop;

                    # Write to log.
                    Write-CustomLog -Message ("Succesfully backup ADCS database to '{0}'" -f $Path) -Level Verbose;

                    # Write to console.
                    Write-Console -Message ("Succesfully backup ADCS database to '{0}'" -f $Path) -Color 'White' -IndentLevel 2;
                }
                # Something went wrong.
                catch
                {
                    # Write to console.
                    Write-Console -Message ('Failed to backup the database without private key') -Color 'Red' -IndentLevel 2;

                    # Throw execption.
                    Write-CustomLog -Level Error -Message ("Failed to backup the ADCS database to '{0}'. {1}" -f $Path, $_);
                }
            }
        }
        # Else no private key.
        else
        {
            # Try to backup the database.
            try
            {
                # Write to log.
                Write-CustomLog -Message ("Trying to backup the ADCS database to '{0}' (without private key), this might take a few moments" -f $Path) -Level Verbose;

                # Write to console.
                Write-Console -Message ('Private key will NOT be included in the backup') -Color 'White' -IndentLevel 1;

                # Backup the database.
                Backup-CARoleService -Path $Path -DatabaseOnly -KeepLog -Force -ErrorAction Stop;

                # Write to log.
                Write-CustomLog -Message ("Succesfully backup ADCS database to '{0}'" -f $Path) -Level Verbose;

                # Write to console.
                Write-Console -Message ("Succesfully backup ADCS database to '{0}'" -f $Path) -Color 'White' -IndentLevel 1;
            }
            # Something went wrong.
            catch
            {
                # Write to console.
                Write-Console -Message ('Failed to backup the database without private key') -Color 'Red' -IndentLevel 1;

                # Throw execption.
                Write-CustomLog -Level Error -Message ("Failed to backup the ADCS database to '{0}'. {1}" -f $Path, $_);
            }
        }
    }
    END
    {
        # Write to console.
        Write-Console -Message ("Backup path is '{0}\DataBase'" -f $Path) -Color 'White' -IndentLevel 1;

        # Return path of the backup folder.
        return ('{0}\DataBase' -f $Path);
    }
}

function Get-ADCSCertificateExpired
{
    <#
    .SYNOPSIS
        Get all expired certificates from the ADCS database.
    .DESCRIPTION
        Using certutil we will get the expired certificates and return the in a object array.
        Same as running:
        certutil -view -restrict "Certificate Expiration Date < NOW" -out "RequestId,RequesterName,CommonName,CertificateTemplate,Certificate Expiration Date,CertificateHash" csv
    .EXAMPLE
        Get-ADCSCertificateExpired;
    #>

    [cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
        # Date to get expired certificates up-to. Default is today.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [DateTime]$ExpireDate
    )

    BEGIN
    {
        # Write to console.
        Write-Console -Message ('Getting expired certificates') -Color 'White';

        # If date is set.
        if ($null -ne $ExpireDate)
        {
            # If date is in the future.
            if ($ExpireDate -gt (Get-Date))
            {
                # Write to console.
                Write-Console -Message ("The date '{0}' cant be in the future" -f $ExpireDate.ToString("dd'/'MM'/'yyyy")) -Color 'Red' -IndentLevel 1;

                # Throw execption.
                Write-CustomLog -Level Error -Message ("The date '{0}' cant be in the future" -f $ExpireDate.ToString("dd'/'MM'/'yyyy"));
            }

            # Write to log.
            Write-CustomLog -Message ('Getting expired certificates up-to {0}' -f $ExpireDate.ToString("dd'/'MM'/'yyyy")) -Level Verbose;

            # Write to console.
            Write-Console -Message ('Getting expired certificates up-to {0}, this might take a few minutes depending on the database size' -f $ExpireDate.ToString("dd'/'MM'/'yyyy")) -Color White -IndentLevel 1;

            # Contruct the arguments.
            [string]$arguments = ('-view -restrict "Certificate Expiration Date < {0}" -out "RequestId,RequesterName,CommonName,CertificateTemplate,Certificate Expiration Date,CertificateHash,StatusCode" csv' -f $ExpireDate.ToString("dd'/'MM'/'yyyy"));
        }
        # Else use today.
        else
        {
            # Write to console.
            Write-Console -Message ('Getting expired certificates up-to {0}, this might take a few minutes depending on the database size' -f (Get-Date).ToString("dd'/'MM'/'yyyy")) -Color White -IndentLevel 1;

            # Write to log.
            Write-CustomLog -Message ('Getting expired certificates up-to {0}' -f (Get-Date).ToString("dd'/'MM'/'yyyy")) -Level Verbose;

            # Contruct the arguments.
            [string]$arguments = '-view -restrict "Certificate Expiration Date < NOW" -out "RequestId,RequesterName,CommonName,CertificateTemplate,Certificate Expiration Date,CertificateHash,StatusCode" csv';
        }

        # Object array for the expired certificates.
        $expiredCertificates = New-Object System.Collections.ArrayList;

    }
    PROCESS
    {
        # Invoke certutil.
        $result = Invoke-CertUtility -Arguments $arguments;

        # Get the rows.
        [string[]]$rows = $result -split '\n';

        # Foreach row.
        foreach ($row in $rows)
        {
            # If row is empty.
            if ([string]::IsNullOrEmpty($row))
            {
                # Skip.
                continue;
            }

            # Skip first row.
            if ($row -like '"Issued Request ID"*')
            {
                # Skip.
                continue;
            }

            # Convert row from CSV to object.
            $csvData = $row | ConvertFrom-Csv -Header 'RequestId', 'RequesterName', 'CommonName', 'CertificateTemplate', 'ExpirationDate', 'CertificateHash', 'StatusCode' -Delimiter ',';

            # Add the data to the object array.
            $null = $expiredCertificates.Add($csvData);
        }
    }
    END
    {
        # Write to log.
        Write-CustomLog -Message ('Found {0} expired certificates' -f $expiredCertificates.Count) -Level Verbose;

        # Write to console.
        Write-Console -Message ('Found {0} expired certificates' -f $expiredCertificates.Count) -Color White -IndentLevel 1;

        # Return the object array.
        return $expiredCertificates;
    }
}

function Remove-ADCSCerticateExpired
{
    <#
    .SYNOPSIS
        Remove expired certificates.
    .DESCRIPTION
        This will remove expired ADCS certificates that are expired up to a certain date.
    .PARAMETER Date
        Date to remove requests up-to. Default is 3 months back.
    .EXAMPLE
        Remove-ADCSRequest -Date ([DateTime]"02-25-2024");
    #>
    [cmdletbinding(SupportsShouldProcess)]
    [OutputType()]
    param
    (
        # Date to remove expired certificates up-to. Default is 3 months back.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [DateTime]$ExpireDate,

        # Limit the number of certificates to remove.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$Limit = 150000
    )

    BEGIN
    {
        # Expired certificates.
        [System.Collections.ArrayList]$expiredCertificates = $null;

        # If date is set.
        if ($null -ne $ExpireDate)
        {
            # Get expired certificates.
            $expiredCertificates = Get-ADCSCertificateExpired -ExpireDate $ExpireDate;
        }
        # Else use today.
        else
        {
            # Get expired certificates.
            $expiredCertificates = Get-ADCSCertificateExpired;
        }

        # Write to console.
        Write-Console -Message ('Removing expired certificates') -Color 'White';

        # Array list for removed certificates.
        [System.Collections.ArrayList]$removedCertificates = New-Object System.Collections.ArrayList;
    }
    PROCESS
    {
        # Counter.
        [int]$counter = 0;

        # Foreach expired certificate.
        foreach ($expiredCertificate in $expiredCertificates)
        {
            # If limit is reached.
            if ($removedCertificates.Count -gt $Limit)
            {
                # Write to log.
                Write-CustomLog -Message ('Limit of {0} certificates removal reached' -f $Limit) -Level Verbose;

                # Write to console.
                Write-Console -Message ('Limit of {0} certificates removal reached (this is to ensure the log file dont growth to big)' -f $Limit) -Color 'White' -IndentLevel 1;

                # Stop function.
                break;
            }

            # Create arguments.
            [string]$arguments = ('-deleterow {0} ' -f $expiredCertificate.RequestId);

            # If whatif is set.
            if ($PSCmdlet.ShouldProcess($expiredCertificate.RequestId, 'Removing expired certificate'))
            {
                # Write to log.
                Write-CustomLog -Message ("Removing expired certificate with id '{0}'" -f $expiredCertificate.RequestId) -Level Verbose;

                # Try to remove the certificate.
                try
                {
                    # Remove expired certificate.
                    $null = Invoke-CertUtility -Arguments $arguments -ErrorAction Stop;

                    # Add to removed certificates.
                    $null = $removedCertificates.Add($expiredCertificate);
                }
                # Something went wrong.
                catch
                {
                    # Write to log.
                    Write-CustomLog -Message ("Failed to remove expired certificate with id '{0}'. {1}" -f $expiredCertificate.RequestId, $_.Exception.Message) -Level Warning;
                }
            }
        }
    }
    END
    {
        # Write to log.
        Write-CustomLog -Message ('Removed {0} expired certificates' -f $counter) -Level Verbose;

        # Write to console.
        Write-Console -Message ('Removed {0} expired certificates' -f $counter) -IndentLevel 1;

        # Returned removed certificates.
        return $removedCertificates;
    }
}

function Get-DateTimeShortDateFormat
{
    <#
    .SYNOPSIS
        Get the short date format for the current culture.
    .DESCRIPTION
        Returns something like dd-MM-yyyy, depending on your settings.
    .EXAMPLE
        Get-DateTimeShortDateFormat;
    #>
    [cmdletbinding()]
    [OutputType([string])]
    param
    (
    )

    BEGIN
    {
        # Get regional date format.
        [CultureInfo]$culture = [CultureInfo]::CurrentCulture;
    }
    PROCESS
    {
        # Get short date format.
        $shortDatePattern = $culture.DateTimeFormat.ShortDatePattern;
    }
    END
    {
        # Return short date format.
        return $shortDatePattern;
    }
}



function Get-ADCSDatabaseLocation
{
    <#
    .SYNOPSIS
        Get the location of the Active Directory Certificate Services database files.
    .DESCRIPTION
        Return database file, database folder and log folder as a object.
    .EXAMPLE
        Get-ADCSDatabaseLocation;
    #>
    [cmdletbinding()]
    [OutputType([PSCustomObject])]
    param
    (
    )

    BEGIN
    {
        # Construct arguments.
        [string]$arguments = '-databaselocations';
    }
    PROCESS
    {
        # Invoke certutil.
        $result = Invoke-CertUtility -Arguments $arguments;

        # Regular expression to match file and folder paths.
        $regex = '\\\\.*';

        # Find matches.
        $regexMatches = [regex]::Matches($result, $regex);

        # Extract paths.
        $paths = $regexMatches | ForEach-Object { $_.Value.Trim() };

        # Construct database location object.
        $databaseLocations = [PSCustomObject]@{
            DatabaseFile   = $paths[0];
            DatabaseFolder = $paths[1];
            LogFolder      = $paths[2];
        };

        # If any of the path is empty.
        if (
            [string]::IsNullOrEmpty($databaseLocations.DatabaseFile) -or
            [string]::IsNullOrEmpty($databaseLocations.DatabaseFolder) -or
            [string]::IsNullOrEmpty($databaseLocations.LogFolder)
        )
        {
            # Write to console.
            Write-Console -Message ('Failed to get database locations') -Color 'Red' -IndentLevel 1;

            # Throw execption.
            Write-CustomLog -Level Error -Message ('Failed to get database locations. Database file: {0}, Database folder: {1}, Log folder: {2}' -f $databaseLocations.DatabaseFile, $databaseLocations.DatabaseFolder, $databaseLocations.LogFolder);
        }

        # Write to log.
        Write-CustomLog -Message ('Database file: {0}' -f $databaseLocations.DatabaseFile) -Level Verbose;
        Write-CustomLog -Message ('Database folder: {0}' -f $databaseLocations.DatabaseFolder) -Level Verbose;
        Write-CustomLog -Message ('Log folder: {0}' -f $databaseLocations.LogFolder) -Level Verbose;

        # Write to console.
        Write-Console -Message ('Database file: {0}' -f $databaseLocations.DatabaseFile) -Color 'White' -IndentLevel 1;
        Write-Console -Message ('Database folder: {0}' -f $databaseLocations.DatabaseFolder) -Color 'White' -IndentLevel 1;
        Write-Console -Message ('Log folder: {0}' -f $databaseLocations.LogFolder) -Color 'White' -IndentLevel 1;
    }
    END
    {
        # Return database locations.
        return $databaseLocations;
    }
}

function Set-ADCSCrlPublicationInterval
{
    <#
    .SYNOPSIS
        Set the CRL publication interval.
    .DESCRIPTION
        Use certutil to set the CRL publication interval.
    .PARAMETER Unit
        Units to use for the interval.
    .PARAMETER Period
        Period to set the interval to.
        Years, 'Months, Weeks, Days or Hours
    .PARAMETER DeltaUnit
        Delta units to use for the interval.
    .PARAMETER DeltaPeriod
        Delta period to set the interval to.
        Years, 'Months, Weeks, Days or Hours
    .PARAMETER OverlapPeriod
        Overlap period.
        Years, 'Months, Weeks, Days or Hours
    .PARAMETER OverlapUnits
        Overlap units.
    .PARAMETER DeltaOverlapPeriod
        Delta overlap period.
        Years, 'Months, Weeks, Days or Hours
    .PARAMETER DeltaOverlapUnits
        Delta overlap units.
    .PARAMETER Restart
        Restart the ADCS service after changing the CRL.
    .PARAMETER Publish
        Publish the CRL after changing the CRL.
    .EXAMPLE
        Set-ADCSCrlPublicationInterval -Unit 3 -Period 'Days' -DeltaUnit 12 -DeltaPeriod 'Hours' -OverlapPeriod 'Hours' -OverlapUnits 12 -DeltaOverlapPeriod 'Hours' -DeltaOverlapUnits 6 -Restart -Publish;
    #>
    [cmdletbinding()]
    [OutputType([void])]
    param
    (
        # Unit for length.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$Unit,

        # Period for the interval.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Years', 'Months', 'Weeks', 'Days', 'Hours', '')]
        [string]$Period,

        # Delta unit for length.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$DeltaUnit,

        # Delta period for the interval.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Years', 'Months', 'Weeks', 'Days', 'Hours', '')]
        [string]$DeltaPeriod,

        # Overlap period.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Years', 'Months', 'Weeks', 'Days', 'Hours', '')]
        [string]$OverlapPeriod,

        # Overlap units.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]$OverlapUnits,

        # Delta overlap units.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]$DeltaOverlapUnits,

        # Delta overlap period.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Years', 'Months', 'Weeks', 'Days', 'Hours', '')]
        [string]$DeltaOverlapPeriod,

        # Restart the ADCS service.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$Restart,

        # If the CRL should be published.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$Publish,

        # If the delta CRL should be disabled.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$DisableDeltaCRL
    )

    BEGIN
    {
        # Write to console.
        Write-Console -Message ('Setting CRL publication interval') -Color 'White';

        # If delta CRL is disabled.
        if ($true -eq $DisableDeltaCRL)
        {
            # Write to log.
            Write-CustomLog -Message ('Disabling delta CRL' -f $DeltaUnit) -Level Verbose;

            # Set delta unit.
            $DeltaUnit = 0;

            # Set delta overlap unit.
            $DeltaOverlapUnits = 0;
        }

        # Construct arguments.
        [string]$unitArguments = ('-setreg ca\crlperiodunits {0}' -f $Unit);
        [string]$periodArguments = ('-setreg ca\crlperiod "{0}"' -f $Period);
        [string]$deltaUnitArguments = ('-setreg ca\crldeltaperiodunits {0}' -f $Unit);
        [string]$deltaPeriodArguments = ('-setreg ca\crldeltaperiod "{0}"' -f $Period);
        [string]$overlapPeriodArguments = ('-setreg ca\crloverlapperiod "{0}"' -f $OverlapPeriod);
        [string]$overlapUnitsArguments = ('-setreg ca\crloverlapunits {0}' -f $OverlapUnits);
        [string]$deltaOverlapPeriodArguments = ('-setreg ca\crldeltaoverlapperiod "{0}"' -f $DeltaOverlapPeriod);
        [string]$deltaOverlapUnitsArguments = ('-setreg ca\crldeltaoverlapunits {0}' -f $DeltaOverlapUnits);
        [string]$publishArguments = ('-crl');

        # Boolean to check if the CRL is changed.
        [bool]$crlChanged = $false;
    }
    PROCESS
    {
        # If unit is set.
        if ($null -ne $Unit)
        {
            # Write to log.
            Write-CustomLog -Message ('Setting CRL unit to {0}' -f $Unit) -Level Verbose;

            # Write to console.
            Write-Console -Message ('Setting CRL unit to "{0}"' -f $Unit) -Color 'White' -IndentLevel 1;

            # Change CRL unit.
            $null = Invoke-CertUtility -Arguments $unitArguments;

            # Set flag.
            $crlChanged = $true;
        }

        # If period is set.
        if ($null -ne $Period)
        {
            # Write to log.
            Write-CustomLog -Message ('Setting CRL period to {0}' -f $Period) -Level Verbose;

            # Write to console.
            Write-Console -Message ('Setting CRL period to "{0}"' -f $Period) -Color 'White' -IndentLevel 1;

            # Change CRL period.
            $null = Invoke-CertUtility -Arguments $periodArguments;

            # Set flag.
            $crlChanged = $true;
        }

        # If delta unit is set.
        if ($null -ne $DeltaUnit)
        {
            # Write to log.
            Write-CustomLog -Message ('Setting CRL delta unit to {0}' -f $DeltaUnit) -Level Verbose;

            # Write to console.
            Write-Console -Message ('Setting CRL delta unit to "{0}"' -f $DeltaUnit) -Color 'White' -IndentLevel 1;

            # Change CRL delta unit.
            $null = Invoke-CertUtility -Arguments $deltaUnitArguments;

            # Set flag.
            $crlChanged = $true;
        }

        # If delta period is set.
        if ($null -ne $DeltaPeriod)
        {
            # Write to log.
            Write-CustomLog -Message ('Setting CRL delta period to {0}' -f $DeltaPeriod) -Level Verbose;

            # Write to console.
            Write-Console -Message ('Setting CRL delta period to "{0}"' -f $DeltaPeriod) -Color 'White' -IndentLevel 1;

            # Change CRL delta period.
            $null = Invoke-CertUtility -Arguments $deltaPeriodArguments;

            # Set flag.
            $crlChanged = $true;
        }

        # If overlap period is set.
        if ($null -ne $OverlapPeriod)
        {
            # Write to log.
            Write-CustomLog -Message ('Setting CRL overlap period to {0}' -f $OverlapPeriod) -Level Verbose;

            # Write to console.
            Write-Console -Message ('Setting CRL overlap period to "{0}"' -f $OverlapPeriod) -Color 'White' -IndentLevel 1;

            # Change CRL overlap period.
            $null = Invoke-CertUtility -Arguments $overlapPeriodArguments;

            # Set flag.
            $crlChanged = $true;
        }

        # If overlap units is set.
        if ($null -ne $OverlapUnits)
        {
            # Write to log.
            Write-CustomLog -Message ('Setting CRL overlap units to {0}' -f $OverlapUnits) -Level Verbose;

            # Write to console.
            Write-Console -Message ('Setting CRL overlap units to "{0}"' -f $OverlapUnits) -Color 'White' -IndentLevel 1;

            # Change CRL overlap units.
            $null = Invoke-CertUtility -Arguments $overlapUnitsArguments;

            # Set flag.
            $crlChanged = $true;
        }

        # If delta overlap period is set.
        if ($null -ne $DeltaOverlapPeriod)
        {
            # Write to log.
            Write-CustomLog -Message ('Setting CRL delta overlap period to {0}' -f $DeltaOverlapPeriod) -Level Verbose;

            # Write to console.
            Write-Console -Message ('Setting CRL delta overlap period to "{0}"' -f $DeltaOverlapPeriod) -Color 'White' -IndentLevel 1;

            # Change CRL delta overlap period.
            $null = Invoke-CertUtility -Arguments $deltaOverlapPeriodArguments;

            # Set flag.
            $crlChanged = $true;
        }

        # If delta overlap units is set.
        if ($null -ne $DeltaOverlapUnits)
        {
            # Write to log.
            Write-CustomLog -Message ('Setting CRL delta overlap units to {0}' -f $DeltaOverlapUnits) -Level Verbose;

            # Write to console.
            Write-Console -Message ('Setting CRL delta overlap units to "{0}"' -f $DeltaOverlapUnits) -Color 'White' -IndentLevel 1;

            # Change CRL delta overlap units.
            $null = Invoke-CertUtility -Arguments $deltaOverlapUnitsArguments;

            # Set flag.
            $crlChanged = $true;
        }

        # If restart flag is set.
        if ($true -eq $Restart)
        {
            # Write to console.
            Write-Console -Message ('Restarting service after CRL change') -Color 'White' -IndentLevel 1;

            # If CRL is changed.
            if ($true -eq $crlChanged)
            {
                # Write to log.
                Write-CustomLog -Message ('Restarting service after CRL change') -Level Verbose;

                # Restart the ADCS service.
                Stop-ADCSService;
                Start-ADCSService;

                # Write to log.
                Write-CustomLog -Message ('Service restarted, waiting 2 seconds before continuing') -Level Verbose;

                # Sleep for 2 seconds.
                Start-Sleep -Seconds 2;
            }
            # Else restart required.
            else
            {
                # Write to log.
                Write-CustomLog -Message ('CRL settings not changed, restart not required') -Level Verbose;
            }
        }
        # Else no restart.
        elseif ($false -eq $Restart -and $true -eq $crlChanged)
        {
            # Write to console.
            Write-Console -Message ('Service restart is required after changing CRL') -Color 'Yellow' -IndentLevel 1;

            # Write to log.
            Write-CustomLog -Message ('Service restart is required after changing CRL') -Level Warning;
        }

        # If publish flag is set.
        if ($true -eq $Publish)
        {
            # Try to publish.
            try
            {
                # Publish the CRL.
                $null = Invoke-CertUtility -Arguments $publishArguments -ErrorAction Stop;

                # Write to console.
                Write-Console -Message ("Succesfully published CRL to 'C:\Windows\System32\CertSrv\CertEnroll'") -Color 'White' -IndentLevel 1;
            }
            catch
            {
                # Write to console.
                Write-Console -Message ('Failed to publish CRL') -Color 'Red' -IndentLevel 1;

                # Throw execption.
                Write-CustomLog -Level Error -Message ('Failed to publish CRL');
            }
        }
    }
    END
    {
        # Return.
        return;
    }
}

function Get-ADCSCrlPublicationInterval
{
    <#
    .SYNOPSIS
        Get the CRL publication intervals.
    .DESCRIPTION
        Use certutil to set the CRL publication interval.
    .EXAMPLE
        Get-ADCSCrlPublicationInterval;
    #>
    [cmdletbinding()]
    [OutputType([PSCustomObject])]
    param
    (
    )

    BEGIN
    {
        # Write to log.
        Write-CustomLog -Message ('Getting CRL publication intervals') -Level Verbose;

        # Write to console.
        Write-Console -Message ('Getting CRL publication intervals') -Color 'White';

        # Get the active certificate authority.
        $activeAuthority = Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration' -Name 'Active';
    }
    PROCESS
    {
        # If active authority is not set.
        if ([string]::IsNullOrEmpty($activeAuthority))
        {
            # Throw execption.
            Write-CustomLog -Level Error -Message ('No active certificate authority found at "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration" in the key "Active"');
        }

        # Get the CRL publication intervals.
        [string]$crlDeltaOverlapPeriod = Get-ItemPropertyValue -Path ('HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\{0}' -f $activeAuthority) -Name 'CRLDeltaOverlapPeriod';
        [int]$crlDeltaOverlapUnits = Get-ItemPropertyValue -Path ('HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\{0}' -f $activeAuthority) -Name 'CRLDeltaOverlapUnits';
        [string]$crlDeltaPeriod = Get-ItemPropertyValue -Path ('HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\{0}' -f $activeAuthority) -Name 'CRLDeltaPeriod';
        [int]$crlDeltaPeriodUnits = Get-ItemPropertyValue -Path ('HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\{0}' -f $activeAuthority) -Name 'CRLDeltaPeriodUnits';
        [string]$crlOverlapPeriod = Get-ItemPropertyValue -Path ('HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\{0}' -f $activeAuthority) -Name 'CRLOverlapPeriod';
        [int]$crlOverlapUnits = Get-ItemPropertyValue -Path ('HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\{0}' -f $activeAuthority) -Name 'CRLOverlapUnits';
        [string]$crlPeriod = Get-ItemPropertyValue -Path ('HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\{0}' -f $activeAuthority) -Name 'CRLPeriod';
        [int]$crlUnits = Get-ItemPropertyValue -Path ('HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\{0}' -f $activeAuthority) -Name 'CRLPeriodUnits';

        # Construct CRL publication intervals object.
        $crlPublicationIntervals = [PSCustomObject]@{
            CRLDeltaOverlapPeriod = $crlDeltaOverlapPeriod;
            CRLDeltaOverlapUnits  = $crlDeltaOverlapUnits;
            CRLDeltaPeriod        = $crlDeltaPeriod;
            CRLDeltaPeriodUnits   = $crlDeltaPeriodUnits;
            CRLOverlapPeriod      = $crlOverlapPeriod;
            CRLOverlapUnits       = $crlOverlapUnits;
            CRLPeriod             = $crlPeriod;
            CRLPeriodUnits        = $crlUnits;
        };

        # Write to console.
        Write-Console -Message ("CRLDeltaOverlapPeriod is set to '{0}'" -f $crlDeltaOverlapPeriod) -Color 'White' -IndentLevel 1;
        Write-Console -Message ("CRLDeltaOverlapUnits is set to '{0}'" -f $crlDeltaOverlapUnits) -Color 'White' -IndentLevel 1;
        Write-Console -Message ("CRLDeltaPeriod is set to '{0}'" -f $crlDeltaPeriod) -Color 'White' -IndentLevel 1;
        Write-Console -Message ("CRLDeltaPeriodUnits is set to '{0}'" -f $crlDeltaPeriodUnits) -Color 'White' -IndentLevel 1;
        Write-Console -Message ("CRLOverlapPeriod is set to '{0}'" -f $crlOverlapPeriod) -Color 'White' -IndentLevel 1;
        Write-Console -Message ("CRLOverlapUnits is set to '{0}'" -f $crlOverlapUnits) -Color 'White' -IndentLevel 1;
        Write-Console -Message ("CRLPeriod is set to '{0}'" -f $crlPeriod) -Color 'White' -IndentLevel 1;
        Write-Console -Message ("CRLPeriodUnits is set to '{0}'" -f $crlUnits) -Color 'White' -IndentLevel 1;

        # Write to log.
        Write-CustomLog -Message ('CRL publication intervals: {0}' -f $crlPublicationIntervals) -Level Verbose;
    }
    END
    {
        # Return CRL publication intervals.
        return $crlPublicationIntervals;
    }
}

function Start-ADCSDatabaseDefagmentation
{
    <#
    .SYNOPSIS
        Defragment the Active Directory Certificate Services database.
    .DESCRIPTION
        Use esentutl to defragment the ADCS database.
    .EXAMPLE
        Start-ADCSDatabaseDefagmentation;
    #>
    [cmdletbinding()]
    [OutputType([void])]
    param
    (
        # Database file location.
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$DatabaseFile
    )

    BEGIN
    {
        # Write to console.
        Write-Console -Message ('Starting defragmenting the ADCS database') -Color 'White';

        # Construct arguments.
        [string]$arguments = ('/d "{0}"' -f $DatabaseFile);
    }
    PROCESS
    {
        # ADCS service need to be stopped.
        $serviceStatus = Get-ADCSService;

        # If service is running.
        if ($serviceStatus.Status -eq 'Running')
        {
            # Write to log.
            Write-CustomLog -Message ('ADCS service need to be stopped prior running defragmentation') -Level Warning;

            # Write to console.
            Write-Console -Message ('ADCS service need to be stopped prior running defragmentation') -Color 'Yellow' -IndentLevel 1;

            # Break function.
            return;
        }

        # Try to defragment the database.
        try
        {
            # Write to log.
            Write-CustomLog -Message ('Trying to defragment the ADCS database') -Level Verbose;

            # Defragment the database.
            $null = Invoke-EsentUtility -Arguments $arguments;

            # Write to log.
            Write-CustomLog -Message ('Successfully defragmented the ADCS database') -Level Verbose;

            # Write to console.
            Write-Console -Message ('Successfully defragmented the ADCS database') -Color 'White' -IndentLevel 1;
        }
        # Something went wrong.
        catch
        {
            # Write to console.
            Write-Console -Message ('Failed to defragment the ADCS database') -Color 'Red' -IndentLevel 1;

            # Throw execption.
            Write-CustomLog -Level Error -Message ('Failed to defragment the ADCS database. {0}' -f $_.Exception.Message);
        }
    }
    END
    {
        # Return.
        return;
    }
}

function Get-DiskSpace
{
    <#
    .SYNOPSIS
        Get the disk space of a drive.
    .DESCRIPTION
        Uses WMI to get drive space.
    .PARAMETER Drive
        Drive letter to get disk space from.
    .EXAMPLE
        Get-DiskSpace -Drive 'C';
    #>
    [cmdletbinding()]
    [OutputType([PSCustomObject])]
    param
    (
        # Drive letter.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Drive = 'C'
    )

    BEGIN
    {
        # Get drive info.
        $driveInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter ('DeviceID="{0}:"' -f $Drive);
    }
    PROCESS
    {
        # Construct disk space object.
        $diskSpace = [PSCustomObject]@{
            DriveLetter = $driveInfo.DeviceID;
            VolumeName  = $driveInfo.VolumeName;
            FreeSpace   = $driveInfo.FreeSpace;
            TotalSpace  = $driveInfo.Size;
        };
    }
    END
    {
        # Return disk space.
        return $diskSpace;
    }
}

function Get-ADCSDatabaseSize
{
    <#
    .SYNOPSIS
        Get the size of the Active Directory Certificate Services database.
    .DESCRIPTION
        Return used space in bytes.
    .EXAMPLE
        Get-ADCSDatabaseSize;
    #>
    [cmdletbinding()]
    [OutputType([PSCustomObject])]
    param
    (
    )

    BEGIN
    {
        # Get database locations.
        $databaseLocations = Get-ADCSDatabaseLocation;

        # Size.
        [long]$size = 0;
    }
    PROCESS
    {
        # Write to log.
        Write-CustomLog -Message ("Getting size of the ADCS database from folder '{0}'" -f $databaseLocations.DatabaseFolder) -Level Verbose;

        # Get size of database folder.
        $size += Get-ChildItem -Path $databaseLocations.DatabaseFolder | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum;

        # If the log path is not under database.
        if ($databaseLocations.LogFolder -notlike $databaseLocations.DatabaseFolder)
        {
            # Write to log.
            Write-CustomLog -Message ("Getting size of the ADCS log from folder '{0}'" -f $databaseLocations.LogFolder) -Level Verbose;

            # Get size of log folder.
            $size += Get-ChildItem -Path $databaseLocations.LogFolder | Measure-Object -Property Length | Select-Object -ExpandProperty Sum;
        }
        # Else log path is in the same folder.
        else
        {
            # Write to log.
            Write-CustomLog -Message ("Skipping getting log folder size, because it's in the same folder path as database '{0}'" -f $databaseLocations.LogFolder) -Level Verbose;
        }
    }
    END
    {
        # Write to log.
        Write-CustomLog -Message ("The size of the ADCS database is '{0}' bytes ({1:N0} MB)" -f $size, ($size / 1MB)) -Level Verbose;

        # Write to console.
        Write-Console -Message ("The size of the ADCS database is '{0}' bytes ({1:N0} MB)" -f $size, ($size / 1MB)) -Color 'White' -IndentLevel 1;

        # Return size.
        return $size;
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-CustomLog -Message ("Starting script '{0}' executed by '{1}'. Exporting output to file '{2}'" -f $MyInvocation.MyCommand , $env:USERNAME, $Global:logFilePath) -Level Verbose;
Write-CustomLog -Message ('Parameters used:') -Level Verbose;
$PSBoundParameters.Keys | ForEach-Object {
    Write-CustomLog -Message "$_ = $($PSBoundParameters.Item($_))" -Level Verbose;
};

# Write to console.
Write-Console -Message ('Starting maintenance job') -Color 'White';
Write-Console -Message ("Log file is available at '{0}'" -f $Global:logFilePath) -Color 'White' -IndentLevel 1;

# Test if user is local admin.
$isLocalAdmin = Test-IsLocalAdmin;

# If user is not local admin.
if ($false -eq $isLocalAdmin)
{
    # Write to log.
    Write-CustomLog -Message 'This script need to be executed with elevated permissions. Aborting script' -Level Verbose;

    # Write to console.
    Write-Console -Message 'This script need to be executed with elevated permissions. Aborting script' -Color 'Red';

    # Exit script.
    exit 1;
}

# Test if certutil is available.
$certUtilPresent = Test-CertUtilPresent;

# If certutil is not available.
if ($false -eq $certUtilPresent)
{
    # Write to log.
    Write-CustomLog -Message 'The "C:\Windows\system32\certutil.exe" program is not available. Aborting script' -Level Verbose;

    # Write to console.
    Write-Console -Message 'The "C:\Windows\system32\certutil.exe" program is not available. Aborting script' -Color 'Red';

    # Exit script.
    exit 1;
}

# Test if esentutl is available.
$esentUtilPresent = Test-EsentUtilPresent;

# If esentutl is not available.
if ($false -eq $esentUtilPresent)
{
    # Write to log.
    Write-CustomLog -Message 'The "C:\Windows\system32\esentutl.exe" program is not available. Aborting script' -Level Verbose;

    # Write to console.
    Write-Console -Message 'The "C:\Windows\system32\esentutl.exe" program is not available. Aborting script' -Color 'Red';

    # Exit script.
    exit 1;
}

# If ADCS service is available.
$adcsService = Get-ADCSService -ErrorAction SilentlyContinue;

# If ADCS service is not available.
if ($null -eq $adcsService)
{
    # Write to log.
    Write-CustomLog -Message 'The Active Directory Certificate Services service is not available. Aborting script' -Level Warning;

    # Write to console.
    Write-Console -Message 'The Active Directory Certificate Services service is not available. Aborting script' -Color 'Red';

    # Exit script.
    exit 1;
}
# Else if the service is not running.
elseif ($adcsService.Status -eq 'Stopped')
{
    # Try to start the service.
    Start-ADCSService -ErrorAction Stop;
}

# If backup should be initiated.
if ($true -eq $Backup)
{
    # Backup database.
    $backupPath = Backup-ADCSDatabase -Path $BackupPath -PrivateKey:$BackupPrivateKey;
}

# If expired certificates should be removed.
if ($true -eq $RemoveExpiredCertificate)
{
    # Get datetime threshold.
    [datetime]$RemoveExpiredDate = (Get-Date).AddDays(-$ExpiredCertificateDayThreshold);

    # Remove expired certificates.
    $removedCertificates = Remove-ADCSCerticateExpired -ExpireDate $RemoveExpiredDate;
}

# If the database should be defragmented.
if ($true -eq $DefragmentDatabase)
{
    # Get CRL publication intervals.
    $crlPublicationIntervals = Get-ADCSCrlPublicationInterval;

    # Write to log.
    Write-CustomLog -Message ("Exporting CRL publication intervals to '{0}' (just-in-case)" -f $crlPublicationConfigPath) -Level Verbose;

    # Write to console.
    Write-Console -Message ("Exporting CRL publication intervals to '{0}'" -f $crlPublicationConfigPath) -Color 'White' -IndentLevel 1;

    # Export the CRL publication intervals.
    $crlPublicationIntervals | Export-Csv -Path $crlPublicationConfigPath -NoTypeInformation -Encoding UTF8 -Delimiter ';' -Force;

    # If the CRL publication intervals should be extended.
    if ($true -eq $ExtendCrlLifeTime)
    {
        # Extend CRL publication intervals.
        Set-ADCSCrlPublicationInterval `
            -Unit $ExtendCrlDays `
            -Period 'Days' `
            -DeltaUnit 0 `
            -OverlapUnits 0 `
            -DeltaOverlapUnit 0 `
            -Publish `
            -Restart;
    }

    # Get database location.
    $databaseLocations = Get-ADCSDatabaseLocation;

    # Stop the ADCS service.
    Stop-ADCSService;

    # Defragment the database.
    Start-ADCSDatabaseDefagmentation -DatabaseFile $databaseLocations.DatabaseFile;

    # Start the ADCS service.
    Start-ADCSService;

    # If the CRL publication intervals was extended.
    if ($true -eq $ExtendCrlLifeTime)
    {
        # Revert the CRL publication intervals and restart service.
        Set-ADCSCrlPublicationInterval `
            -Unit $crlPublicationIntervals.CRLPeriodUnits `
            -Period $crlPublicationIntervals.CRLPeriod `
            -DeltaUnit $crlPublicationIntervals.CRLDeltaPeriodUnits `
            -DeltaPeriod $crlPublicationIntervals.CRLDeltaPeriod `
            -OverlapUnits $crlPublicationIntervals.CRLOverlapUnits `
            -OverlapPeriod $crlPublicationIntervals.CRLOverlapPeriod `
            -DeltaOverlapPeriod $crlPublicationIntervals.CRLDeltaOverlapPeriod `
            -DeltaOverlapUnits $crlPublicationIntervals.CRLDeltaOverlapUnits `
            -Publish `
            -Restart;
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-CustomLog -Message ("Finished script '{0}' executed by '{1}'. Log file cant be found at '{2}'" -f $MyInvocation.MyCommand , $env:USERNAME, $Global:logFilePath) -Level Verbose;

# Write to console.
Write-Console -Message ('Finsihed maintenance job') -Color 'White';
Write-Console -Message ("Log file is available at '{0}'" -f $Global:logFilePath) -Color 'White' -IndentLevel 1;

############### Finalize - End ###############
#endregion
