#requires -version 3;
#requires -module ExchangeOnlineManagement;

<#
.SYNOPSIS
  Export mailbox into PST file chunks.

.DESCRIPTION
  Create compliance search by date intervals and exports data to several PST files.
  You need the eDiscovery Manager Administrator role and the ExchangeOnlineManagement PowerShell module.
  It uses basic authentication for connection to Exchange Online.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  15-11-2021
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]

Param
(
    # Username.
    [Parameter(Mandatory=$true)][string]$Username,

    # Password.
    [Parameter(Mandatory=$true)][string]$Password,

    # Output path for PST files.
    [Parameter(Mandatory=$false)][string]$OutputPath = "C:\PstExport",

    # Mailbox to export.
    [Parameter(Mandatory=$true)][string[]]$Mailboxes
)

# Clear screen.
Clear-Host;

# Import modules.
Import-Module -Name "ExchangeOnlineManagement" -Force -DisableNameChecking;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Credentials.
$Credentials = @{
    ExchangeOnline = @{
        Username = $Username;
        Password = $Password;
    };
};

# Folders.
$Folders = @{
    PstOutput = $OutputPath;
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
        [Parameter(Mandatory=$false)][string]$Text
    )
 
    # If the input is empty.
    If([string]::IsNullOrEmpty($Text))
    {
        $Text = " ";
    }
    Else
    {
        # Write to the console.
        Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
}

# Creates a PS credential object.
Function New-PSCredential
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$Username,
        [Parameter(Mandatory=$true)]$Password
    )
 
    # Convert the password to a secure string.
    $SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force;
 
    # Convert $Username and $SecurePassword to a credential object.
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username,$SecurePassword;
 
    # Return the credential object.
    Return $Credential;
}

# Create compliance searches to use for PST exports.
Function Search-MailboxContent
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)]$Mailbox,
        [Parameter(Mandatory=$false)][int]$DaysPerSpan = 20
    )

    # Object array.
    $Results = @();

    # Get dates to search.
    $MailboxCreated = $Mailbox.WhenCreated;
    $Today = Get-Date;  

    # Get smaller chunk for search criteria.
    $SearchDates = Split-TimeSpan -StartDate $MailboxCreated -EndDate $Today -DaysPerSpan $DaysPerSpan;

    # Counter.
    $Counter = 1;

    # Foreach date.
    Foreach($SearchDate in $SearchDates)
    {
        # Construct search name.
        $SearchName = ("Search_{0}_{1}" -f $Mailbox.Alias, $Counter);
        $ExportName = ("{0}_Export" -f $SearchName);

        # Get dates.
        $StartDate = $SearchDate.StartDate.ToString("yyyy-MM-dd");
        $EndDate = $SearchDate.EndDate.ToString("yyyy-MM-dd");

        # Write to log.
        Write-Log ("{0}: Searching from '{1}' to '{2}" -f $Mailbox.PrimarySmtpAddress, $StartDate, $EndDate);
    
        # Get query.
        $Query = ('(c:c)(date={0}..{1})' -f $StartDate, $EndDate);

        # If search already exist.
        If(Get-ComplianceSearch -Identity $SearchName -ErrorAction SilentlyContinue)
        {
            # Write to log.
            Write-Log ("{0}: Removing existing search '{1}'" -f $Mailbox.PrimarySmtpAddress, $SearchName);
            
            # Remove compliance search.
            Remove-ComplianceSearch -Identity $SearchName -Confirm:$false;
        }

        # Write to log.
        Write-Log ("{0}: Creating search query '{1}'" -f $Mailbox.PrimarySmtpAddress, $SearchName);

        # Create search.
        New-ComplianceSearch -Name $SearchName -Description $Mailbox.PrimarySmtpAddress -ExchangeLocation $Mailbox.PrimarySmtpAddress -AllowNotFoundExchangeLocationsEnabled $true -Force -ContentMatchQuery $Query;

        # Write to log.
        Write-Log ("{0}: Starting search '{1}'" -f $Mailbox.PrimarySmtpAddress, $SearchName);

        # Start the search.
        Start-ComplianceSearch -Identity $SearchName;

        # Get search status.
        Do
        {
            # Start sleep.
            Start-Sleep -Seconds 2;
    
            # Get search status.
            $SearchStatus = Get-ComplianceSearch -Identity $SearchName | Select-Object -ExpandProperty Status;

            # Write to log.
            Write-Log ("{0}: Search status is '{1}' for '{2}'" -f $Mailbox.PrimarySmtpAddress, $SearchStatus, $SearchName);
        }
        While($SearchStatus -ne "Completed");

        # Start sleep.
        Start-Sleep -Seconds 5;

        # Get search results.
        $SearchResult = Get-ComplianceSearch $SearchName;

        # If there is any items.
        If($SearchResult.Items -ne 0)
        {
            # Write to log.
            Write-Log ("{0}: Creating new search action" -f $Mailbox.PrimarySmtpAddress);

            # Create search action.
            New-ComplianceSearchAction -SearchName $SearchName -Export -Format FxStream  -ExchangeArchiveFormat PerUserPst -Scope IndexedItemsOnly -EnableDedupe $true;

            # Write to log.
            Write-Log ("{0}: Getting search action status for '{1}'" -f $Mailbox.PrimarySmtpAddress, $SearchName);

            # Get search status.
            $SearchActionStatus = Get-ComplianceSearchAction -Identity $ExportName | Select-Object -ExpandProperty Status;

            # Get search action status.
            Do
            {
                # Clear variable.
                $SearchActionStatus = $null;

                # Write to log.
                Write-Log ("{0}: Waiting for search action status to complete for '{1}', next update in 10 seconds" -f $Mailbox.PrimarySmtpAddress, $ExportName);
    
                # Get search status.
                $SearchActionStatus = Get-ComplianceSearchAction -Identity $ExportName | Select-Object -ExpandProperty Status;

                # Start sleep.
                Start-Sleep -Seconds 10;
            }
            # Stop if the status is completed.
            While($SearchActionStatus -ne "Completed");

            # Write to log.
            Write-Log ("{0}: Getting search action results with details from '{1}'" -f $Mailbox.PrimarySmtpAddress, $ExportName);

            # Get details.
            $SearchActionStatusDetails = Get-ComplianceSearchAction -Identity $ExportName -IncludeCredential -Details;

            # Add to object array.
            $Results += $SearchActionStatusDetails;
        }
        Else
        {
            # Write to log.
            Write-Log ("{0}: No items in the search '{1}'" -f $Mailbox.PrimarySmtpAddress, $SearchName);
        }

        # Add to counter.
        $Counter++;
    }

    # Return results.
    Return $Results;
}

# Split timespan into smaller chunks.
Function Split-TimeSpan
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)][datetime]$StartDate,
        [Parameter(Mandatory=$true)][datetime]$EndDate,
        [Parameter(Mandatory=$true)][int]$DaysPerSpan
    )

    # Get timespan.
    $Span = New-TimeSpan -Start $StartDate -End $EndDate;

    # Object array.
    $Spans = @();
    
    # Foreach days per span.
    for ($i = 0; $i -lt $Span.Days; $i+= ($DaysPerSpan + 1))
    { 
        # Add loop details.
        $LoopStart = ($StartDate).AddDays($i);
        $LoopEnd = ($StartDate).AddDays($i+$DaysPerSpan);

        # If loop end is greater than end date.
        If($LoopEnd -gt $EndDate)
        {
            # Set the loop end to end date.
            $LoopEnd = $EndDate;
        }

        # Add to object array.
        $Spans += New-Object psobject -Property @{StartDate=$LoopStart; EndDate=$LoopEnd};
    }

    # Return object array.
    Return $Spans;
}

