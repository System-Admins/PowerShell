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
    .PARAMETER IndentLevel
        (Optional) Indent level (only works when the level is console).
    .PARAMETER Color
        (Optional) Color of the message (only works when the level is console).
    .EXAMPLE
        # Write a information message to the console.
        Write-MyLog -Message 'This is an information message'
    .EXAMPLE
        # Write a debug message to a log file and console.
        Write-CustomLog -Message 'This is a debug message' -Path 'C:\Temp\log.txt' -Level Verbose
    .EXAMPLE
        # Write an error message to a log file but not to the console.
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level Error
    .EXAMPLE
        # Write an information message to a log file but not to the console and do not append to the log file.
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level 'Information' -NoAppend
    .EXAMPLE
        # Write an information message to the console with indentlevel 1 and the color green.
        Write-CustomLog -Message 'Some output here' -Level 'Console' -IndentLevel 1 -Color 'Green'
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
        [string]$Path = $script:logFilePath,

        # (Optional) Log level.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Console', 'Error', 'Warning', 'Information', 'Debug', 'Verbose')]
        [string]$Level = 'Information',

        # (Optional) If date and time should not be added to the log message.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoDateTime,

        # (Optional) If the log message should not be appended to the log file.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoAppend,

        # (Optional) If the log level should not be logged.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [bool]$NoLogLevel = $false,

        # (Optional) If the log message should not be added to a file.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]$NoLogFile,

        # (Optional) Indent level (only works when the level is console).
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]$IndentLevel = 0,

        # (Optional) Color of the message (only works when the level is console).
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Green', 'Red', 'Yellow', 'White', 'Black')]
        [string]$Color = 'White'
    )

    BEGIN
    {
        # Store original preferences.
        $originalInformationPreference = $InformationPreference;

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
                Write-Error -Message $logMessage -ErrorAction Stop;
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
            'Console'
            {
                # Prefix meessage.
                [string]$prefixMessage = '';

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

                # Write to console.
                Write-Host -Object $prefixMessage -NoNewline;
                Write-Host -Object $Message -ForegroundColor $Color;
            }
        }

        # If output should be written to file.
        if ($true -eq $outputToFile)
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
    }
    END
    {
        # Restore original preferences.
        $InformationPreference = $originalInformationPreference;
    }
}
