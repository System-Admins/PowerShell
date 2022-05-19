# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Must have the following modules installed.
#Requires -Module Az.Accounts;

# Make sure that you have the following dll (x64) installed:
#https://www.microsoft.com/en-us/download/confirmation.aspx?id=48742

# Also make sure that you have installed the following modules:
#Install-Module -Name Az.Accounts -SkipPublisherCheck -Force -Scope CurrentUser;

<#
.SYNOPSIS
  Copy Azure SQL Database from one server to another.

.DESCRIPTION
  .

.NOTES
  Version:        1.1
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  19-05-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

# Parameters.
Param
(
    # Source - Username and password for the Azure SQL Server.
    [Parameter(Mandatory=$false)][string]$SourceUsername,
    [Parameter(Mandatory=$false)][securestring]$SourcePassword,

    # Source - Login type to user (AAD or SQL).
    [Parameter(Mandatory=$false)][ValidateSet("AADPassword", "SQLUser", "AadContext")][string]$SourceLoginType = 'AadContext', #or SQLUser / AadContext

    # Source - Server where the source database is stored.
    [Parameter(Mandatory=$true)][string]$SourceDbServer,

    # Source - Database to copy from.
    [Parameter(Mandatory=$true)][string]$SourceDbName,

    # Target - Username and password for the Azure SQL Server.
    [Parameter(Mandatory=$false)][string]$TargetUsername,
    [Parameter(Mandatory=$false)][securestring]$TargetPassword,

    # Target - Login type to user (AAD or SQL).
    [Parameter(Mandatory=$false)][ValidateSet("AADPassword", "SQLUser", "AadContext")][string]$TargetLoginType = 'AadContext', #or SQLUser / AadContext

    # Target - Server where the target database will be stored.
    [Parameter(Mandatory=$true)][string]$TargetDbServer,

    # Target - The database that will be created in the target with a copy.
    [Parameter(Mandatory=$true)][string]$TargetDbName
)

# Clear host.
#Clear-Host;

# Import module(s).
Import-Module -Name Az.Accounts -Force -DisableNameChecking;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

############### Input - End ###############
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

# Convert secure password to plain text.
Function Convert-SecurePassword
{
    [CmdletBinding()]
    param
    (
        # Source and destination database server.
        [Parameter(Mandatory=$true)][securestring]$SecureString
    )

    # Convert from secure string to plain text.
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString);
    [string]$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR);

    # Return unsecure password.
    Return $UnsecurePassword;
}

# Execute query against SQL server.
Function Invoke-SqlQuery
{
    [CmdletBinding()]
    param
    (
        # Connection string to the database.
        [Parameter(Mandatory=$true)]$ConnectionString,

        # Query to invoke.
        [Parameter(Mandatory=$true)][string]$Query
    )

    # Write to log.
    #Write-Log -Text ("Executing query:");
    #Write-Log -Text ($Query);

    # Create object with connection string.
    $DatabaseConnection = New-Object System.Data.SqlClient.SqlConnection;
    $DatabaseConnection.ConnectionString = $ConnectionString.ConnectionString;

    # If token is specificed.
    If($ConnectionString.AccessToken)
    {
        # Add the token.
        $DatabaseConnection.AccessToken = $ConnectionString.AccessToken;
    }

    # Connect to database.
    $DatabaseConnection.Open();

    # Construct command.
    $DatabaseQuery = New-Object System.Data.SqlClient.SqlCommand;
    $DatabaseQuery.Connection = $ConnectionString;
    $DatabaseQuery.CommandText = $Query;
    $DatabaseQuery.CommandTimeout = 0;;

    # Fetch all results.
    $Dataset = New-Object System.Data.DataSet;
    $Adapter = New-Object System.Data.SqlClient.SqlDataAdapter;
    $Adapter.SelectCommand = $DatabaseQuery;
    $Adapter.Fill($Dataset) | Out-Null;

    # Close connection.
    $DatabaseConnection.Close();

    # Return results.
    Return $Dataset.Tables;
}