# Export PST files.
Function ExportTo-PST
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$ExportToolPath,
        [Parameter(Mandatory=$true)][string]$ExportLocation,
        [Parameter(Mandatory=$true)][string]$SearchName
    )

    # Get export name.
    $ExportName = $SearchName + "_Export";

    # Get details.
    $SearchActionStatusDetails = Get-ComplianceSearchAction -Identity $ExportName -IncludeCredential -Details;
    $Email = $SearchActionStatusDetails.ExchangeLocation;
    $SearchActionStatusDetails = $SearchActionStatusDetails.Results.split(";");
    $ExportContainerUrl = $SearchActionStatusDetails[0].trimStart("Container url: ");
    $ExportSasToken = $SearchActionStatusDetails[1].trimStart(" SAS token: ");

    # Write to log.
    Write-Log ("{0}: Starting download for action '{1}'" -f $Email, $ExportName);

    # Set argument list.
    $ArgumentList = ('-name "{0}" -source "{1}" -key "{2}" -dest "{3}" -trace true' -f $SearchName, $ExportContainerUrl, $ExportSasToken, $ExportLocation);

    # Start export.
    Start-Process -FilePath $ExportToolPath -ArgumentList $ArgumentList;

    # Start sleep.
    Start-Sleep -Seconds 3;

    # While the process is still active.
    While(Get-Process -Name "microsoft.office.client.discovery.unifiedexporttool" -ErrorAction SilentlyContinue)
    {
        # Get export details.
        $SearchActionStatusDetails = Get-ComplianceSearchAction -Identity $ExportName -IncludeCredential -Details;
        $SearchActionStatusDetails = $SearchActionStatusDetails.Results.split(";");
        $ExportEstSize = [double]::Parse(((($SearchActionStatusDetails[18].TrimStart(" Total estimated bytes: ")))), [cultureinfo] 'da-DK');
        $ExportProgress = $SearchActionStatusDetails[22].TrimStart(" Progress: ").TrimEnd("%");
        $ExportStatus = $SearchActionStatusDetails[25].TrimStart(" Export status: ");

        # Get download content.
        $Downloaded = Get-ChildItem -Path ("{0}" -f $ExportLocation) -Recurse | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum;

        # Get procent downloaded.
        $ProcentDownloaded = ($Downloaded/$ExportEstSize*100);

        # Write to log.
        Write-Output ("{0}: Downloaded {1}%" -f $Email, $ProcentDownloaded);

        # Start sleep.
        Start-Sleep -Seconds 5;
    }

    # Write to log.
    Write-Output ("{0}: Download completed" -f $Email, $ProcentDownloaded);
}

Function Install-ExportTool
{
    # Check if the export tool is installed for the user, and download if not.
    While (-Not ((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter microsoft.office.client.discovery.unifiedexporttool.exe -Recurse).FullName | Where-Object{ $_ -notmatch "_none_" } | Select-Object -First 1))
    {
        # Download manifest.
        $Manifest = "https://complianceclientsdf.blob.core.windows.net/v16/Microsoft.Office.Client.Discovery.UnifiedExportTool.application";

        # Write to log.
        Write-Log ("Downloading Unified Export Tool from '{0}'" -f $Email, $ExportName);

        # Need elevated permissions.
        $ElevatePermissions = $true;

        # Try to install.
        Try
        {
            # Add assembly.
            Add-Type -AssemblyName System.Deployment;

            # Write to log.
            Write-Log ("Installing Unified Export Tool");

            # Construct URI
            $RemoteURI = [URI]::New( $Manifest , [UriKind]::Absolute);

            # If manifest is not accessable.
            if (-not  $Manifest)
            {
                throw "Invalid ConnectionUri parameter '$ConnectionUri'";
            }

            # Get hosting manager.
            $HostingManager = New-Object System.Deployment.Application.InPlaceHostingManager -ArgumentList $RemoteURI , $False;
            
            # Register object event.
            Register-ObjectEvent -InputObject $HostingManager -EventName GetManifestCompleted -Action { 
                new-event -SourceIdentifier "ManifestDownloadComplete";
            } | Out-Null;

            # Register object event.
            Register-ObjectEvent -InputObject $HostingManager -EventName DownloadApplicationCompleted -Action { 
                new-event -SourceIdentifier "DownloadApplicationCompleted";
            } | Out-Null;
            
            # Get manifest async.
            $HostingManager.GetManifestAsync();
            
            # Wait for event.
            $event = Wait-Event -SourceIdentifier "ManifestDownloadComplete" -Timeout 15;

            # If event exist.
            if ($event)
            {
                # Remove event.
                $event | Remove-Event
                
                # Write to log.
                Write-Log ("ClickOnce Manifest Download Completed");
                
                # Application require elevated permissions.
                $HostingManager.AssertApplicationRequirements($ElevatePermissions);

                # Download async.
                $HostingManager.DownloadApplicationAsync();

                # Wait for event.
                $event = Wait-Event -SourceIdentifier "DownloadApplicationCompleted" -Timeout 60
                
                # If event exist.
                if ($event)
                {
                    
                    # Remove event.
                    $event | Remove-Event;
                    
                    # Write to log.
                    Write-Log ("Download of Unified Export completed");
                }
                # Event doesnt exist.
                else
                {
                    # Write to log.
                    Write-Log ("ClickOnce Application Download did not complete in time (60s)");
                }
            }
            # No event exists.
            else
            {
                # Write to log.
                Write-Log ("ClickOnce Manifest Download did not complete in time (15s)");
            }
        }
        finally {
            # Unregister event.
            Get-EventSubscriber|? {$_.SourceObject.ToString() -eq 'System.Deployment.Application.InPlaceHostingManager'} | Unregister-Event;
        }
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Create credentials.
$CredentialExchangeOnline = New-PSCredential -Username $Credentials.ExchangeOnline.Username -Password $Credentials.ExchangeOnline.Password;

# Write to log.
Write-Log ("Connecting to Exchange Online");

# Connect to the compliance center.
Connect-IPPSSession -Credential $CredentialExchangeOnline -WarningAction SilentlyContinue;

# Connect to Exchange Online.
Connect-ExchangeOnline -Credential $CredentialExchangeOnline -ShowBanner:$false;

# Write to log.
Write-Log ("Creating folder '{0}'" -f $Folders.PstOutput);

# Create output folder.
New-Item -Path $Folders.PstOutput -ItemType Directory -Force | Out-Null;

# Write to log.
Write-Log ("Installing export tool");

# Install tool.
Install-ExportTool;

# Get tool.
$PstExport = ((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter microsoft.office.client.discovery.unifiedexporttool.exe -Recurse).FullName) | Where-Object{ $_ -notmatch "_none_" } | Select-Object -First 1;

# Foreach mailbox.
Foreach($Mailbox in $Mailboxes)
{
    # Write to log.
    Write-Log ("Will be exporting '{0}'" -f $Mailbox);
    
    # Get mailbox.
    $ExoMailbox = Get-Mailbox -Identity $Mailbox;
    
    # Output folder.
    $Output = ("{0}\{1}" -f $Folders.PstOutput, $ExoMailbox.PrimarySmtpAddress);

    # Write to log.
    Write-Log ("Creating folder '{0}'" -f $Output);

    # Create output folder.
    New-Item -Path $Output -ItemType Directory -Force | Out-Null;

    # Search mailbox.
    $MailboxSearches = Search-MailboxContent -Mailbox $ExoMailbox;

    # Foreach mailbox search.
    Foreach($MailboxSearch in $MailboxSearches)
    {
        # Write to log.
        Write-Log ("Exporting search '{0}'" -f $MailboxSearch.SearchName);

        # Export to PST.
        ExportTo-PST -ExportToolPath $PstExport -ExportLocation $Output -SearchName $MailboxSearch.SearchName;

        # Write to log.
        Write-Log ("");
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Disconnect exchange.
Disconnect-ExchangeOnline -Confirm:$false;

############### Finalize - End ###############
#endregion
