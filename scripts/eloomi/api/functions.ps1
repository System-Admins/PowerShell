# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

<#
.SYNOPSIS
  PowerShell functions to interact with the Eloomi API.

.DESCRIPTION
  Uses the Eloomi API to create/remove/update users, teams and departments in Eloomi.
  See the API at "https://apidocs.eloomi.com/v3/guides/home".

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  21-10-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin input
############### Variables - Start ###############

# Eloomi API connection strings.
[string]$EloomiClientId = '<provided by Eloomi>';
[string]$EloomiClientSecret = '<provided by Eloomi>';

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Write to log.
Function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Text
    )
  
    # If text is not present.
    If([string]::IsNullOrEmpty($Text))
    {
        # Write to the console.
        Write-Host("");
    }
    Else
    {
        # Write to the console.
        Write-Host("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text);
    }
}

# Get Eloomi access token.
Function Get-EloomiAccessToken
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$true)][string]$ClientSecret,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/oauth/token'
    )

    # Create body.  
    $Body = @{
        'grant_type' = 'client_credentials';
        'client_id' = $ClientId;
        'client_secret' = $ClientSecret;
    } | ConvertTo-Json;

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Getting access token from Eloomi");

        # Invoke.
        $AccessToken = Invoke-RestMethod -Method Post -Uri $Uri -Body $Body -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $AccessToken;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while getting the access token in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Get Eloomi user(s).
Function Get-EloomiUser
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][ValidateSet("all", "pending", "active", "inactive", "suspended")][string]$Mode = "all",
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/users',
        [Parameter(Mandatory=$false)][string]$Id
    )

    # If team id is set.
    If(!([string]::IsNullOrEmpty($Id)))
    {
        # Set URI for specific object.
        $Uri = ("{0}/{1}" -f $Uri, $Id);
    }

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
        'mode' = $Mode;
    };

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Getting user(s) from Eloomi" -f $Mode);

        # Invoke.
        $Result = Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -Body $Body -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while getting the users in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Create Eloomi user.
Function New-EloomiUser
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/users',
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$false)][string]$FirstName,
        [Parameter(Mandatory=$false)][string]$LastName
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
        'email' = $Email;
        'activate' = 'instant';
    };

    # If firstname is set.
    If(!([string]::IsNullOrEmpty($FirstName)))
    {
        # Add to body.
        $Body.Add('first_name', $FirstName);
    }

    # If lastname is set.
    If(!([string]::IsNullOrEmpty($LastName)))
    {
        # Add to body.
        $Body.Add('last_name', $LastName);
    }

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Create user '{0}' in Eloomi" -f $Email);

        # Invoke.
        $Result = Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while create the user in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Update Eloomi user.
Function Set-EloomiUser
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/users-email/',
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$false)][string]$NewEmail,
        [Parameter(Mandatory=$false)][string]$FirstName,
        [Parameter(Mandatory=$false)][string]$LastName,
        [Parameter(Mandatory=$false)][string]$Title,
        [Parameter(Mandatory=$false)][string]$MobilePhone,
        [Parameter(Mandatory=$false)][string]$Phone,
        [Parameter(Mandatory=$false)][ValidateSet("deactivate", "standard", "company_default", "pre_generated_password", "instant", $null)][string]$Status = $null
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
    };

    # If firstname is set.
    If(!([string]::IsNullOrEmpty($FirstName)))
    {
        # Add to body.
        $Body.Add('first_name', $FirstName);
    }

    # If lastname is set.
    If(!([string]::IsNullOrEmpty($LastName)))
    {
        # Add to body.
        $Body.Add('last_name', $LastName);
    }

    # If status is set.
    If(!([string]::IsNullOrEmpty($Status)))
    {
        # Add to body.
        $Body.Add('activate', $Status);
    }

    # If title is set.
    If(!([string]::IsNullOrEmpty($Title)))
    {
        # Add to body.
        $Body.Add('title', $Title);
    }

    # If mobile phone is set.
    If(!([string]::IsNullOrEmpty($MobilePhone)))
    {
        # Add to body.
        $Body.Add('mobile_phone', $MobilePhone);
    }

    # If phone is set.
    If(!([string]::IsNullOrEmpty($Phone)))
    {
        # Add to body.
        $Body.Add('phone', $Phone);
    }

    # If phone is set.
    If(!([string]::IsNullOrEmpty($NewEmail)))
    {
        # Add to body.
        $Body.Add('email', $NewEmail);
    }

    # If body have updates.
    If($Body.Keys.Count -gt 0)
    {
        # Try to invoke.
        Try
        {
            # Write to log.
            Write-Log ("Updating user '{0}' in Eloomi" -f $Email);

            # Invoke.
            $Result = Invoke-RestMethod -Method Patch -Uri ($Uri + $Email) -Headers $Headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8';

            # Return token.
            Return $Result.data;
        }
        Catch
        {
            # Write to log.
            Write-Log ("Something went wrong while updating the user in Eloomi");

            # Throw exception.
            Throw($Error[0]);
        }
    }
    # No updates.
    Else
    {
        # Write to log.
        Write-Log ("No updates is set for user '{0}', skipping" -f $Email);
    }
}

# Remove Eloomi user.
Function Remove-EloomiUser
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/users-email/',
        [Parameter(Mandatory=$true)][string]$Email
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
        'activate' = $Status;
    } | ConvertTo-Json;

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Deleting user '{0}' in Eloomi" -f $Email);

        # Invoke.
        $Result = Invoke-RestMethod -Method Delete -Uri ($Uri + $Email) -Headers $Headers -Body $Body -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while deleting the user in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Create Eloomi department.
Function New-EloomiDepartment
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/units',
        [Parameter(Mandatory=$true)][string]$Code,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)][string]$ParentId
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
        'code' = $Code;
        'name' = $Name;
    };

    # If parent code is set.
    If(!([string]::IsNullOrEmpty($ParentId)))
    {
        # Add to body.
        $Body.Add('parent_id', $ParentId);
    }

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Create department '{0}' ({1}) in Eloomi" -f $Code, $Name);

        # Invoke.
        $Result = Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while create the department in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Update Eloomi department.
Function Set-EloomiDepartment
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/units/',
        [Parameter(Mandatory=$true)][string]$Id,
        [Parameter(Mandatory=$false)][string]$Name,
        [Parameter(Mandatory=$false)][string]$ParentId
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
    };

    # If name is set.
    If(!([string]::IsNullOrEmpty($Name)))
    {
        # Add to body.
        $Body.Add('name', $Name);
    }

    # If parent code is set.
    If(!([string]::IsNullOrEmpty($ParentId)))
    {
        # Add to body.
        $Body.Add('parent_id', $ParentId);
    }

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Updating department '{0}' in Eloomi" -f $Id);

        # Invoke.
        $Result = Invoke-RestMethod -Method Patch -Uri ($Uri + $Id) -Headers $Headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while updating the department in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Remove Eloomi department.
Function Remove-EloomiDepartment
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/units/',
        [Parameter(Mandatory=$true)][string]$Id
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Deleting department '{0}' in Eloomi" -f $Id);

        # Invoke.
        $Result = Invoke-RestMethod -Method Delete -Uri ($Uri + $Id) -Headers $Headers -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while removing the department in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Adding users to an Eloomi department.
Function Add-EloomiDepartmentUser
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/units/',
        [Parameter(Mandatory=$true)][string]$Id,
        [Parameter(Mandatory=$true)][string[]]$UserId
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
    };

    # If id is set.
    If($UserId.Length -gt 0)
    {
        # Add to body.
        $Body.Add('add_user_ids', $UserId);
    }

    # Try to invoke.
    Try
    {
        # Foreach user.
        Foreach($User in $UserId)
        {
            # Write to log.
            Write-Log ("Adding user ID '{0}' to department '{1}' in Eloomi" -f $User, $Id);
        }

        # Invoke.
        $Result = Invoke-RestMethod -Method Patch -Uri ($Uri + $Id) -Headers $Headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while adding users to the department in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Get Eloomi departments.
Function Get-EloomiDepartment
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/units',
        [Parameter(Mandatory=$false)][string]$Id
    )

    # If team id is set.
    If(!([string]::IsNullOrEmpty($Id)))
    {
        # Set URI for specific object.
        $Uri = ("{0}/{1}" -f $Uri, $Id);
    }

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Getting all departments from Eloomi");

        # Invoke.
        $Result = Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while getting the departments in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Remove users from a Eloomi department.
Function Remove-EloomiDepartmentUser
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/units/',
        [Parameter(Mandatory=$true)][string]$Id,
        [Parameter(Mandatory=$true)][string[]]$UserId
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
    };

    # If id is set.
    If($UserId.Length -gt 0)
    {
        # Add to body.
        $Body.Add('remove_user_ids', $UserId);
    }

    # Try to invoke.
    Try
    {
        # Foreach user.
        Foreach($User in $UserId)
        {
            # Write to log.
            Write-Log ("Removing user ID '{0}' to department '{1}' in Eloomi" -f $User, $Code);
        }

        # Invoke.
        $Result = Invoke-RestMethod -Method Delete -Uri ($Uri + $Id) -Headers $Headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while removing users from the department in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Get Eloomi departments.
Function Get-EloomiTeam
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/teams',
        [Parameter(Mandatory=$false)][string]$Id
    )

    # If team id is set.
    If(!([string]::IsNullOrEmpty($Id)))
    {
        # Set URI for specific object.
        $Uri = ("{0}/{1}" -f $Uri, $Id);
    }

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Getting team(s) from Eloomi");

        # Invoke.
        $Result = Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while getting the teams in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Create Eloomi team.
Function New-EloomiTeam
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/teams',
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Description
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
        'code' = $Code;
        'name' = $Name;
    };

    # If description is set.
    If(!([string]::IsNullOrEmpty($Description)))
    {
        # Add to body.
        $Body.Add('description', $Description);
    }

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Create team '{0}' in Eloomi" -f $Name);

        # Invoke.
        $Result = Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while create the team in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Update Eloomi department.
Function Set-EloomiTeam
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/teams/',
        [Parameter(Mandatory=$true)][string]$Id,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Description
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
        'name' = $Name;
    };

    # If description is set.
    If(!([string]::IsNullOrEmpty($Description)))
    {
        # Add to body.
        $Body.Add('description', $Description);
    }

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Updating team '{0}' in Eloomi" -f $Id);

        ($Body | ConvertTo-Json)

        # Invoke.
        $Result = Invoke-RestMethod -Method Patch -Uri ($Uri + $Id) -Headers $Headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while updating the team in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Remove Eloomi team.
Function Remove-EloomiTeam
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/teams/',
        [Parameter(Mandatory=$true)][string]$Id
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Try to invoke.
    Try
    {
        # Write to log.
        Write-Log ("Deleting team '{0}' in Eloomi" -f $Id);

        # Invoke.
        $Result = Invoke-RestMethod -Method Delete -Uri ($Uri + $Id) -Headers $Headers -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while removing the team in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

# Ovewrite users for a Eloomi team.
Function Set-EloomiTeamUser
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$Uri = 'https://api.eloomi.com/v3/teams/',
        [Parameter(Mandatory=$true)][string]$Id,
        [Parameter(Mandatory=$true)][int[]]$UserId
    )

    # Create header.  
    $Headers = @{
        'Authorization' = ('Bearer {0}' -f $AccessToken);
        'ClientId' = $ClientId;
    };

    # Create body.  
    $Body = @{
    };

    # If id is set.
    If($UserId.Length -gt 0)
    {
        # Add to body.
        $Body.Add('user_ids', $UserId);
    }

    # Try to invoke.
    Try
    {
        # Foreach user.
        Foreach($User in $UserId)
        {
            # Write to log.
            Write-Log ("Adding user ID '{0}' to team '{1}' in Eloomi" -f $User, $Id);
        }

        # Invoke.
        $Result = Invoke-RestMethod -Method Patch -Uri ($Uri + $Id) -Headers $Headers -Body ($Body | ConvertTo-Json) -ContentType 'application/json; charset=utf-8';

        # Return token.
        Return $Result.data;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong while adding users to the team in Eloomi");

        # Throw exception.
        Throw($Error[0]);
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

<#

# Get Eloomi access token.
$EloomiAccessToken = (Get-EloomiAccessToken -ClientId $EloomiClientId -ClientSecret $EloomiClientSecret).access_token;

# Create parameter splash for functions.
$Token = @{
    AccessToken = $EloomiAccessToken;
    ClientId = $ClientId;
};

# Get all users from Eloomi.
$EloomiUsers = Get-EloomiUser -AccessToken $EloomiAccessToken -ClientId $ClientId;

# Get all users from Eloomi.
$EloomiUser = Get-EloomiUser -AccessToken $EloomiAccessToken -ClientId $ClientId -Id 67;

# New Eloomi user.
$NewEloomiUser = New-EloomiUser @Token -Email "user@contoso.com" -FirstName "User" -LastName "Contoso";

# Update Eloomi user properties.
Set-EloomiUser @Token -Email "user@contoso.com" -Title "Test User Update" -Phone "+4512345678";

# Set user as admin.
$EloomiAdmin = Set-EloomiAdmin @Token -Email "user@contoso.com" -Admin:$true;

# Remove Eloomi user.
Remove-EloomiUser @Token -Email "user@contoso.com";

# Get all Eloomi departments.
$EloomiDepartments = Get-EloomiDepartment @Token;

# Get Eloomi department.
$EloomiDepartment = Get-EloomiDepartment @Token -Id "<id of the department>";

# New Eloomi department.
$EloomiNewDepartment = New-EloomiDepartment @Token -Code "test" -Name "Contoso Department";

# Update Eloomi department properties.
Set-EloomiDepartment @Token -Id 13 -Name "Contoso Department Update";

# Add Eloomi user to department.
Add-EloomiDepartmentUser @Token -Id "<id of the department>" -UserId "<id of the user(s)>";

# Remove Eloomi user from department.
Remove-EloomiDepartmentUser @Token -Id "<id of the department>" -UserId "<id of the user(s)>";

# Remove Eloomi department.
Remove-EloomiDepartment @Token -Id "<id of the department>";

# Get all Eloomi teams.
$EloomiTeams = Get-EloomiTeam @Token;

# Get Eloomi team.
$EloomiTeam = Get-EloomiTeam @Token -Id "<id of the team>";

# New Eloomi team.
New-EloomiTeam @Token -Name "Contoso Team" -Description "Test team";

# Update team members (overwrites users).
Set-EloomiTeamUser @Token -Id "<id of the team>" -UserId "<id of the user(s)>";

# Remove Eloomi team.
Remove-EloomiTeam @Token -Id "<id of the team>";

#>

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion
