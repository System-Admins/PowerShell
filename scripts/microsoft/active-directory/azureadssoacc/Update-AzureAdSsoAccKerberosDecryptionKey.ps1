#Requires -Module "AzureAD";
#Requires -Module "ActiveDirectory";
#Requires -Version 5.1;
#Requires -RunAsAdministrator;

# Write to log.
Write-Host "Importing module AzureAD and Active Directory";

# Import module(s).
Import-Module -Name "AzureAD" -Force;
Import-Module -Name "ActiveDirectory" -Force;

# Path to Azure AD SSO module.
$AzureAdSsoModulePath = ("{0}\Microsoft Azure Active Directory Connect\AzureADSSO.psd1" -f $env:ProgramFiles);

# If module file dont exist.
if(-not (Test-Path -Path $AzureAdSsoModulePath -ErrorAction SilentlyContinue))
{
    # Throw exception.
    throw ("The file '{0}' dont exist on the server, please make sure that you are on the Azure AD Connect server" -f $AzureAdSsoModulePath);
}

# Write to log.
Write-Host ("Importing module from '{0}'" -f $AzureAdSsoModulePath);

# Import Azure AD SSO module.
Import-Module $AzureAdSsoModulePath;

# Write to log.
Write-Host ("Get Azure AD context");

# Get Azure AD context.
New-AzureADSSOAuthenticationContext | Out-Null;

# Get on-premise Active Directory credential.
$ADCredential = Get-Credential -Message "The domain administrator credentials username must be entered in the SAM account name format (contoso\johndoe or contoso.com\johndoe). This will be used to update the kerberos decryption key for the AZUREADSSO computer account in this specific AD forest and updates it in Azure AD.";

# Get Azure AD SSO computer account.
$AzureADSSOComputerAccount = Get-AzureADSSOComputerAcccountInformation -OnPremCredentials $ADCredential;

# If AD account exist.
if($null -eq $AzureADSSOComputerAccount)
{
    # Throw exception.
    throw ("The Azure AD SSO computer account dont exist");
}
else
{
    # Write to log.
    Write-Host ("Found Azure AD SSO computer object at '{0}'" -f $AzureADSSOComputerAccount.DN);
}

# Get last password reset.
$AdSsoComputerAccount = Get-ADComputer -Identity $AzureADSSOComputerAccount.DN -Properties pwdLastSet;

# If password last set exist.
if($null -ne $AdSsoComputerAccount.pwdLastSet)
{
    # Convert to datetime.
    $PasswordLastSet = [datetime]::FromFileTime($AdSsoComputerAccount.pwdLastSet);

    # Write to log.
    Write-Host ("Password for '{0}' was last set '{1}'" -f $AzureADSSOComputerAccount.DN, $PasswordLastSet);
}
# Else no password set.
else
{
    # Convert to datetime.
    $PasswordLastSet = [datetime]::MinValue;

    # Write to log.
    Write-Host ("Password for '{0}' was never reset" -f $AzureADSSOComputerAccount.DN, $PasswordLastSet);
}

# Get time span.
$TimeSpan = New-TimeSpan -Start $PasswordLastSet -End (Get-Date);

# If password reset was reset within last 10 hours (kerberos default lifetime).
if($TimeSpan.TotalHours -le 10)
{
    # Write to log.
    Write-Host ("Password was already reset within the last 10 hours, skipping reset so Kerberos can catch up");

    # Throw exception.
    throw ("Password was already reset within the last 10 hours, skipping reset so Kerberos can catch up");
}

# Try to roll over kerberos decryption key.
try
{
    # Write to log.
    Write-Host ("Trying to roll over Kerberos decryption key");

    # Update the kerberos decryption key for the AZUREADSSO
    Update-AzureADSSOForest -OnPremCredentials $ADCredential -PreserveCustomPermissionsOnDesktopSsoAccount;

    # Write to log.
    Write-Host ("Succesfull roll over the Kerberos decryption key");
}
catch
{
    # Write to log.
    Write-Host ("Something went wrong while updating Kerberos decryption key");
    
    # Throw exception.
    throw ($_);
}
