# Modules required.
#Requires -Module Az.Resources;
#Requires -Module Az.Accounts;

# Minimum version required.
#Requires -Version 5.1;

<#
.SYNOPSIS
  Get health events for Azure resources.
    
.DESCRIPTION
  Runs through every Azure resource that the context have access to and invokes the REST api for health events associated with the resource.
  If any health events are found, it will export the results to a CSV file on the desktop of the current user.

.EXAMPLE
  .\Get-AzureResourceHealthEvents.ps1;

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  10-09-2023
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# File path for the CSV export.
$CsvFilePath = ("{0}\{1}_healthevents.csv" -f [Environment]::GetFolderPath("Desktop"), (Get-Date).ToString("yyyyMMdd"));

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Information ("Script started '{0}'" -f (Get-Date)) -InformationAction Continue;

# Get all context.
$AzContexts = Get-AzContext -ListAvailable;

# If we are not connected to Azure.
if($null -eq $AzContexts)
{
    # Connect to Azure.
    try
    {
        # Write to log.
        Write-Information ("Trying to connect to Azure") -InformationAction Continue;

        # Connect to Azure.
        Connect-AzAccount -ErrorAction Stop -WarningAction SilentlyContinue;

        # Write to log.
        Write-Information ("Successfully connected to Azure") -InformationAction Continue;
    }
    # Something went wrong while connecting.
    catch
    {
        # Throw execption.
        throw ("Something went wrong while connecting to Azure, here is the execption:`r`n{0}" -f $_);
    }
}

# Events data.
$EventResults = @();

# Foreach context.
foreach ($AzContext in $AzContexts)
{
    # Get Azure subscription info.
    $AzSubscriptionId = $AzContext.Subscription.Id;
    $AzSubscriptionName = $AzContext.Subscription.Name;

    # Write to log.
    Write-Information ("[{0}]: Setting context to Azure subscription '{0}' ({1})" -f $AzSubscriptionName, $AzSubscriptionId) -InformationAction Continue;

    # Set context.
    Set-AzContext -Subscription $AzSubscriptionId | Out-Null;

    # Write to log.
    Write-Information ("[{0}]: Getting all Azure resources" -f $AzSubscriptionName) -InformationAction Continue;
    
    # Get all resources in subscription.
    $AzResources = Get-AzResource;

    # Foreach resource.
    foreach ($AzResource in $AzResources)
    {
        # Get Azure access token.
        $AccessToken = (Get-AzAccessToken).Token;

        # Construct bearer token for REST.
        $Headers = @{
            'Authorization' = ('Bearer {0}' -f $AccessToken)  
        };

        # Try to invoke.
        try
        {
            # Write to log.
            Write-Information ("[{0}][{1}][{2}]: Getting health events for Azure resource of type '{3}'" -f $AzSubscriptionName, $AzResource.ResourceGroupName, $AzResource.Name, $AzResource.ResourceType) -InformationAction Continue;

            # Invoke REST method.
            $Result = Invoke-RestMethod -Method Get -Uri ('https://management.azure.com/{0}/providers/Microsoft.ResourceHealth/events?api-version=2018-07-01-rc&%24filter=Properties%2FEventType+ne+%27HealthAdvisory%27+and+Properties%2FEventType+ne+%27SecurityAdvisory%27&%24top=1' -f $AzResource.ResourceId) -Headers $Headers;
        }
        catch
        {
            # If the error is an 429.
            if ($_.Exception -like '*429*')
            {
                # Write to log.
                Write-Information ('[{0}][{1}][{2}]: We are being throttled by calling the API' -f $AzSubscriptionName, $AzResource.ResourceGroupName, $AzResource.Name) -InformationAction Continue;

                # Split error message with single quote.
                $ErrorMessageParts = $_.ErrorDetails.Message -split "'";

                # Get seconds to wait.
                #$SecondsToWait = $ErrorMessageParts[$ErrorMessageParts.Count - 2];
                $SecondsToWait = 10;

                # Write to log.
                Write-Information ('[{0}][{1}][{2}]: Waiting {3} seconds before trying to call the REST api again' -f $AzSubscriptionName, $AzResource.ResourceGroupName, $AzResource.Name, $SecondsToWait) -InformationAction Continue;

                # Start sleep.
                Start-Sleep -Seconds $SecondsToWait;

                # Try to invoke again.
                try
                {
                    # Write to log.
                    Write-Information ("[{0}][{1}][{2}]: Trying to get the health events for Azure resource '{1}' in resource group '{2}' of type '{3}' again" -f $AzSubscriptionName, $AzResource.ResourceGroupName, $AzResource.Name, $AzResource.ResourceType) -InformationAction Continue;

                    # Invoke REST method.
                    $Result = Invoke-RestMethod -Method Get -Uri ('https://management.azure.com/{0}/providers/Microsoft.ResourceHealth/events?api-version=2018-07-01-rc&%24filter=Properties%2FEventType+ne+%27HealthAdvisory%27+and+Properties%2FEventType+ne+%27SecurityAdvisory%27&%24top=1' -f $AzResource.ResourceId) -Headers $Headers;
                }
                # Something went wrong.
                catch
                {
                    # Write to log.
                    Write-Information ("[{0}][{1}][{2}]: Something went while trying the seconds time, skipping. The execption is: `r`n {3}" -f $AzSubscriptionName, $AzResource.ResourceGroupName, $AzResource.Name, $_) -InformationAction Continue;
                }
            }
            # Else some other execption.
            else
            {
                # Write to log.
                Write-Information ("[{0}][{1}][{2}]: Something went wrong getting health data, the execption is: `r`n {3}" -f $AzSubscriptionName, $AzResource.ResourceGroupName, $AzResource.Name, $_) -InformationAction Continue;

                # Continue.
                continue;
            }
        }

        # If event data is not empty.
        if (!([string]::IsNullOrEmpty($Result.Value.Id)))
        {
            # Write to log.
            Write-Information ('[{0}][{1}][{2}]: Found events for resource' -f $AzSubscriptionName, $AzResource.ResourceGroupName, $AzResource.Name) -InformationAction Continue;

            # Foreach result value (if multiple events).
            foreach ($Value in $Result.Value)
            {
                # Add to object array.
                $EventResults += [PSCustomObject]@{
                    ResourceSubscriptionName = $AzSubscriptionName;
                    ResourceSubscriptionId   = $AzSubscriptionId;
                    ResourceGroupName        = $AzResource.ResourceGroupName;
                    ResourceName             = $AzResource.ResourceName;
                    ResourceId               = $AzResource.Id;
                    EventName                = $Value.Name;
                    EventId                  = $Value.Id;
                    EventUrl                 = ('https://app.azure.com/h/{0}' -f ($Value.Name));
                    EventStartTime           = $Value.Properties.impactStartTime;
                    EventTitle               = $Value.Properties.title;
                };
            }
        }
    }
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# If there is some events.
if($EventResults.Count -gt 0)
{
    # Write to log.
    Write-Information ("Exporting results to '{0}'" -f $CsvFilePath) -InformationAction Continue;

    # Export to CSV.
    $EventResults | Export-Csv -Path $CsvFilePath -Encoding UTF8 -Delimiter ";" -NoTypeInformation -Force;
}
# Else no events found.
else
{
    # Write to log.
    Write-Information ("No events found for any resources") -InformationAction Continue;
}

# Write to log.
Write-Information ("Script finished '{0}'" -f (Get-Date)) -InformationAction Continue;

# Disconnect from Azure.
Disconnect-AzAccount -ErrorAction SilentlyContinue;

############### Finalize - End ###############
#endregion