# Get Azure access token.
Function Get-AzureSqlToken
{
    # Resource URL.
    $DbResourceUrl = 'https://database.windows.net/';

    # Get the access token.
    $AccessToken = Get-AzAccessToken -ResourceUrl $dbResourceUrl;

    # Extract the token.
    [string]$Token = $accessToken.Token;

    # Return token.
    Return $Token;
}

# Construct SQL connection string.
Function Get-SqlConnectionString
{
    [CmdletBinding()]
    param
    (
        # Server name.
        [Parameter(Mandatory=$true)][string]$Server,

        # Server port.
        [Parameter(Mandatory=$false)][int]$Port = 1433,

        # Server port.
        [Parameter(Mandatory=$false)][string]$Database = "master",

        # Username.
        [Parameter(Mandatory=$false)][string]$Username,

        # Password.
        [Parameter(Mandatory=$false)][securestring]$Password,

        # Connection type.
        [Parameter(Mandatory=$true)][ValidateSet("AADPassword", "SQLUser", "AadContext")][string]$LoginType
    )

    # If the password is set.
    If($Password)
    {
        # Convert from secure string to plain text.
        [string]$UnsecurePassword = Convert-SecurePassword -SecureString $Password;
    }

    # If the login type is "Azure Active Directory - Passsword".
    If($LoginType -eq "AADPassword")
    {
        # Write to log.
        Write-Log ("Using Azure AD password login for server '{0}' for data '{1}'" -f $Server, $Database);

        # Get basic connection string.
        [string]$ConnectionString = ('Server=tcp:{0},{1};Persist Security Info=False;Authentication=Active Directory Password;User ID={2};Password={3};MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=True;;' -f $Server, $Port, $Username, $UnsecurePassword);
    }
    # Else if the login type is "SQL Server Authentication".
    ElseIf($LoginType -eq "SQLUser")
    {
        # Write to log.
        Write-Log ("Using SQL login for server '{0}' for data '{1}'" -f $Server, $Database);

        # Get basic connection string.
        [string]$ConnectionString = ('Server=tcp:{0},{1};User ID={2};Password={3};MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=True;' -f $Server, $Port, $Username, $UnsecurePassword);
    }
    # Else if the login type is "Azure AD Context".
    ElseIf($LoginType -eq "AadContext")
    {
        # Write to log.
        Write-Log ("Using Azure AD context login for server '{0}' for data '{1}'" -f $Server, $Database);
        
        # Get basic connection string.
        [string]$ConnectionString = ('Data Source={0};Trusted_Connection=False;Encrypt=True;' -f $Server);

        # Get Azure AD token.
        $AadAccessToken = Get-AzureSqlToken;
    }

    # If database is set else we will connect to "master".
    If(!([string]::IsNullOrEmpty($Database)))
    {
        # If Azure AD context authentication.
        If($LoginType -eq "AadContext")
        {
            # Add database to string.
            $ConnectionString += ('Initial Catalog={0};' -f $Database);
        }
        Else
        {
            # Add database to string.
            $ConnectionString += ('Database={0};' -f $Database);
        }
    }

    # Create object.
    $SqlConnection = [PSCustomObject]@{
        ConnectionString = $ConnectionString;
    };

    # If token is set.
    If($AadAccessToken)
    {
        # Set Azure AD token.
        $SqlConnection | Add-Member -MemberType NoteProperty -Name AccessToken -Value $AadAccessToken -Force;
    }

    # Return connection string.
    Return $SqlConnection;
}

# Create SQL login.
Function New-SqlLogin
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString,

        # Login name.
        [Parameter(Mandatory=$true)][string]$LoginName,

        # SID.
        [Parameter(Mandatory=$false)][string]$SID,

        # Password.
        [Parameter(Mandatory=$true)][securestring]$Password
    )

    # If the password is set.
    If($Password)
    {
        # Convert from secure string to plain text.
        [string]$UnsecurePassword = Convert-SecurePassword -SecureString $Password;
    }

    # Get existing.
    $SqlLogins = Get-SqlLogin -ConnectionString $ConnectionString;

    # Check if login already exist.
    If($SqlLogins | Where-Object {$_.Name -eq $LoginName})
    {
        # Write to log.
        Write-Log ("Login '{0}' already exist" -f $LoginName);

        # Update password.
        Reset-SqlLoginPassword -ConnectionString $ConnectionString -LoginName $LoginName -Password $Password;
    }
    Else
    {
        
        # Construct query.
        [string]$Query =
@"
CREATE LOGIN [$LoginName] WITH PASSWORD = N'$UnsecurePassword'
"@;

        # If SID is set.
        If(!([string]::IsNullOrEmpty($SID)))
        {
            # Add to query.
            $Query = ("{0}, SID = {1}" -f $Query, $SID);
        }

        # Try to create.
        Try
        {
            # Create SQL login.
            Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

            # Write to log.
            Write-Log ("Creating new login named '{0}'" -f $LoginName);
        }
        Catch
        {
            # Write to log.
            Write-Log ("Something went wrong creating the login named '{0}'" -f $LoginName);
        }
    }
}

# Create SQL login.
Function New-SqlUser
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString,

        # Login name.
        [Parameter(Mandatory=$true)][string]$LoginName,

        # Default schema.
        [Parameter(Mandatory=$true)][ValidateSet("dbo")][string]$DefaultSchema
    )

    # Get existing.
    $SqlUsers = Get-SqlUser -ConnectionString $ConnectionString;

    # Check if login already exist.
    If($SqlUsers | Where-Object {$_.Name -eq $LoginName})
    {
        # Write to log.
        Write-Log ("SQL user '{0}' already exist" -f $LoginName);
    }
    Else
    {
        # Construct query.
        [string]$Query =
@"
CREATE USER [$LoginName] FOR LOGIN [$LoginName] WITH DEFAULT_SCHEMA=[$DefaultSchema];
"@;

        # Try to create.
        Try
        {
            # Invoke query.
            Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

            # Write to log.
            Write-Log ("Creating new user named '{0}' with the default schema '{1}'" -f $LoginName, $DefaultSchema);
        }
        Catch
        {
            # Write to log.
            Write-Log ("Something went wrong creating the login named '{0}' with the default schema '{1}'" -f $LoginName, $DefaultSchema);
        }
    }
}

# Reset SQL login password.
Function Reset-SqlLoginPassword
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString,

        # Login name.
        [Parameter(Mandatory=$true)][string]$LoginName,

        # Password.
        [Parameter(Mandatory=$true)][securestring]$Password
    )

    # If the password is set.
    If($Password)
    {
        # Convert from secure string to plain text.
        [string]$UnsecurePassword = Convert-SecurePassword -SecureString $Password;
    }

    # Construct query.
    [string]$Query =
@"
ALTER LOGIN $LoginName WITH PASSWORD=N'$UnsecurePassword';
"@;

    # Try to create.
    Try
    {
        # Invoke query.
        Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

        # Write to log.
        Write-Log ("Changed password for login '{0}'" -f $LoginName);
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong changing password for login '{0}'" -f $LoginName);
    }
}

# Add SQL role for login.
Function Add-SqlLoginRole
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString,

        # Login name.
        [Parameter(Mandatory=$true)][string]$LoginName,

        # Role.
        [Parameter(Mandatory=$true)][ValidateSet("dbmanager", "db_owner")][string]$Role
    )

    # Construct query.
    [string]$Query =
@"
ALTER ROLE [$Role] ADD MEMBER [$LoginName];
"@;

    # Try to create.
    Try
    {
        # Invoke query.
        Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

        # Write to log.
        Write-Log ("Adding role to '{0}' with '{1}'" -f $LoginName, $Role);
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong changing role for login '{0}'" -f $LoginName);
    }
}

# Get SQL login.
Function Get-SqlLogin
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString
    )

    # Construct query.
    [string]$Query =
@"
SELECT * FROM sysusers
WHERE islogin = 1
"@;

    # Try to create.
    Try
    {
        # Invoke query.
        $Result = Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

        # Return result.
        Return $Result;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong, getting logins from the database server");
    }
}

# Get SQL user.
Function Get-SqlUser
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString
    )

    # Construct query.
    [string]$Query =
@"
select *
from sys.database_principals
where type not in ('A', 'G', 'R')
      and sid is not null
      and name != 'guest'
"@;

    # Try to create.
    Try
    {
        # Invoke query.
        $Result = Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

        # Return result.
        Return $Result;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong, getting logins from the database server");
    }
}

# Convert binary SID to hash string.
Function ConvertTo-SQLHashString
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]$Binary
    )

    # Add prefix to string.
    $Result = '0x';

    # Foreach binary object.
    $Binary | ForEach-Object {$Result += ('{0:X}' -f $_).PadLeft(2, '0')};
    
    # Return result.
    Return $Result;
}

# Create new database from copy.
Function New-SqlDatabaseFromCopy
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString,

        # Source server name.
        [Parameter(Mandatory=$true)][string]$SourceServer,

        # Source database name.
        [Parameter(Mandatory=$true)][string]$SourceDatabaseName,

        # Destination database name.
        [Parameter(Mandatory=$true)][string]$DestinationDatabaseName,

        # Elastic pool name.
        [Parameter(Mandatory=$false)][string]$ElasticPoolName
    )


    # If elastic pool name is set.
    If(!([string]::IsNullOrEmpty($ElasticPoolName)))
    {
        # Construct query.
        [string]$Query =
@"
CREATE DATABASE [$DestinationDatabaseName]
AS COPY OF [$SourceServer].[$SourceDatabaseName]
(SERVICE_OBJECTIVE = ELASTIC_POOL(name =[$ElasticPoolName]));
"@;
    }
    # No elastic pool name set.
    Else
    {
        # Construct query.
        [string]$Query =
@"
CREATE DATABASE [$DestinationDatabaseName]
AS COPY OF [$SourceServer].[$SourceDatabaseName];
"@;
    }

    # Try to create.
    Try
    {
        # Write to log.
        Write-Log ("Copying database from '{0}' to '{1}'" -f $SourceDatabaseName, $DestinationDatabaseName);

        # Invoke query.
        Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong, while copying the database");
    }
}

# Get elastic pool name for databases.
Function Get-SqlElasticPoolNameForDbs
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString
    )

    # Construct query.
    [string]$Query =
@"
SELECT
       @@SERVERNAME as [ServerName],
       dso.elastic_pool_name,
       d.name as DatabaseName,
       dso.edition
FROM
       sys.databases d inner join sys.database_service_objectives dso on d.database_id = dso.database_id
WHERE d.Name <> 'master'
"@;

    # Try to create.
    Try
    {
        # Invoke query.
        $Result = Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

        # Retur result.
        Return $Result;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong, while getting the elastic pool names for databases");
    }
}

# Drop SQL login.
Function Remove-SqlLogin
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString,

        # Login name.
        [Parameter(Mandatory=$true)][string]$LoginName
    )

    # Construct query.
    [string]$Query =
@"
DROP LOGIN [$LoginName]
"@;

    # Get SQL logins.
    $SqlLogins = Get-SqlLogin -ConnectionString $ConnectionString;

    # Check if login already exist.
    If(!($SqlLogins | Where-Object {$_.Name -eq $LoginName}))
    {
        # Write to log.
        Write-Log ("SQL login '{0}' doesnt exist" -f $LoginName);
    }
    # Login exist.
    Else
    {
        # Try to delete.
        Try
        {
            # Invoke query.
            Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

            # Write to log.
            Write-Log ("Dropped SQL login '{0}'" -f $LoginName);
        }
        Catch
        {
            # Write to log.
            Write-Log ("Something went wrong dropping SQL login '{0}'" -f $LoginName);
        }
    }
}

# Drop SQL user.
Function Remove-SqlUser
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString,

        # Login name.
        [Parameter(Mandatory=$true)][string]$LoginName
    )

    # Construct query.
    [string]$Query =
@"
DROP USER [$LoginName]
"@;

    # Get SQL logins.
    $SqlUsers = Get-SqlUser -ConnectionString $ConnectionString;

    # Check if login already exist.
    If(!($SqlUsers | Where-Object {$_.Name -eq $LoginName}))
    {
        # Write to log.
        Write-Log ("SQL user '{0}' doesnt exist" -f $LoginName);
    }
    # User exist.
    Else
    {
        # Try to create.
        Try
        {
            # Invoke query.
            Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

            # Write to log.
            Write-Log ("Dropped SQL user '{0}'" -f $LoginName);
        }
        Catch
        {
            # Write to log.
            Write-Log ("Something went wrong dropping SQL user '{0}'" -f $LoginName);
        }
    }
}

# Drop SQL database.
Function Remove-SqlDatabase
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString,

        # Login name.
        [Parameter(Mandatory=$true)][string]$Database
    )

    # Construct query.
    [string]$Query =
@"
DROP DATABASE IF EXISTS [$Database];
"@;


    # Try to create.
    Try
    {
        # Invoke query.
        Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

        # Write to log.
        Write-Log ("Dropped database '{0}', if it existed" -f $Database);
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong dropping SQL database '{0}'" -f $Database);
    }
}

# Copy SQL database from server to another in Azure.
Function Copy-AzureSqlDatabase
{
    [CmdletBinding()]
    param
    (
        # Source database server/database details.
        [Parameter(Mandatory=$true)][string]$SourceDbServer,
        [Parameter(Mandatory=$true)][string]$SourceDbName,
        [Parameter(Mandatory=$false)][string]$SourceUsername,
        [Parameter(Mandatory=$false)][securestring]$SourcePassword,
        [Parameter(Mandatory=$true)][ValidateSet("AADPassword", "SQLUser", "AadContext")][string]$SourceLoginType,

        # Target database server/database details.
        [Parameter(Mandatory=$true)][string]$TargetDbServer,
        [Parameter(Mandatory=$true)][string]$TargetDbName,
        [Parameter(Mandatory=$false)][string]$TargetUsername,
        [Parameter(Mandatory=$false)][securestring]$TargetPassword,
        [Parameter(Mandatory=$true)][ValidateSet("AADPassword", "SQLUser", "AadContext")][string]$TargetLoginType
    )

    # Name and password of the user which will be created to do the copy (it will be created).
    [string]$SqlUsername = 'SqlCopyAccount';
    [securestring]$SqlPassword = (New-Password -Length 18 | ConvertTo-SecureString -AsPlainText -Force);

    # Create connection string to source master database.
    $SourceConnectionStringMaster = Get-SqlConnectionString -Server $SourceDbServer `
                                                                    -Username $SourceUsername `
                                                                    -Password $SourcePassword `
                                                                    -LoginType $SourceLoginType;


    # Create connection string to source application database.
    $SourceConnectionStringApplication = Get-SqlConnectionString -Server $SourceDbServer `
                                                                    -Database $SourceDbName `
                                                                    -Username $SourceUsername `
                                                                    -Password $SourcePassword `
                                                                    -LoginType $SourceLoginType;

    # Write to log.
    Write-Log ("Connecting to '{0}' (source)" -f $SourceDbServer);

    # Drop existing login.
    Remove-SqlLogin -ConnectionString $SourceConnectionStringMaster -LoginName $SqlUsername;

    # Drop existing user in master database.
    Remove-SqlUser -ConnectionString $SourceConnectionStringMaster -LoginName $SqlUsername;

    # Drop existing user in application database.
    Remove-SqlUser -ConnectionString $SourceConnectionStringApplication -LoginName $SqlUsername;

    # New SQL login in master.
    New-SqlLogin -ConnectionString $SourceConnectionStringMaster -LoginName $SqlUsername -Password $SqlPassword;

    # Create SQL user in master.
    New-SqlUser -ConnectionString $SourceConnectionStringMaster -LoginName $SqlUsername -DefaultSchema dbo;

    # Add role to master.
    Add-SqlLoginRole -ConnectionString $SourceConnectionStringMaster -LoginName $SqlUsername -Role dbmanager;

    # New SQL user on application database.
    New-SqlUser -ConnectionString $SourceConnectionStringApplication -LoginName $SqlUsername -DefaultSchema dbo;

    # Add role to application database.
    Add-SqlLoginRole -ConnectionString $SourceConnectionStringApplication -LoginName $SqlUsername -Role db_owner;

    # Get source SQL user SID.
    [string]$SourceSqlLoginSid = (Get-SqlLogin -ConnectionString $SourceConnectionStringMaster | Where-Object {$_.Name -eq $SqlUsername} | Select-Object @{Name = "SID"; Expression = {ConvertTo-SQLHashString -Binary $_.sid}}).SID;

    # Create connection string to target master database.
    $DestinationConnectionStringMaster = Get-SqlConnectionString -Server $TargetDbServer `
                                                                    -Username $TargetUsername `
                                                                    -Password $TargetPassword `
                                                                    -LoginType $TargetLoginType;

    # Create connection string to target master database using SQL credentail.
    $DestinationConnectionStringMasterSqlCred = Get-SqlConnectionString -Server $TargetDbServer `
                                                                    -Username $SqlUsername `
                                                                    -Password $SqlPassword `
                                                                    -LoginType SQLUser;

    # Write to log.
    Write-Log "";
    Write-Log ("Connecting to '{0}' (target)" -f $TargetDbServer);

    # Check if source and destination is not the same.
    If($SourceDbServer -ne $TargetDbServer)
    {
        # Drop existing login.
        Remove-SqlLogin -ConnectionString $DestinationConnectionStringMaster -LoginName $SqlUsername;

        # Drop existing user in master database.
        Remove-SqlUser -ConnectionString $DestinationConnectionStringMaster -LoginName $SqlUsername;
    
        # New SQL login in master.
        New-SqlLogin -ConnectionString $DestinationConnectionStringMaster `
                     -LoginName $SqlUsername `
                     -Password $SqlPassword `
                     -SID $SourceSqlLoginSid;

        # New SQL user on master database.
        New-SqlUser -ConnectionString $DestinationConnectionStringMaster `
                    -LoginName $SqlUsername `
                    -DefaultSchema dbo;

        # Add role to master database.
        Add-SqlLoginRole -ConnectionString $DestinationConnectionStringMaster `
                         -LoginName $SqlUsername `
                         -Role dbmanager;
    }
    # Server source and destination is the same.
    Else
    {
        # Write to log.
        Write-Log ("Source and target database server is the same, skipping login/user creation" -f $TargetDbServer);
    }

    # Drop database on destination if it exists.
    Remove-SqlDatabase -ConnectionString $DestinationConnectionStringMaster -Database $TargetDbName;

    # Get elastic pool name.
    $TargetElasticPoolName = Get-SqlElasticPoolNameForDbs -ConnectionString $DestinationConnectionStringMaster | Select-Object -ExpandProperty elastic_pool_name -First 1;

    # Copy database from source to a new database.
    New-SqlDatabaseFromCopy -ConnectionString $DestinationConnectionStringMasterSqlCred `
                            -SourceServer ([string]($SourceDbServer -split "\.")[0]) `
                            -SourceDatabaseName $SourceDbName `
                            -DestinationDatabaseName $TargetDbName `
                            -ElasticPoolName $TargetElasticPoolName;

    # If CDC is enabled.
    If(Get-AzureSqlDatabaseCdc -ConnectionString $DestinationConnectionStringMaster | Where-Object {$_.Name -eq $TargetDbName})
    {
        # Create connection string to target application database.
        $DestinationConnectionStringApplication = Get-SqlConnectionString -Server $TargetDbServer `
                                                                            -Database $TargetDbName `
                                                                            -Username $TargetUsername `
                                                                            -Password $TargetPassword `
                                                                            -LoginType $TargetLoginType;

        # Write to log.
        Write-Log ("Disabling CDC for database '{0}'" -f $TargetDbName);
        
        # Disable CDC.
        Disable-AzureSqlDatabaseCdc -ConnectionString $DestinationConnectionStringApplication;
    }

    # Clean up SQL login and user permission.
    Remove-SqlLogin -ConnectionString $SourceConnectionStringMaster -LoginName $SqlUsername;
    Remove-SqlUser -ConnectionString $SourceConnectionStringMaster -LoginName $SqlUsername;
    Remove-SqlUser -ConnectionString $SourceConnectionStringApplication -LoginName $SqlUsername;
    Remove-SqlLogin -ConnectionString $DestinationConnectionStringMaster -LoginName $SqlUsername;
    Remove-SqlUser -ConnectionString $DestinationConnectionStringMaster -LoginName $SqlUsername;
}

# Generate password.
Function New-Password
{
    param
    (
        [Parameter(Mandatory = $false)][int]$Length = 20
    )
    
    # Characters allowed.
    $CharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@$'.ToCharArray();
    
    # Create new crypto object.
    $RNGCrypto = New-Object System.Security.Cryptography.RNGCryptoServiceProvider;

    # Convert length to bytes.
    $Bytes = New-Object byte[]($Length);
 
    # Get bytes.
    $RNGCrypto.GetBytes($Bytes);
 
    # New char object.
    $Result = New-Object char[]($Length);

    # For each byte.
    for ($i = 0 ; $i -lt $Length ; $i++)
    {
        # Add random char to result.
        $Result[$i] = $CharSet[$Bytes[$i]%$CharSet.Length];
    }
 
    # Combine and return charset.
    Return (-join $Result) + "==";
}

# Get database with CDC enabled.
Function Get-AzureSqlDatabaseCdc
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString
    )

    # Construct query.
    [string]$Query =
@"
SELECT name, database_id, is_cdc_enabled FROM sys.databases
WHERE is_cdc_enabled = 1
"@;

    # Try to create.
    Try
    {
        # Invoke query.
        Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong getting databases with CDC enabled");
    }
}

# Disable database CDC.
Function Disable-AzureSqlDatabaseCdc
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString
    )

    # Construct query.
    [string]$Query =
@"
EXEC sys.sp_cdc_disable_db;
"@;

    # Try to create.
    Try
    {
        # Invoke query.
        Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;
    }
    Catch
    {
        # Write to log.
        Write-Log ("Something went wrong getting databases with CDC enabled");
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Copy Azure SQL database.
Copy-AzureSqlDatabase -SourceDbServer $SourceDbServer `
                      -SourceDbName $SourceDbName `
                      -SourceUsername $SourceUsername `
                      -SourcePassword $SourcePassword `
                      -SourceLoginType $SourceLoginType `
                      -TargetDbServer $TargetDbServer `
                      -TargetDbName $TargetDbName `
                      -TargetUsername $TargetUsername `
                      -TargetPassword $TargetPassword `
                      -TargetLoginType $TargetLoginType;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion
