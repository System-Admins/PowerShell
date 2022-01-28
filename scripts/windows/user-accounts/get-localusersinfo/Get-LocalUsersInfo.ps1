#requires -version 4

<#
.SYNOPSIS
  Get local users with last logon date.

.DESCRIPTION
  Get local users through ADSI on the local machine and exports an CSV on the desktop.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  28-01-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Object array.
$Users = @();

# Get date.
$Today = Get-Date;

# Get all local users.
$LocalUsers = Get-WmiObject -Class Win32_UserAccount -Namespace "root\cimv2" ` -Filter "LocalAccount='$True'";

# Foreach local user.
foreach($LocalUser in $LocalUsers)
{
    # Get local user information.
    $ADSI = ([adsi]("WinNT://{0}/{1},user" -f $env:COMPUTERNAME, $LocalUser.Name));

    # Calculate password age, expiration and last set.
    $PwAge    = $ADSI.PasswordAge.Value;
    $MaxPwAge = $ADSI.MaxPasswordAge.Value;
    $PwLastSet = $Today.AddSeconds(-$pwAge);

    # Create PSObject.
    $User = New-Object -TypeName PSObject -Property @{
        'Name'                 = $LocalUser.Name;
        'Full Name'            = $LocalUser.FullName;
        'Disabled'             = $LocalUser.Disabled;
        'Status'               = $LocalUser.Status;
        'LockOut'              = $LocalUser.LockOut;
        'Password Expires'     = $LocalUser.PasswordExpires;
        'Password Required'    = $LocalUser.PasswordRequired;
        'Account Type'         = $LocalUser.AccountType;
        'Domain'               = $LocalUser.Domain;
        'Password Last Set'    = $PwLastSet.ToString("dd-MM-yyyy");
        'Password Age (Days)'  = ($Today - $PwLastSet).Days;
        'Password Expiry Date' = $Today.AddSeconds($MaxPwAge - $PwAge).ToString("dd-MM-yyyy");
        'Description'          = $LocalUser.Description;
        'Computer'             = $env:COMPUTERNAME;
    }

    # Add to object array.
    $Users += $User;
}

# Export to an CSV file on the desktop.
$Users | Export-Csv -Path ("{0}\LocalUsers.csv" -f [Environment]::GetFolderPath("Desktop")) -Encoding UTF8 -Delimiter ";" -NoTypeInformation -Force;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
