#Requires -version 5.1;
#Requires -module Microsoft.Graph.Authentication;
#Requires -module Microsoft.Graph.Mail;

# Get MS Graph access token.
function Get-GraphAccessToken
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)][string]$ClientId,
        [Parameter(Mandatory = $true)][string]$ClientSecret,
        [Parameter(Mandatory = $true)][string]$TenantId
    )

    # HTTP Body to get access token.
    $Body = @{
        Grant_Type    = "client_credentials";
        Scope         = "https://graph.microsoft.com/.default";
        Client_Id     = $clientId;
        Client_Secret = $clientSecret;
    };

    # Try to invoke REST method.
    try
    {
        # Write to log.
        Write-Information -MessageData "Getting MS Graph access token" -InformationAction Continue;

        # Get access token.
        $token = (Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token" -Method POST -Body $Body).access_token;

        # Write to log.
        Write-Information -MessageData "MS Graph access token received" -InformationAction Continue;

        # Return access token.
        return $token;
    }
    # If error.
    catch
    {
        # Throw execption.
        throw "Error getting MS Graph access token";
    }
}

# Service principal details.
$clientId = "<id>";
$clientSecret = '<secret>';
$tenantId = "<tenantid>";

# Mailbox details.
$mailboxUserPrincipalName = "<e-mail address>"

# Get access token.
$accessToken = Get-GraphAccessToken -ClientId $clientId -ClientSecret $clientSecret -TenantId $tenantId;

# Write to log.
Write-Information -MessageData "Connecting to Microsoft Graph" -InformationAction Continue;

# Connect to Graph API using token.
Connect-MgGraph -AccessToken ($accessToken | ConvertTo-SecureString -AsPlainText -Force) -NoWelcome;

# Write to log.
Write-Information -MessageData ("Getting latest email from mailbox '{0}'" -f $mailboxUserPrincipalName) -InformationAction Continue;

# Get latest (header) message from mailbox.
$latestMessage.Body = Get-MgUserMessage -UserId $mailboxUserPrincipalName -Top 1;

# Write to log.
Write-Information -MessageData ("`r`nLatest e-mail details:") -InformationAction Continue;
Write-Information -MessageData ("From: {0}" -f $latestMessage.Sender.EmailAddress.Address) -InformationAction Continue;
Write-Information -MessageData ("To: {0}" -f $latestMessage.ToRecipients.EmailAddress.Address) -InformationAction Continue;
Write-Information -MessageData ("DateTime: {0}" -f $latestMessage.SentDateTime) -InformationAction Continue;
Write-Information -MessageData ("Subject: {0}" -f $latestMessage.Subject) -InformationAction Continue;
Write-Information -MessageData ("Message:`r`n{0}" -f $latestMessage.BodyPreview) -InformationAction Continue;
