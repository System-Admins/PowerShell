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

# Send mail message through Graph API.
function Send-GraphMailMessage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)][string]$AccessToken,
        [Parameter(Mandatory = $true)][string]$FromAddress,
        [Parameter(Mandatory = $true)][string]$ToAddress,
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $false)][string]$ReplyTo,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][bool]$SaveToSentItems = $false
    )

    # URI.
    $uri = "https://graph.microsoft.com/v1.0/users/$fromAddress/sendMail";

    # HTTP headers.
    $headers = @{
        "Authorization" = ("Bearer {0}" -f $AccessToken);
        "Content-type"  = "application/json";
    }

    # HTTP body.
    $body = @{
        "message"         = @{
            "subject"      = $Subject;
            "body"         = @{
                "contentType" = "html";
                "content"     = $Message;
            };
            "toRecipients" = @(
                @{
                    "emailAddress" = @{
                        "address" = $ToAddress;
                    };
                };
            );
        };
        "saveToSentItems" = $SaveToSentItems;
    };

    # If reply to address is specified.
    if ($null -ne $ReplyTo)
    {
        # Add reply to address to body.
        $body.message.replyTo = @(
            @{
                "emailAddress" = @{
                    "address" = $ReplyTo;
                };
            };
        );
    }
    
    # Convert to JSON.
    $body = $body | ConvertTo-Json -Depth 6;

    # Try to invoke REST method.
    try
    {
        # Write to log.
        Write-Information -MessageData ("Sending mail message to {0}." -f $toAddress) -InformationAction Continue;

        # Invoke REST method.
        Invoke-RestMethod -Uri $uri -Headers $headers -Method POST -Body $body | Out-Null;

        # Write to log.
        Write-Information -MessageData ("Mail message sent to {0}." -f $toAddress) -InformationAction Continue;
    }
    # If error.
    catch
    {
        # Write to log.
        throw ("Error sending mail message to {0}, execption is '{1}'" -f $toAddress, $_);
    }
}

# Service principal details.
$clientId = "<client id>";
$clientSecret = '<client secret>';
$tenantId = "<tenant id>";

# Get access token.
$accessToken = Get-GraphAccessToken -ClientId $clientId -ClientSecret $clientSecret -TenantId $tenantId;

# Mail details.
$fromAddress = "from@contoso.com";
$toAddress = "to@contoso.com";
$replyTo = "replyToThisEmail@contoso.com";
$subject = "My Subject";
$message = "Hello World!";

# Send mail message.
Send-GraphMailMessage -AccessToken $accessToken -FromAddress $fromAddress -ToAddress $toAddress -Subject $subject -Message $message;
