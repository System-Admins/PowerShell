#Requires -Version 5.1;

<#
.SYNOPSIS
    Decode a Certificate Signing Request (CSR) file.

.DESCRIPTION
    Decode a Certificate Signing Request (CSR) file and display the content of the CSR file.
    This script uses the certutil.exe and .NET assemblies to decode the CSR file.

.Parameter FilePath
    Path to the Certificate Signing Request (CSR) file.

.Parameter ReturnObject
    If the object should be returned.

.EXAMPLE
    # Decode the CSR file and display the content.
    .\Decode-CertificateSigningRequest.ps1 -FilePath 'C:\temp\certificate.csr';

.EXAMPLE
    # Decode the CSR file and return the object.
    $csr = .\Decode-CertificateSigningRequest.ps1 -FilePath 'C:\temp\certificate.csr' -ReturnObject;

.NOTES
  Version:        1.0
  Author:         Alex Hansen (zorh@novonordisk.com)
  Creation Date:  05-09-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]
[OutputType([PSCustomObject])]
param
(
    # Path for the certificate signing request file.
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [string]$FilePath,

    # If the object should be returned.
    [Parameter(Mandatory = $false)]
    [switch]$ReturnObject
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
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level Error
    .EXAMPLE
        # Write an information message to a log file but not to the console and do not append to the log file.
        Write-CustomLog -Message 'This is an error message' -Path 'C:\Temp\log.txt' -Level 'Information' -NoAppend
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
        [switch]$NoLogLevel = $true,

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

function Get-Hash
{
    [cmdletbinding()]
    [OutputType([PSCustomObject])]
    param
    (
        # File path.
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$FilePath
    )

    BEGIN
    {
        # Path to certutil.exe.
        $certutilPath = 'C:\Windows\System32\certutil.exe';

        # If certutil.exe don't exist.
        if (!(Test-Path -Path $certutilPath -PathType Leaf))
        {
            # Throw exception.
            throw ('Did not find the certutil.exe executable at path: {0}' -f $certutilPath);
        }

        # If file don't exist.
        if (!(Test-Path -Path $FilePath -PathType Leaf))
        {
            # Throw exception.
            throw ('Did not find the file at path: {0}' -f $FilePath);
        }

        # Object for the hashes.
        $csrHash = [PSCustomObject]@{
            SHA1 = $null;
            MD5  = $null;
        };
    }
    PROCESS
    {
        # Try to execute the certutil.exe command.
        try
        {
            # Write to log.
            Write-CustomLog -Message ("Trying to dump CSR '{0}' with certutil.exe" -f $FilePath) -Level Verbose;

            # Dump the CSR.
            $csrDump = & $certutilPath -dump $FilePath;

            # Write to log.
            Write-CustomLog -Message ("Successfully dumped CSR '{0}' with certutil.exe" -f $FilePath) -Level Verbose;
        }
        # Something went wrong while executing the certutil.exe command.
        catch
        {
            # Throw exception.
            throw ('Failed to dump the CSR file. Error: {0}' -f $_.Exception.Message);
        }

        # Foreach line in the dump.
        foreach ($line in $csrDump)
        {
            # Extract the Name Hash MD5
            if ($line -match '^\s*Name Hash\(md5\):\s*([0-9a-fA-F]+)$')
            {
                # Write to log.
                Write-Output ("MD5 hash is '{0}'" -f $matches[1])
                # Extract the MD5 hash
                $csrHash.MD5 = $matches[1]
            }

            # Extract the Name Hash SHA1.
            if ($line -match '^\s*Name Hash\(sha1\):\s*([0-9a-fA-F]+)$')
            {
                # Write to log.
                Write-Output ("SHA1 hash is '{0}'" -f $matches[1])
                # Extract the SHA1 hash
                $csrHash.SHA1 = $matches[1]
            }
        }
    }
    END
    {
        # Return hashes.
        return $csrHash;
    }
}

function Get-SubjectAlternativeName
{
    [cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
        # File path.
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$FilePath
    )

    BEGIN
    {
        # Path to certutil.exe.
        $certutilPath = 'C:\Windows\System32\certutil.exe';

        # If certutil.exe don't exist.
        if (!(Test-Path -Path $certutilPath -PathType Leaf))
        {
            # Throw exception.
            throw ('Did not find the certutil.exe executable at path: {0}' -f $certutilPath);
        }

        # If file don't exist.
        if (!(Test-Path -Path $FilePath -PathType Leaf))
        {
            # Throw exception.
            throw ('Did not find the file at path: {0}' -f $FilePath);
        }

        # Object array for the SAN.
        $subjectAlternativeNames = New-Object System.Collections.ArrayList;
    }
    PROCESS
    {
        # Try to execute the certutil.exe command.
        try
        {
            # Write to log.
            Write-CustomLog -Message ("Trying to dump CSR '{0}' with certutil.exe" -f $FilePath) -Level Verbose;

            # Dump the CSR.
            $csrDump = & $certutilPath -dump $FilePath;

            # Write to log.
            Write-CustomLog -Message ("Successfully dumped CSR '{0}' with certutil.exe" -f $FilePath) -Level Verbose;
        }
        # Something went wrong while executing the certutil.exe command.
        catch
        {
            # Throw exception.
            throw ('Failed to dump the CSR file. Error: {0}' -f $_.Exception.Message);
        }

        # Foreach line in the dump.
        foreach ($line in $csrDump)
        {
            # Check if the line indicates the start of the SAN section.
            if ($line -match 'Subject Alternative Name')
            {
                # Set the SAN section flag to true.
                $sanSection = $true;

                # Skip the current line.
                continue;
            }

            # If we are in the SAN section, extract the SAN values.
            if ($sanSection)
            {
                # Check if the line contains a DNS Name.
                if ($line -match '^\s*DNS Name=(.*)$')
                {
                    # Extract the DNS Name.
                    $subjectAlternativeName = $matches[1];

                    # Write to log.
                    Write-CustomLog -Message ("Found DNS domain '{0}'" -f $subjectAlternativeName) -Level Verbose;

                    # Add the DNS Name to the SAN array.
                    $null = $subjectAlternativeNames.Add($subjectAlternativeName);
                }
                # Exit the SAN section if another section starts.
                if ($line -match '^\s*$')
                {
                    # Set the SAN section flag to false.
                    $sanSection = $false;
                }
            }
        }
    }
    END
    {
        # Write to log.
        Write-CustomLog -Message ("Found {0} subject alternative names in the file '{1}'" -f $subjectAlternativeNames.Count, $FilePath) -Level Verbose;

        # Return the SAN array.
        return $subjectAlternativeNames;
    }
}

function Get-ApplicationPolicy
{
    [cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
        # File path.
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$FilePath
    )

    BEGIN
    {
        # Path to certutil.exe.
        $certutilPath = 'C:\Windows\System32\certutil.exe';

        # If certutil.exe don't exist.
        if (!(Test-Path -Path $certutilPath -PathType Leaf))
        {
            # Throw exception.
            throw ('Did not find the certutil.exe executable at path: {0}' -f $certutilPath);
        }

        # If file don't exist.
        if (!(Test-Path -Path $FilePath -PathType Leaf))
        {
            # Throw exception.
            throw ('Did not find the file at path: {0}' -f $FilePath);
        }

        # Object array for the policies.
        $appPolicies = New-Object System.Collections.ArrayList;
    }
    PROCESS
    {
        # Try to execute the certutil.exe command.
        try
        {
            # Write to log.
            Write-CustomLog -Message ("Trying to dump CSR '{0}' with certutil.exe" -f $FilePath) -Level Verbose;

            # Dump the CSR.
            $csrDump = & $certutilPath -dump $FilePath;

            # Write to log.
            Write-CustomLog -Message ("Successfully dumped CSR '{0}' with certutil.exe" -f $FilePath) -Level Verbose;
        }
        # Something went wrong while executing the certutil.exe command.
        catch
        {
            # Throw exception.
            throw ('Failed to dump the CSR file. Error: {0}' -f $_.Exception.Message);
        }

        # Iterate through the lines of the CSR dump.
        foreach ($line in $csrDump)
        {
            # Check if the line indicates the start of the Application Policies section
            if ($line -match 'Application Policies')
            {
                # Set the flag to indicate that we are in the Application Policies section.
                $appPoliciesSection = $true;

                # Skip the line that indicates the start of the section.
                continue;
            }

            # If we are in the Application Policies section, extract the policies
            if ($appPoliciesSection)
            {
                # Exit the Application Policies section if another section starts
                if ($line -match '^\s*$')
                {
                    # Reset the flag to indicate that we are no longer in the Application Policies section.
                    $appPoliciesSection = $false;

                    # Skip the empty line.
                    continue;
                }

                # Extract the Application Policy
                if ($line -match '^\s*\[\d+\]Application Certificate Policy:\s*$')
                {
                    # Skip the line that indicates the start of the policy.
                    continue;
                }

                # Extract the Policy Identifier
                if ($line -match '^\s*Policy Identifier=(.*)$')
                {
                    # Extract the policy name.
                    $policyName = $matches[1].Trim();

                    # Write to log.
                    Write-CustomLog -Message ("Found application policy '{0}'" -f $policyName) -Level Verbose;

                    # Add the policy name to the list of Application Policies.
                    $null = $appPolicies.Add($policyName);
                }
            }
        }
    }
    END
    {
        # Write to log.
        Write-CustomLog -Message ("Found {0} application policies in the file '{1}'" -f $appPolicies.Count, $FilePath) -Level Verbose;

        # Return policies.
        return $appPolicies;
    }
}

function Write-CsrToScreen
{
    [cmdletbinding()]
    [OutputType([void])]
    param
    (
        # CSR object.
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        $CertificateSigningRequest
    )

    BEGIN
    {
    }
    PROCESS
    {
        # If subject is empty.
        if ([string]::IsNullOrEmpty($CertificateSigningRequest.Subject))
        {
            # Write to log.
            Write-CustomLog -Message ('Subject: <empty>') -Level Console -Color Yellow;
            Write-CustomLog -Message ("It's best practice that the subject is not empty") -Level Console -IndentLevel 1;
        }
        # Else subject is not empty.
        else
        {
            # Write to log.
            Write-CustomLog -Message ('Subject: {0}' -f $CertificateSigningRequest.Subject) -Level Console;
        }

        # If the hash algorithm is sha1.
        if ($CertificateSigningRequest.HashAlgorithm.FriendlyName -eq 'sha1')
        {
            # Write to log.
            Write-CustomLog -Message ('Hash Algorithm: {0}' -f $CertificateSigningRequest.HashAlgorithm) -Level Console -Color Red;
            Write-CustomLog -Message ("It's best practice that the hash algorithm is not sha1") -Level Console -IndentLevel 1;
        }
        # Else the hash algorithm is not sha1.
        else
        {
            # Write to log.
            Write-CustomLog -Message ('Hash Algorithm: {0}' -f $CertificateSigningRequest.HashAlgorithm) -Level Console;
        }

        # Write to log.
        Write-CustomLog -Message ('Public Key Algorithm: {0}' -f $CertificateSigningRequest.PublicKeyAlgorithm) -Level Console;

        # If the key size is lower than 2048-bit.
        if ([int]$CertificateSigningRequest.KeySize -lt 2048)
        {
            # Write to log.
            Write-CustomLog -Message ('Key Size: {0}' -f $CertificateSigningRequest.KeySize) -Level Console -Color Yellow;
            Write-CustomLog -Message ('The key size should be at least 2048-bit or higher') -Level Console -IndentLevel 1;
        }
        # Else the key size is 2048-bit or higher.
        else
        {
            # Write to log.
            Write-CustomLog -Message ('Key Size: {0}' -f $CertificateSigningRequest.KeySize) -Level Console;
        }

        # If the subject alternative names is empty.
        if ($CertificateSigningRequest.SubjectAlternativeNames.Count -eq 0)
        {
            # Write to log.
            Write-CustomLog -Message ('Subject Alternative Names: <empty>') -Level Console;
        }
        # Else the subject alternative names is not empty.
        else
        {
            # Write to log.
            Write-CustomLog -Message ('Subject Alternative Names:') -Level Console;

            # Foreach subject alternative name.
            foreach ($subjectAlternativeName in $CertificateSigningRequest.SubjectAlternativeNames)
            {
                # Write to log.
                Write-CustomLog -Message ('{0}' -f $subjectAlternativeName) -Level Console -IndentLevel 1;

                # If the subject alternative name is a wildcard.
                if ($subjectAlternativeName -match '^\*\..*')
                {
                    # Write to log.
                    Write-CustomLog -Message ('The subject alternative name is a wildcard, this is not best practice') -Level Console -IndentLevel 2 -Color Red;
                }
            }
        }

        # Write to log.
        Write-CustomLog -Message ('MD5 hash: {0}' -f $CertificateSigningRequest.MD5Hash) -Level Console;
        Write-CustomLog -Message ('SHA1 hash: {0}' -f $CertificateSigningRequest.SHA1Hash) -Level Console;

        # If the application policies is empty.
        if ($CertificateSigningRequest.ApplicationPolicy.Count -eq 0)
        {
            # Write to log.
            Write-CustomLog -Message ('Application Policies: <empty>') -Level Console;
            Write-CustomLog -Message ('A policy should be set using best practice') -Level Console -IndentLevel 1 -Color Yellow;
        }
        # Else the application policies is not empty.
        else
        {
            # Write to log.
            Write-CustomLog -Message ('Application Policies:') -Level Console;

            # Foreach application policy.
            foreach ($applicationPolicy in $CertificateSigningRequest.ApplicationPolicy)
            {
                # Write to log.
                Write-CustomLog -Message ('{0}' -f $applicationPolicy) -Level Console -IndentLevel 1;
            }
        }
    }
    END
    {
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get file.
$file = Get-Item -Path $FilePath;

# If extension is not CSR or CER.
if (!
    (
        $file.Extension -eq '.csr' -or
        $file.Extension -eq '.cer' -or
        $file.Extension -eq '.req'
    )
)
{
    # Throw execption.
    throw ('The file extension is not valid. The file extension must be .csr or .cer.');
}
# Else the extension is correct.
else
{
    # Write to log.
    Write-CustomLog -Message ("File '{0}' have the correct format" -f $FilePath) -Level Verbose;
}

# Write to log.
Write-CustomLog -Message ("Retrieving the content of file '{0}'" -f $FilePath) -Level Verbose;

# Read the CSR file content
$csrContent = Get-Content -Path $FilePath -Raw;

# Crate a new X509enrollment.CX509CertificateRequestPkcs10 object.
$x509CertificateRequest = New-Object -ComObject X509enrollment.CX509CertificateRequestPkcs10;

# Try to decode the CSR content.
try
{
    # Write to log.
    Write-CustomLog -Message ('Trying to decode CSR' -f $FilePath) -Level Verbose;

    # Initialize the object with the CSR content.
    $x509CertificateRequest.InitializeDecode($csrContent, 6);

    # Write to log.
    Write-CustomLog -Message ('Successfully decoded CSR' -f $FilePath) -Level Verbose;
}
# Something went wrong while decoding CSR content.
catch
{
    # Throw exception.
    throw ('Failed to decode the CSR content. Error: {0}' -f $_.Exception.Message);
}

# Create a new object to store the decoded CSR content.
$certificateSigningRequest = New-Object -TypeName PSObject;

# Add the decoded CSR content to the object.
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'Subject' -Value $x509CertificateRequest.Subject.Name;
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'HashAlgorithm' -Value $x509CertificateRequest.HashAlgorithm.FriendlyName;
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'TemplateName' -Value $x509CertificateRequest.TemplateObjectId.FriendlyName;
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'TemplateId' -Value $x509CertificateRequest.TemplateObjectId.Value;
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'PublicKeyAlgorithm' -Value ('{0} ({1})' -f $x509CertificateRequest.PublicKey.Algorithm.FriendlyName, $x509CertificateRequest.PublicKey.Algorithm.Value);
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'PublicKeyEncoded' -Value $x509CertificateRequest.PublicKey.EncodedKey();
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'KeySize' -Value $x509CertificateRequest.PublicKey.Length;
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'SignatureEncoded' -Value $x509CertificateRequest.Signature();

# X509 extensions.
$x509Extensions = @();

# Foreach X509 extension.
foreach ($x509Extension in $x509CertificateRequest.X509Extensions)
{
    # Add the extension to the object.
    $x509Extensions += ('{0} ({1})' -f $x509Extension.ObjectId.FriendlyName, $x509Extension.ObjectId.Value);
}

# Add the critical extensions to the array.
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'X509Extensions' -Value $x509Extensions;

# Critial extensions object.
$criticalExtensions = @();

# Foreach X509 critical extension.
foreach ($x509CriticalExtension in $x509CertificateRequest.CriticalExtensions)
{
    # Add the critical extension to the array.
    $criticalExtensions += ('{0} ({1})' -f $x509CriticalExtension.FriendlyName, $x509CriticalExtension.Value);
}

# Add the critical extensions to the object.
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'CriticalExtensions' -Value $criticalExtensions;

# Crypt attributes object.
$cryptAttributes = @();

# Foreach crypt attribute.
foreach ($cryptAttribute in $x509CertificateRequest.CryptAttributes)
{
    # Add the crypt attribute to the array.
    $cryptAttributes += ('{0} ({1})' -f $cryptAttribute.ObjectId.FriendlyName, $cryptAttribute.ObjectId.Value);
}

# Add the crypt attribute to the object.
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'CryptAttributes' -Value $cryptAttributes;

# Get the subject alternative names.
$subjectAlternativeNames = Get-SubjectAlternativeName -FilePath $FilePath;

# Add the SAN to the object.
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'SubjectAlternativeNames' -Value $subjectAlternativeNames;

# Get the hash of the CSR.
$csrHash = Get-Hash -FilePath $FilePath;

# Add the hash to the object.
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'SHA1Hash' -Value $csrHash.SHA1;
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'MD5Hash' -Value $csrHash.MD5;

# Get the application policies.
$applicationPolicies = Get-ApplicationPolicy -FilePath $FilePath;

# Add the application policies to the object.
$certificateSigningRequest | Add-Member -MemberType NoteProperty -Name 'ApplicationPolicy' -Value $applicationPolicies;

# Write to log.
Write-CsrToScreen -CertificateSigningRequest $certificateSigningRequest;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# If the object should be returned.
if ($ReturnObject)
{
    # Return the object.
    return $certificateSigningRequest;
}

############### Finalize - End ###############
#endregion
