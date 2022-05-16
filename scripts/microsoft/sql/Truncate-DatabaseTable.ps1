# Must be running PowerShell version 5.1.
#Requires -Version 5.1;

# Make sure that you have the following dll (x64) installed, if you need to use the Azure AD authentication method:
#https://www.microsoft.com/en-us/download/confirmation.aspx?id=48742

<#
.SYNOPSIS
  Truncate tables in database.

.DESCRIPTION
  .

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  16-05-2022
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Username and password of the user that will be used to truncate tables in the database.
[string]$SqlUsername = '<username>';
[securestring]$SqlPassword = ('<password>' | ConvertTo-SecureString -AsPlainText -Force);

# The login type method.
[string]$SqlLoginType = 'AADPassword'; # or SQLUser

# SQL server and database.
[string]$SqlServer = '<server>.database.windows.net';
[string]$SqlDatabase = '<database>';

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
        Write-Output("");
    }
    Else
    {
        # Write to the console.
        Write-Output("[{0}]: {1}" -f (Get-Date).ToString("dd/MM-yyyy HH:mm:ss"), $Text);
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
        [Parameter(Mandatory=$true)][string]$ConnectionString,

        # Query to invoke.
        [Parameter(Mandatory=$true)][string]$Query
    )

    # Write to log.
    #Write-Log -Text ("Executing query:");
    #Write-Log -Text ($Query);

    # Connect to database.
    $DatabaseConnection = New-Object System.Data.SqlClient.SqlConnection;
    $DatabaseConnection.ConnectionString = $ConnectionString;
    $DatabaseConnection.Open();

    # Construct command.
    $DatabaseQuery = New-Object System.Data.SqlClient.SqlCommand;
    $DatabaseQuery.Connection = $DatabaseConnection;
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
        [Parameter(Mandatory=$false)][string]$Database,

        # Username.
        [Parameter(Mandatory=$true)][string]$Username,

        # Password.
        [Parameter(Mandatory=$true)][securestring]$Password,

        # Connection type.
        [Parameter(Mandatory=$true)][ValidateSet("AADPassword", "SQLUser")][string]$LoginType
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
        # Get basic connection string.
        [string]$ConnectionString = ('Server=tcp:{0},{1};Persist Security Info=False;Authentication=Active Directory Password;User ID={2};Password={3};MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=True;' -f $Server, $Port, $Username, $UnsecurePassword);
    }
    # Else if the login type is "SQL Server Authentication".
    ElseIf($LoginType -eq "SQLUser")
    {
        # Get basic connection string.
        [string]$ConnectionString = ('Server=tcp:{0},{1};User ID={2};Password={3};MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=True;' -f $Server, $Port, $Username, $UnsecurePassword);
    }

    # If database is set.
    If(!([string]::IsNullOrEmpty($Database)))
    {
        # Add database to string.
        $ConnectionString += ('Database={0};' -f $Database);
    }

    # Return connection string.
    Return $ConnectionString;
}

# Get all tables in a database.
Function Get-DatabaseTable
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)][string]$ConnectionString
    )

    # Query to get all tables.
    $Query = @"
SELECT t.name AS [name], s.name AS [schema]
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.[name] <> 'sysdiagrams' 
        AND t.is_ms_shipped = 0
"@;


    # Get tables.
    $Tables = Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;

    # Return the result.
    Return $Tables;
}

# Truncate table.
Function Truncate-DatabaseTable
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)][string]$ConnectionString,
        
        # Tables.
        [Parameter(Mandatory=$true)]$Tables
    )

    # Query.
    [string]$Query = "";


    # Foreach table.
    Foreach($Table in $Tables)
    {
        # Add to query.
        $Query += ("TRUNCATE TABLE [{0}].[{1}];`r`n" -f $Table.schema, $Table.name);

        # Write log.
        Write-Log -Text ("Will truncate the table '{0}' with the schema '{1}'" -f $Table.name, $Table.schema)
    }

    # Run truncate query.
    Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Construct connection string.
$SqlConnectionString = Get-SqlConnectionString -Server $SqlServer -Username $SqlUsername -Password $SqlPassword -Database $SqlDatabase -LoginType $SqlLoginType;

# Get all database tables.
$Tables = Get-DatabaseTable -ConnectionString $SqlConnectionString;

# Truncate tables.
Truncate-DatabaseTable -ConnectionString $SqlConnectionString -Tables $Tables;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion