# Variables.
$ImpersonatedUser = "joe@contoso.com";
$EwsUrl = "https://mail.weibel.dk/EWS/Exchange.asmx";
$SearchStart = (Get-Date);
$SearchEnd = (Get-Date).AddYears(1);

# If script running in PowerSHell ISE.
If($psise)
{
    # Set script path.
    $ScriptPath = Split-Path $psise.CurrentFile.FullPath;
}
# Normal PowerShell session.
Else
{
    # Set script path.
    $ScriptPath = $global:PSScriptRoot;
}

# Import module.
Import-Module -Name "$ScriptPath\Microsoft.Exchange.WebServices.dll";

# Get credential (admin user).
$Credential = Get-Credential;

# Create Exchange object.
$ExchangeService = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2016);

# EWS url.
$ExchangeService.Url = $EwsUrl;

# Login to EWS using admin credentials.
$ExchangeService.Credentials = New-Object -TypeName Microsoft.Exchange.WebServices.Data.WebCredentials($Credential);

# Imporsonate user.
$ExchangeService.ImpersonatedUserId = New-Object -TypeName Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $ImpersonatedUser);

# Connect the calendar.
$Calendar = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($ExchangeService, [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Calendar);

# Define the calendar view.
$CalendarView = New-Object Microsoft.Exchange.WebServices.Data.CalendarView($SearchStart,$SearchEnd,1000);

# Find appointments.
$CalendarItems = $ExchangeService.FindAppointments($Calendar.Id,$CalendarView);

# Foreach item.
Foreach($CalendarItem in $CalendarItems)
{
    # Cancel meeting.
    $CalendarItem.CancelMeeting();
} 
