#requires -version 5.1

<#
.SYNOPSIS
  Add or update an Win32 application in Microsoft Intune.
.DESCRIPTION
.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  14-07-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]

Param
(
    # Azure AD Tenant ID.
    [Parameter(Mandatory=$false)][string]$AzureAdTenantId,

    # Application/Client ID of the Azure AD app (service principal).
    [Parameter(Mandatory=$false)][string]$AzureAdClientId,

    # Secret of the Azure AD app (service principal).
    [Parameter(Mandatory=$false)][string]$AzureAdClientSecret,

    # Graph API Token.
    [Parameter(Mandatory=$false)][string]$ApiToken,

    # Intune - App ID of existing app.
    [Parameter(Mandatory=$true)][string]$IntuneAppId,
    
    # Package - Name.
    [Parameter(Mandatory=$true)][string]$Name,

    # Package - Version.
    [Parameter(Mandatory=$true)][string]$Version,

    # Package - Publisher.
    [Parameter(Mandatory=$true)][string]$Publisher,

    # Package - Description.
    [Parameter(Mandatory=$true)][string]$Description,

    # Package - Path to IntuneWin.
    [Parameter(Mandatory=$true)][string]$IntuneWinPath,

    # Package - Path to detection script.
    [Parameter(Mandatory=$true)][string]$DetectionScriptPath,

    # Package - Path to requirement script.
    [Parameter(Mandatory=$false)][string]$RequirementScriptPath = $null,

    # Package - Install command.
    [Parameter(Mandatory=$true)][string]$InstallCmd,

    # Package - Scope (machine or user).
    [Parameter(Mandatory=$true)][ValidateSet("system", "user")][string]$InstallExperience,

    # Package - Project URL.
    [Parameter(Mandatory=$true)][string]$ProjectUrl
)

# Clear screen.
#Clear-Host;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Application to update.
$Application = @{
    "Name" = $Name;
    "Version" = $Version;
    "Publisher" = $Publisher;
    "Description" = $Description;
    "Developer" = $Publisher;
    "Path" = $IntuneWinPath;
    "DetectionScript" = $DetectionScriptPath;
    "RequirementScript" = $RequirementScriptPath;
    "EnforceSignatureCheck" = $false;
    "InstallCmd" = $InstallCmd;
    "UninstallCmd" = $InstallCmd;
    "InstallExperience" = $InstallExperience; #or user.
    "InformationUrl" = $ProjectUrl;
    "IsFeatured" = $false; #or $true.
    "MinimumOs" = @{"v10_1607" = $true};
    "Notes" = "Automated by System Admins";
    "Owner" = $Publisher;
    "PrivacyUrl" = $ProjectUrl;
    "RunAs32Bit" = $false; #or true;
};

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Write to the console.
Function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Text,
        [Parameter(Mandatory=$false)][switch]$NoDateTime
    )
 
    # If the input is empty.
    If([string]::IsNullOrEmpty($Text))
    {
        $Text = " ";
    }
    # No date time.
    ElseIf($NoDateTime)
    {
        Write-Host $Text;
    }
    Else
    {
        # Write to the console.
        Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
}

# Get Microsoft Graph API token.
Function Get-ApiToken
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$TenantId,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$true)][string]$ClientSecret
    )

    # Construct body.
    $Body = @{    
        Grant_Type    = "client_credentials";
        Scope         = "https://graph.microsoft.com/.default";
        client_Id     = $ClientId;
        Client_Secret = $ClientSecret;
    };

    # Write to log.
    Write-Log ("Getting API token for Microsoft Graph");

    # Try to call the API.
    Try
    {
        # Invoke REST against Graph API.
        $Response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $Body;

        # Return
        Return [string]("Bearer {0}" -f $Response.access_token);
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while connecting to the Microsoft Graph API");
        Write-Log ($Error[0]) -NoDateTime;
    }
}

# Get specific Intune app.
Function Get-IntuneMobileApp
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken,
        [Parameter(Mandatory=$true)][string]$AppId
    )

    # Write to log.
    Write-Log ("Getting Intune Win32 app with id '{0}'" -f $AppId);
    
    # Headers.
    $Headers = @{
        'Authorization' = $ApiToken;
    }
    
    # Microsoft Graph API endpoint.
    $Uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppId";
    
    # Invoke endpoint.
    $Result = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get;

    # If result is not empty.
    If($Result)
    {
        # Write to log.
        Write-Log ("Found app '{0}'" -f $Result.DisplayName);
        
        # Return result.
        Return $Result;
    }
}

# Get default return codes.
Function Get-ReturnCodes
{
    [cmdletbinding()]	

    # Create default default return codes.
    $ReturnCodes = @(
        @{"returnCode" = 0;"type" = "success"},
        @{"returnCode" = 1707;"type" = "success"},
        @{"returnCode" = 3010;"type" = "softReboot"},
        @{"returnCode" = 1641;"type" = "hardReboot"},
        @{"returnCode" = 1618;"type" = "retry"}
    );
    
    #Return return codes.
    Return $ReturnCodes;
}

# Create detection rule.
Function New-DetectionRule
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][bool]$EnforceSignatureCheck,
        [Parameter(Mandatory=$true)][bool]$RunAs32Bit
    )

    # Write to log.
    Write-Log ("Converting '{0}' detection script to BASE64" -f $Path);
    Write-Log ("Enforce signature check is set to '{0}'" -f $EnforceSignatureCheck);
    Write-Log ("Will run as a 32-bit process '{0}'" -f $RunAs32Bit);

    # Convert script to BASE64.
    $Script = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path));

    # Construct detection rule.
    $DetectionRule = @{
        '@odata.type' = "#microsoft.graph.win32LobAppPowerShellScriptDetection";
        'enforceSignatureCheck' = $EnforceSignatureCheck;
        'runAs32Bit' = $RunAs32Bit;
        'scriptContent' = $Script;
    };

    # Return detection rule.
    Return $DetectionRule;
}

# Create detection rule.
Function New-RequirementScript
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Path,
        [Parameter(Mandatory=$true)][bool]$EnforceSignatureCheck,
        [Parameter(Mandatory=$true)][bool]$RunAs32Bit
    )

    # If path is set.
    If(!([string]::IsNullOrEmpty($Path)))
    {
        # Write to log.
        Write-Log ("Converting '{0}' requirement script to BASE64" -f $Path);
        Write-Log ("Enforce signature check is set to '{0}'" -f $EnforceSignatureCheck);
        Write-Log ("Will run as a 32-bit process '{0}'" -f $RunAs32Bit);

        # Convert script to BASE64.
        $Script = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path));

        # Construct requirement.
        $Requirement = @{
            '@odata.type' = "#microsoft.graph.win32LobAppPowerShellScriptRequirement";
            'enforceSignatureCheck' = $EnforceSignatureCheck;
            'runAs32Bit' = $RunAs32Bit;
            'scriptContent' = $Script;
            'operator' = "equal"
            'detectionValue' = "Upgrade"
            'displayName' = "Upgrade previous installation"
            'runAsAccount' = 'system'
            'detectionType' = "string"
        };

        # Return detection rule.
        Return $Requirement;   
    }
    Else
    {
        # Write to log.
        Write-Log ("Requirement script not set, skipping");
    }
}

# Extract the IntuneWin file.
Function Extract-IntuneWin
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Output
    )

    # Add ZIP assembly.
    Add-Type -Assembly System.IO.Compression.FileSystem;

    # If output folder already exist.
    If(Test-Path -Path $Output)
    {
        # Write to log.
        Write-Log ("Removing output folder '{0}'" -f $Output);

        # Remove directory if it already exists.
        Remove-Item -Path $Output -Force -Recurse;   
    }

    # Write to log.
    Write-Log ("Extracting file '{0}' to '{1}'" -f $Path, $Output);

    # Extract IntuneWin file.
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $Output);
}

# Get detection information inside the .IntuneWin file.
Function Get-IntuneWinDetection
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Path
    )

    # Name of the detection xml file name.
    $DetectionXmlFileName = "Detection.xml";

    # Find file in the directory.
    $File = Get-ChildItem -Path $Path -Recurse | Where-Object {$_.Name -eq $DetectionXmlFileName};

    # Get content inside the XML file.
    $XmlContent = [xml](Get-Content -Path $File.FullName);

    # Return the XML content.
    Return $XmlContent;
}

# Get IntuneWin encryption information.
Function Get-IntuneWinEncryptionInfo
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$DetectionXml
    )

    # Get encryption information from XML.
    $EncryptionInfo = @{
        'encryptionKey' = $DetectionXml.ApplicationInfo.EncryptionInfo.EncryptionKey;
        'macKey' = $DetectionXml.ApplicationInfo.EncryptionInfo.macKey;
        'initializationVector' = $DetectionXml.ApplicationInfo.EncryptionInfo.initializationVector;
        'mac' = $DetectionXml.ApplicationInfo.EncryptionInfo.mac;
        'profileIdentifier' = "ProfileVersion1";
        'fileDigest' = $DetectionXml.ApplicationInfo.EncryptionInfo.fileDigest;
        'fileDigestAlgorithm' = $DetectionXml.ApplicationInfo.EncryptionInfo.fileDigestAlgorithm;
    };

    # Return.
    Return $EncryptionInfo;
}

# Get file size for the IntuneWin file.
Function Get-IntuneWinFileSize
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Path
    )

    # Find file in the directory.
    $File = Get-ChildItem -Path $Path -Recurse | Where-Object {$_.Extension -eq ".intunewin"};

    # Get file size.
    $FileSize = $File.Length;

    # Return.
    Return $FileSize;
}

# Create new content version for a Win32 client app in Intune.
Function New-IntuneWin32AppContentVersion
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken,
        [Parameter(Mandatory=$true)][string]$AppId,
        [Parameter(Mandatory=$true)][string]$DisplayName
    )

    
    # Write to log.
    Write-Log ("Creating new content version for '{0}' in Intune" -f $DisplayName);

    # Body.
    $Body = @{
    } | ConvertTo-Json;

    # Create request headers.
    $Headers = @{
        'Authorization' = $ApiToken;
        'content-length' = $Body.Length;
        'content-type' = 'application/json';
    };

    # Construct URI.
    $Uri = ("https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions" -f $AppId);

    # Create new mobile app content file in Intune.
    $Response = Invoke-RestMethod -Method Post -Headers $Headers -Body $Body -Uri $Uri -ContentType "application/json";

    # Return reponse
    Return $Response;
}

# Get IntuneWin application informaiton.
Function Get-IntuneWinApplicationInfo
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$Path
    )

    
    # Write to log.
    Write-Log ("Getting application information from '{0}'" -f $Path);

    # Get XML detection file inside the IntuneWin file.
    $DetectionXml = Get-IntuneWinDetection -Path $Application.Path;

    # Return.
    Return $DetectionXml.ApplicationInfo;
}

# Create new mobile app content file in Azure for upload to Intune.
Function New-IntuneWin32AppUpload
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken,
        [Parameter(Mandatory=$true)][string]$FileName,
        [Parameter(Mandatory=$true)][string]$DisplayName,
        [Parameter(Mandatory=$true)][int64]$FileSize,
        [Parameter(Mandatory=$true)][int64]$EncryptedFileSize,
        [Parameter(Mandatory=$true)][string]$AppId,
        [Parameter(Mandatory=$true)][int]$ContentVersionId
    )

    
    # Write to log.
    Write-Log ("Creating a new file entry in Azure for upload '{0}' in Intune" -f $DisplayName);

    # Body.
    $Body = @{
        "@odata.type" = "#microsoft.graph.mobileAppContentFile";
        "name" = $FileName;
        "size" = $FileSize;
        "sizeEncrypted" = $EncryptedFileSize;
        "manifest" = $null;
        "isDependency" = $false;
    } | ConvertTo-Json;

    # Create request headers.
    $Headers = @{
        'Authorization' = $ApiToken;
        'content-length' = $Body.Length;
        'content-type' = 'application/json';
    };

    # Construct URI.
    $Uri = ("https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files" -f $AppId, $ContentVersionId);

    # Create new mobile app content file in Intune.
    $Response = Invoke-RestMethod -Method Post -Headers $Headers -Body $Body -Uri $Uri -ContentType "application/json";

    # Return reponse
    Return $Response;
}

# Get content version file status for Intune app.
Function Get-IntuneWin32AppFileProcessingStatus
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken,
        [Parameter(Mandatory=$true)][string]$AppId,
        [Parameter(Mandatory=$true)][string]$ContentVersionId,
        [Parameter(Mandatory=$true)][string]$FileId,
        [Parameter(Mandatory=$true)][ValidateSet("AzureStorageUriRequest", "CommitFile")][string]$RequestType
    )

    # Create request headers.
    $Headers = @{
        'Authorization' = $ApiToken;
    };

    # Maximum attempts (counter).
    $Attempts = 60;

    # Time between each attempt (in seconds).
    $WaitTime = 1;

    # File state.
    $SuccessState = ("{0}Success" -f $RequestType);
	$PendingState = ("{0}Pending" -f $RequestType);
	$FailedState = ("{0}Failed" -f $RequestType);
	$TimedOutState = ("{0}TimedOut" -f $RequestType);

    # Construct URI.
    $Uri = ("https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files/{2}" -f $AppId, $ContentVersionId, $FileId);

    # As long as maximum attempts isn't reached.
    While($Attempts -gt 0)
    {
        # Clear variables.
        $Response = $null;

        # Make a request.
        $Response = Invoke-RestMethod -Method Get -Headers $Headers -Uri $Uri -ContentType "application/json";

        # If upload state is a success.
        If($Response.uploadState -eq $SuccessState)
        {
            # Write to log.
            Write-Log ("Upload state is '{0}'" -f $Response.uploadState);
            
            #Break the while loop.
            break;
        }
        ElseIf($Response.uploadState -ne $PendingState)
        {
            # Write to log.
            Write-Log ("Upload state is '{0}'" -f $Response.uploadState);
        }

        # Start wait time.
        Start-Sleep -Seconds $WaitTime;

        # Withdraw 1 from attempts.
        $Attempts--;

        # Write to log.
        Write-Log ("Waiting for processing status. {0} attempts remaining" -f $Attempts);
    }

    # If request is empty.
    If($Response -eq $null)
    {
        # Write to log.
        Write-Log ("Something went wrong");
    }
    # Else.
    Else
    {
        #Return reponse.
        Return $Response;
    }
}

# Commit Win32 app file to Intune.
Function Commit-IntuneWin32AppFile
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken,
        [Parameter(Mandatory=$true)][string]$AppId,
        [Parameter(Mandatory=$true)][string]$ContentVersionId,
        [Parameter(Mandatory=$true)][string]$FileId,
        [Parameter(Mandatory=$true)]$EncryptionInfo
    )

    # Write to log.
    Write-Log ("Committing file upload to Intune");

    # Construct URI.
    $Uri = ("https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files/{2}/commit" -f $AppId, $ContentVersionId, $FileId);

    # Convert body to JSON.
    $Body = @{
        'fileEncryptionInfo' = $EncryptionInfo
    } | ConvertTo-Json;

    # Create request headers.
    $Headers = @{
        'Authorization' = $ApiToken;
        'content-length' = $Body.Length;
        'content-type' = 'application/json';
    };

    # Make a request.
    $Response = Invoke-WebRequest $Uri -Method Post -Headers $Headers -Body $Body  -ContentType "application/json";

    # Return reponse.
    Return $Response;
}

# Commit Win32 app to Intune.
Function Commit-IntuneWin32MsiApp
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken,
        [Parameter(Mandatory=$true)][string]$AppId,
        [Parameter(Mandatory=$true)][string]$ContentVersionId
    )

    # Write to log.
    Write-Log ("Comitting application to Intune");

    # Construct URI.
    $Uri = ("https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}" -f $AppId);

    # Construct body.
    $Body = @{
        "@odata.type" = "#microsoft.graph.win32LobApp";
        "committedContentVersion" = $ContentVersionId;
    } | ConvertTo-Json;

    # Create request headers.
    $Headers = @{
        'Authorization' = $ApiToken;
        'content-length' = $Body.Length;
        'content-type' = 'application/json';
    };

    # Make a request.
    $Response = Invoke-WebRequest $Uri -Method Patch -Headers $Headers -Body $Body  -ContentType "application/json";

    # Return reponse.
    Return $Response;
}

# Upload app file to Azure blob storage.
Function Upload-IntuneWin32AppFile
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$Path,
        [Parameter(Mandatory=$true)]$SasUri
    )

    # Chunk size (1 MiB).
    $ChunkSize = 1024 * 1024;

    # Read all content into bytes.
    [byte[]]$Bytes = [System.IO.File]::ReadAllBytes($Path);

    # Split up to chunks.
    $Chunks = [Math]::Ceiling($Bytes.Length/$ChunkSize);
    
    # Counter.
    $Counter = 1;

    # Chunk converted to BASE64.
    $Base64Strings = @();

    # For every chunk.
    For($Chunk = 0; $Chunk -lt $Chunks; $Chunk++)
    {
        # Convert chunk bytes to string.
        $Base64String = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Chunk.ToString("0000")));

        # Add to chunk string to array.
        $Base64Strings += $Base64String;

        # Calculate chunk body.
        $Start = $Chunk * $ChunkSize;
        $End = [Math]::Min($Start + $ChunkSize - 1, $Bytes.Length - 1);
        
        # Get part of bytes.
        $Body = $Bytes[$Start..$End];

        # Write to log.
        Write-Log ("Uploaded {0}% of the application to Intune" -f [math]::Round($($Counter/$Chunks*100)));

        # Add to counter.
        $Counter++;

        # Try to upload chunk.
        $Response = Upload-AzureStorageChunk -SasUri $SasUri -Base64 $Base64String -Body $Body;
    }

    # Write to log.
    Write-Log ("Finished uploading the application to Intune");

    # Construct URI.
    $Uri = ("{0}&comp=blocklist" -f $SasUri);

    # Construct chunks XML list.
    $Xml = '<?xml version="1.0" encoding="utf-8"?><BlockList>';

    # Foreach chunk.
    Foreach($Base64String in $Base64Strings)
    {
        #Add to XML list.
        $Xml += "<Latest>$Base64String</Latest>";
    }

    # Close the XML list.
    $Xml += '</BlockList>';

    # Make request.
    $Response = Invoke-WebRequest $Uri -Method Put -Body $Xml;
}

# Get file.
Function Get-File
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][ValidateSet("DirectoryName", "FileNameWithoutExtension", "FileName")][string]$Option
    )

    # If directory path.
    If($Option -eq "DirectoryName")
    {
        # Get directory path.
        $DirectoryName = [System.IO.Path]::GetDirectoryName($Path);

        # Return directory.
        Return $DirectoryName;
    }
    ElseIf($Option -eq "FileNameWithoutExtension")
    {
        # Get file name without extension.
        $FilenameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($Path);

        # Return filename.
        Return $FilenameWithoutExtension;
    }
    ElseIf($Option -eq "FileName")
    {
        # Get directory path.
        $FileName = [System.IO.Path]::GetFileName($Path);

        # Return file name.
        Return $FileName;
    }
}

# Upload chunk to Azure Storage.
Function Upload-AzureStorageChunk
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$SasUri,
        [Parameter(Mandatory=$true)]$Base64,
        [Parameter(Mandatory=$true)]$Body
    )

    # Construct URI.
    $Uri = ("{0}&comp=block&blockid={1}" -f $SasUri, $Base64);

    # Construct PUT header.
    $Headers = @{
        "x-ms-blob-type" = "BlockBlob";
        "x-ms-version" = "2020-04-08";
    };

    # Get ISO standards.
    $Iso88591 = [System.Text.Encoding]::GetEncoding("iso-8859-1");

    # Get encoded string from body.
    $Content = $Iso88591.GetString($Body);

    # Make a request.
    $Response = Invoke-WebRequest $Uri -Method Put -Headers $Headers -Body $Content;

    # Return reponse.
    Return $Response;
}

# Update Win32 client app in Intune.
Function Update-IntuneWin32App
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken,
        [Parameter(Mandatory=$true)][string]$AppId,
        [Parameter(Mandatory=$true)][string]$Description,
        [Parameter(Mandatory=$true)][string]$Developer,
        [Parameter(Mandatory=$true)][string]$DisplayName,
        [Parameter(Mandatory=$true)][string]$DisplayVersion,
        [Parameter(Mandatory=$true)][string]$FileName,
        [Parameter(Mandatory=$true)][string]$InstallCmd,
        [Parameter(Mandatory=$true)][string]$UninstallCmd,
        [Parameter(Mandatory=$true)][string]$InstallExperience,
        [Parameter(Mandatory=$true)][string]$InformationUrl,
        [Parameter(Mandatory=$true)][bool]$IsFeatured,
        [Parameter(Mandatory=$true)][hashtable]$MinimumOs,
        [Parameter(Mandatory=$true)][string]$Notes,
        [Parameter(Mandatory=$true)][string]$Owner,
        [Parameter(Mandatory=$true)][string]$PrivacyUrl,
        [Parameter(Mandatory=$true)][string]$Publisher,
        [Parameter(Mandatory=$true)][bool]$RunAs32Bit,
        [Parameter(Mandatory=$true)][string]$SetupFileName,
        [Parameter(Mandatory=$true)]$DetectionRule,
        [Parameter(Mandatory=$false)]$RequirementScript,
        [Parameter(Mandatory=$true)]$ReturnCodes
    )

    #Create reqeust body.
    $Body = @{
        '@odata.type' = "#microsoft.graph.win32LobApp";
        'description' = $Description;
        'developer' = $Developer;
        'displayName' = $DisplayName;
        'displayVersion' = $DisplayVersion;
        'fileName' = $FileName;
        'installCommandLine' = $InstallCmd;
        'uninstallCommandLine' = $UninstallCmd;
        'installExperience' = @{"runAsAccount" = $InstallExperience};;
        'informationUrl' = $InformationUrl;
        'isFeatured' = $IsFeatured;
        'minimumSupportedOperatingSystem' = $MinimumOs;
        'msiInformation' = $null;
        'notes' = $Notes;
        'owner' = $Owner;
        'privacyInformationUrl' = $PrivacyUrl;
        'publisher' = $Publisher;
        'runAs32bit' = $RunAs32Bit;
        'setupFileName' = $SetupFileName;
        'detectionRules' = $DetectionRule;
        'returnCodes' = $ReturnCodes;
    };

    # If requirement script is set.
    If(!([string]::IsNullOrEmpty($RequirementScript)))
    {
        # Add to body.
        $Body.Add('requirementRules', $RequirementScript);   
    }
    
    # Convert to JSON.
    $Body = $Body | ConvertTo-Json;

    # Create request headers.
    $Headers = @{
        'Authorization' = $ApiToken;
        'content-length' = $Body.Length;
        'content-type' = 'application/json';
    };

    # Write to log.
    Write-Log ("Updating '{0}' client application in Intune" -f $DisplayName);

    # Update application in Intune.
    Invoke-RestMethod -Method Patch -Headers $Headers -Body $Body -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppId" -ContentType "application/json";

    # Get app return.
    $Response = Get-IntuneMobileApp -ApiToken $ApiToken -AppId $AppId;

    #Return reponse
    Return $Response;
}

# Replace intune win32 app.
Function Replace-IntuneWin32App
{

    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$ApiToken,
        [Parameter(Mandatory=$true)]$AppId,
        [Parameter(Mandatory=$true)]$Application
    )

    # Get output folder for extracting the IntuneWin.
    $IntuneWinOutput = ('{0}\Packages\Extract\{1}' -f $env:TEMP, (New-Guid).Guid);

    # Get detection rule.
    $DetectionRule = New-DetectionRule -Path $Application.DetectionScript `
                      -EnforceSignatureCheck $Application.EnforceSignatureCheck `
                      -RunAs32Bit $Application.RunAs32Bit;

    # Get requirement script.
    $RequirementScript = New-RequirementScript -Path $Application.RequirementScript `
                            -EnforceSignatureCheck $Application.EnforceSignatureCheck `
                            -RunAs32Bit $Application.RunAs32Bit;

    # Get default return codes.
    $ReturnCodes = Get-ReturnCodes;

    # Extract IntuneWin file.
    Extract-IntuneWin -Path $Application.Path -Output $IntuneWinOutput;

    # Get XML detection file inside the IntuneWin file.
    $DetectionXml = Get-IntuneWinDetection -Path $IntuneWinOutput;

    # Get encryption information.
    $EncryptionInfo = Get-IntuneWinEncryptionInfo -DetectionXml $DetectionXml;

    # Get extracted IntuneWin file size.
    $IntuneWinEncryptedFileSize = Get-IntuneWinFileSize -Path $IntuneWinOutput;

    # Create a new Win32 client app in Intune.
    $IntuneWin32App = Update-IntuneWin32App -ApiToken $ApiToken `
                                         -AppId $AppId `
                                         -Description $Application.Description `
                                         -Developer $Application.Developer `
                                         -DisplayName $Application.Name `
                                         -DisplayVersion $Application.Version `
                                         -FileName $DetectionXml.ApplicationInfo.FileName `
                                         -InstallCmd $Application.InstallCmd `
                                         -UninstallCmd $Application.UninstallCmd `
                                         -InstallExperience $Application.InstallExperience `
                                         -InformationUrl $Application.InformationUrl `
                                         -IsFeatured $Application.IsFeatured `
                                         -Notes $Application.Notes `
                                         -MinimumOs $Application.MinimumOs `
                                         -Owner $Application.Owner `
                                         -PrivacyUrl $Application.PrivacyUrl `
                                         -Publisher $Application.Publisher `
                                         -RunAs32Bit $Application.RunAs32Bit `
                                         -SetupFileName $DetectionXml.ApplicationInfo.SetupFile `
                                         -DetectionRule @($DetectionRule) `
                                         -RequirementScript @($RequirementScript) `
                                         -ReturnCodes $ReturnCodes;

    # Create new content version for the Win32 client app in Intune.
    $IntuneWin32AppContentVersion = New-IntuneWin32AppContentVersion -ApiToken $ApiToken `
                                                                     -AppId $IntuneWin32App.id `
                                                                     -DisplayName $Application.Name;

    # Create a new file entry in Azure for the upload.
    $InteunWin32AppUpload = New-IntuneWin32AppUpload -ApiToken $ApiToken `
                             -FileName $DetectionXml.ApplicationInfo.FileName `
                             -DisplayName $Application.Name `
                             -FileSize $DetectionXml.ApplicationInfo.UnencryptedContentSize `
                             -EncryptedFileSize $IntuneWinEncryptedFileSize `
                             -AppId $IntuneWin32App.id `
                             -ContentVersionId $IntuneWin32AppContentVersion.id;

    # Wait until Azure storage URI request processing status is complete.
    $AzureStorageUriRequestProcessingStatus = Get-IntuneWin32AppFileProcessingStatus -ApiToken $ApiToken `
                                                                                      -AppId $IntuneWin32App.id `
                                                                                      -ContentVersionId $IntuneWin32AppContentVersion.id `
                                                                                      -FileId $InteunWin32AppUpload.id `
                                                                                      -RequestType AzureStorageUriRequest;

    # Upload to Azure.
    Upload-IntuneWin32AppFile -Path ('{0}\IntuneWinPackage\Contents\{1}' -f $IntuneWinOutput, $DetectionXml.ApplicationInfo.FileName) `
                              -SasUri $AzureStorageUriRequestProcessingStatus.azureStorageUri;

    # Commit file upload to Azure.
    $IntuneWin32AppUploadCommit = Commit-IntuneWin32AppFile -ApiToken $ApiToken `
                                                            -AppId $IntuneWin32App.id `
                                                            -ContentVersionId $IntuneWin32AppContentVersion.id `
                                                            -FileId $InteunWin32AppUpload.id `
                                                            -EncryptionInfo $EncryptionInfo;

    # Wait until commit file processing status is complete.
    $CommitFileProcessingStatus = Get-IntuneWin32AppFileProcessingStatus -ApiToken $ApiToken `
                                                                         -AppId $IntuneWin32App.id `
                                                                         -ContentVersionId $IntuneWin32AppContentVersion.id `
                                                                         -FileId $InteunWin32AppUpload.id `
                                                                         -RequestType CommitFile;

    # Finish the commit process.
    $IntuneWin32AppCommit = Commit-IntuneWin32MsiApp -ApiToken $ApiToken `
                             -AppId $IntuneWin32App.id `
                             -ContentVersionId $IntuneWin32AppContentVersion.id;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# If API token is empty.
If([string]::IsNullOrEmpty($ApiToken))
{
    # Get graph token.
    $ApiToken = Get-ApiToken -TenantId $AzureAdTenantId -ClientId $AzureAdClientId -ClientSecret $AzureAdClientSecret;
}

# Replace Win32 app.
Replace-IntuneWin32App -ApiToken $ApiToken -Application $Application -AppId $IntuneAppId;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion