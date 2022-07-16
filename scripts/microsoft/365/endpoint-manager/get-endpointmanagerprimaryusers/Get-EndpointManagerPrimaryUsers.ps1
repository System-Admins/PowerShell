#requires -version 3

<#
.SYNOPSIS
  Get all primary users of managed devices in Microsoft Intune.

.DESCRIPTION
  Get all devices from Intune, then it goes through every devices an extract the primary users.
  The authentication is through a service principal.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  18-03-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Tenant Id.
$TenantId = ".....";

# Client Id.
$ClientId = ".....";
 
# Client secret.
$ClientSecret = '....';

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Get Microsoft Graph token.
Function Get-MicrosoftGraphToken
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory=$true)][string]$TenantId,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$true)][string]$ClientSecret
    )

    # Construct the body.
    $Body = @{
        client_id     = $clientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $clientSecret
        grant_type    = "client_credentials"
    }

    # Construct the authentication URL.
    $Uri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token";
 
    # Get Authentication Token.
    $TokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing;
 
    # Extract the Access Token.
    $Token = ($TokenRequest.Content | ConvertFrom-Json).access_token;

    # Return token.
    Return @{Authorization = ("Bearer {0}" -f $Token)};
}

# Get managed devices.
Function Get-IntuneManagedDevice
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory=$true)]$Headers
    )
 
    # Invoke request.
    $Request = Invoke-WebRequest -Method Get -ContentType "application/json" -Headers $Headers -Uri 'https://graph.microsoft.com/beta/deviceManagement/managedDevices' -UseBasicParsing;
 
    # Extract the Access Token.
    $Result = ($Request.Content | ConvertFrom-Json).value;

    # Return token.
    Return $Result;
}

# Get managed devices.
Function Get-IntuneManagedDevicePrimaryUser
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory=$true)]$Headers,
        [Parameter(Mandatory=$true)]$ManagedDevices
    )

    # Object array.
    $Result = @();

    # Counter.
    $Counter = 1;
 
    # Foreach (Windows) device.
    Foreach($ManagedDevice in $ManagedDevices)
    {
        # Write to screen.
        Write-Host ("Fetching device '{0}' ({1}/{2})" -f $ManagedDevice.deviceName, $Counter, $ManagedDevices.Count);

        # Get primary user.
        $PrimaryUser = (Invoke-WebRequest -Method Get -ContentType "application/json" -Headers $Headers -Uri ('https://graph.microsoft.com/beta/deviceManagement/managedDevices/{0}/users' -f $ManagedDevice.Id) -UseBasicParsing | ConvertFrom-Json).Value;

        # Check if primary user is assigned.
        If($PrimaryUser)
        {
            # Add primary user to managed devices.
            $ManagedDevice | Add-Member -NotePropertyName primaryUserId -NotePropertyValue $PrimaryUser.Id;
            $ManagedDevice | Add-Member -NotePropertyName primaryUserPrincipalName -NotePropertyValue $PrimaryUser.userPrincipalName;
        }
        # No primary user.
        Else
        {
            # Add primary user to managed devices.
            $ManagedDevice | Add-Member -NotePropertyName primaryUserId -NotePropertyValue "";
            $ManagedDevice | Add-Member -NotePropertyName primaryUserPrincipalName -NotePropertyValue "";
        }

        # Add to object array.
        $Result += $ManagedDevice;

        # Add to counter.
        $Counter++;
    }

    # Return token.
    Return $Result;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Get token.
$Headers = Get-MicrosoftGraphToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret;

# Get managed devices.
$ManagedDevices = Get-IntuneManagedDevice -Headers $Headers;

# Get primary users.
$ManagedDevicePrimaryUsers = Get-IntuneManagedDevicePrimaryUser -Headers $Headers -ManagedDevices $ManagedDevices;

# Output to JSON.
$ManagedDevicePrimaryUsers | ConvertTo-JSON | Out-File -FilePath "deviceprimaryusers.json" -Encoding utf8 -Force;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion