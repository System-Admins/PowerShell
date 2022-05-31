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

# Parameters.
[cmdletbinding()]
Param
(
    # Username and password of the user that will be used to truncate tables in the database.
    [Parameter(Mandatory=$false)][string]$SqlUsername = 'xalth@pension.dk',
    [Parameter(Mandatory=$false)][securestring]$SqlPassword = ('17x21Oth!' | ConvertTo-SecureString -AsPlainText -Force),

    # The login type method.
    [Parameter(Mandatory=$true)][ValidateSet("AADPassword", "SQLUser", "AadContext")][string]$SqlLoginType,

    # SQL server and database.
    [Parameter(Mandatory=$true)][string]$SqlServer = 'dg-dev-100-we-dbs.database.windows.net',
    [Parameter(Mandatory=$true)][string]$SqlDatabase = 'dg-dev-100-we-alextest111-db'
)

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
    $DatabaseQuery.Connection = $DatabaseConnection;
    $DatabaseQuery.CommandText = $Query;
    $DatabaseQuery.CommandTimeout = 0;

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
        [string]$ConnectionString = ('Server=tcp:{0},{1};Persist Security Info=False;Authentication=Active Directory Password;User ID={2};Password={3};MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=True;' -f $Server, $Port, $Username, $UnsecurePassword);
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

# Get all tables in a database.
Function Get-DatabaseTable
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString
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
        [Parameter(Mandatory=$true)]$ConnectionString,
        
        # Tables.
        [Parameter(Mandatory=$true)]$Tables
    )

    # Query.
    [string]$Query = "";


    # Foreach table.
    Foreach($Table in $Tables)
    {
        # Add to query.
        $Query += ("EXEC [dbo].[truncate_referenced_table] @TableToTruncate = N'{0}';" -f $Table.name);

        # Write log.
        Write-Log -Text ("Will truncate the table '{0}' with the schema '{1}'" -f $Table.name, $Table.schema)
    }

    # Run truncate query.
    Invoke-SqlQuery -ConnectionString $ConnectionString -Query $Query;
}

# Install stored procedure for trunctate table.
Function Install-TruncateStoredProcedure
{
    [CmdletBinding()]
    param
    (
        # Connection string.
        [Parameter(Mandatory=$true)]$ConnectionString
    )

    # Delete stored procedure.
    Invoke-SqlQuery -ConnectionString $ConnectionString -Query 'DROP PROCEDURE IF EXISTS [dbo].[Truncate_referenced_table]';
    
    # Query.
    [string]$Query = @"
CREATE PROCEDURE [dbo].[Truncate_referenced_table] @TableToTruncate VARCHAR(64)
AS
  BEGIN
      SET nocount ON

      -- GLOBAL VARIABLES
      DECLARE @i INT
      DECLARE @Debug BIT
      DECLARE @Recycle BIT
      DECLARE @Verbose BIT
      DECLARE @TableName VARCHAR(80)
      DECLARE @ColumnName VARCHAR(80)
      DECLARE @ReferencedTableName VARCHAR(80)
      DECLARE @ReferencedColumnName VARCHAR(80)
      DECLARE @ConstraintName VARCHAR(250)
      DECLARE @IsDisabled INT
      DECLARE @CreateStatement VARCHAR(max)
      DECLARE @AlterStatement VARCHAR(max)
      DECLARE @DropStatement VARCHAR(max)
      DECLARE @TruncateStatement VARCHAR(max)
      DECLARE @CreateStatementTemp VARCHAR(max)
      DECLARE @AlterStatementTemp VARCHAR(max)
      DECLARE @DropStatementTemp VARCHAR(max)
      DECLARE @TruncateStatementTemp VARCHAR(max)
      DECLARE @Statement VARCHAR(max)
      DECLARE @Alter VARCHAR(max)

      -- 1 = Will not execute statements 
      SET @Debug = 0
      -- 0 = Will not create or truncate storage table
      -- 1 = Will create or truncate storage table
      SET @Recycle = 0
      -- 1 = Will print a message on every step
      SET @Verbose = 1
      SET @i = 1
      SET @CreateStatement =
'ALTER TABLE [dbo].[<tablename>]  WITH NOCHECK ADD  CONSTRAINT [<constraintname>] FOREIGN KEY([<column>]) REFERENCES [dbo].[<reftable>] ([<refcolumn>])'
    SET @AlterStatement =
    'ALTER TABLE [dbo].[<tablename>] NOCHECK CONSTRAINT <fk_constraint_name>'
    SET @DropStatement =
    'ALTER TABLE [dbo].[<tablename>] DROP CONSTRAINT [<constraintname>]'
    SET @TruncateStatement = 'TRUNCATE TABLE [<tablename>]'

    -- Drop Temporary tables
    IF Object_id('tempdb..#FKs') IS NOT NULL
      DROP TABLE #fks

    -- GET FKs
    SELECT Row_number()
             OVER (
               ORDER BY Object_name(fkc.parent_object_id), clm1.NAME) AS ID,
           Object_name(fkc.constraint_object_id)                      AS
           ConstraintName,
           Object_name(fkc.parent_object_id)                          AS
           TableName,
           clm1.NAME                                                  AS
           ColumnName,
           Object_name(fkc.referenced_object_id)                      AS
           ReferencedTableName,
           clm2.NAME                                                  AS
           ReferencedColumnName,
           fk.is_disabled                                             AS
           IsDisabled
    INTO   #fks
    FROM   sys.foreign_key_columns fkc
           JOIN sys.foreign_keys fk
             ON fkc.constraint_object_id = fk.object_id
           JOIN sys.columns clm1
             ON fkc.parent_column_id = clm1.column_id
                AND fkc.parent_object_id = clm1.object_id
           JOIN sys.columns clm2
             ON fkc.referenced_column_id = clm2.column_id
                AND fkc.referenced_object_id = clm2.object_id
    --WHERE OBJECT_NAME(parent_object_id) not in ('//tables that you do not wont to be truncated')
    WHERE  Object_name(fkc.referenced_object_id) = @TableToTruncate
    ORDER  BY Object_name(fkc.parent_object_id)

    -- Prepare Storage Table
    IF NOT EXISTS(SELECT 1
                  FROM   information_schema.tables
                  WHERE  table_name = 'Internal_FK_Definition_Storage')
      BEGIN
          IF @Verbose = 1
            PRINT '1. Creating Process Specific Tables...'

          -- CREATE STORAGE TABLE IF IT DOES NOT EXISTS
          CREATE TABLE [internal_fk_definition_storage]
            (
               id                        INT NOT NULL IDENTITY(1, 1) PRIMARY KEY
               ,
               fk_name                   VARCHAR(250) NOT NULL,
               fk_creationstatement      VARCHAR(max) NOT NULL,
               fk_alterstatement         VARCHAR(max) NOT NULL,
               fk_destructionstatement   VARCHAR(max) NOT NULL,
               table_truncationstatement VARCHAR(max) NOT NULL
            )
      END
    ELSE
      BEGIN
          IF @Recycle = 0
            BEGIN
                IF @Verbose = 1
                  PRINT '1. Truncating Process Specific Tables...'

                -- TRUNCATE TABLE IF IT ALREADY EXISTS
                TRUNCATE TABLE [internal_fk_definition_storage]
            END
          ELSE
            PRINT
      '1. Process specific table will be recycled from previous execution...'
      END

    IF @Recycle = 0
      BEGIN
          IF @Verbose = 1
            PRINT '2. Backing up Foreign Key Definitions...'

          -- Fetch and persist FKs             
          WHILE ( @i <= (SELECT Max(id)
                         FROM   #fks) )
            BEGIN
                SET @ConstraintName = (SELECT constraintname
                                       FROM   #fks
                                       WHERE  id = @i)
                SET @TableName = (SELECT tablename
                                  FROM   #fks
                                  WHERE  id = @i)
                SET @ColumnName = (SELECT columnname
                                   FROM   #fks
                                   WHERE  id = @i)
                SET @ReferencedTableName = (SELECT referencedtablename
                                            FROM   #fks
                                            WHERE  id = @i)
                SET @ReferencedColumnName = (SELECT referencedcolumnname
                                             FROM   #fks
                                             WHERE  id = @i)
                SET @IsDisabled = (SELECT isdisabled
                                   FROM   #fks
                                   WHERE  id = @i)
                SET @DropStatementTemp = Replace(
                Replace(@DropStatement, '<tablename>'
                ,
                @TableName), '<constraintname>',
                                 @ConstraintName)
                SET @CreateStatementTemp = Replace(
                                           Replace(Replace(Replace(
                Replace(
                        @CreateStatement,
                                '<tablename>', @TableName
                                ),
                                '<column>'
                                        ,
                        @ColumnName),
                                '<constraintname>',
                        @ConstraintName), '<reftable>',
                @ReferencedTableName), '<refcolumn>',
                                           @ReferencedColumnName)
                SET @AlterStatementTemp = CASE @IsDisabled
                                            WHEN 1 THEN Replace(
                                            Replace(
                                                        @AlterStatement,
                                                                '<tablename>',
                                            @TableName
                                            )
                                                        ,
                                                        '<fk_constraint_name>'
                                                        ,
                                                        @ConstraintName)
                                            ELSE ''
                                          END
                SET @TruncateStatementTemp =
                Replace(@TruncateStatement, '<tablename>'
                ,
                @TableName)

                INSERT INTO [internal_fk_definition_storage]
                SELECT @ConstraintName,
                       @CreateStatementTemp,
                       @AlterStatementTemp,
                       @DropStatementTemp,
                       @TruncateStatementTemp

                SET @i = @i + 1

                IF @Verbose = 1
                  PRINT '  > Backing up [' + @ConstraintName
                        + '] from [' + @TableName + ']'
            END
      END
    ELSE
      PRINT '2. Backup up was recycled from previous execution...'

    IF @Verbose = 1
      PRINT '3. Dropping Foreign Keys...'

    -- DROP FOREING KEYS
    SET @i = 1

    WHILE ( @i <= (SELECT Max(id)
                   FROM   [internal_fk_definition_storage]) )
      BEGIN
          SET @ConstraintName = (SELECT fk_name
                                 FROM   [internal_fk_definition_storage]
                                 WHERE  id = @i)
          SET @Statement = (SELECT fk_destructionstatement
                            FROM   [internal_fk_definition_storage] WITH (nolock
                                   )
                            WHERE  id = @i)

          IF @Debug = 1
            PRINT @Statement
          ELSE
            EXEC(@Statement)

          SET @i = @i + 1

          IF @Verbose = 1
            PRINT '  > Dropping [' + @ConstraintName + ']'
      END

    IF @Verbose = 1
      PRINT '4. Truncating Tables...'

    IF @Verbose = 1
      PRINT '  > TRUNCATE TABLE [' + @TableToTruncate
            + ']'

    IF @Debug = 1
      PRINT 'TRUNCATE TABLE [' + @TableToTruncate + ']'
    ELSE
      EXEC('TRUNCATE TABLE [' + @TableToTruncate + ']')

    IF @Verbose = 1
      PRINT '5. Re-creating Foreign Keys...'

    -- CREATE FOREING KEYS
    SET @i = 1

    WHILE ( @i <= (SELECT Max(id)
                   FROM   [internal_fk_definition_storage]) )
      BEGIN
          SET @ConstraintName = (SELECT fk_name
                                 FROM   [internal_fk_definition_storage]
                                 WHERE  id = @i)
          SET @Statement = (SELECT fk_creationstatement
                            FROM   [internal_fk_definition_storage]
                            WHERE  id = @i)
          SET @Alter = (SELECT fk_alterstatement
                        FROM   [internal_fk_definition_storage]
                        WHERE  id = @i)

          IF @Debug = 1
            PRINT @Statement
          ELSE
            EXEC(@Statement)

          IF @Verbose = 1
            PRINT '  > Re-creating [' + @ConstraintName + ']'

          IF @Alter != ''
            BEGIN
                IF @Debug = 1
                  PRINT @Alter
                ELSE
                  EXEC(@alter)

                IF @Verbose = 1
                  PRINT '  > Disabling [' + @ConstraintName + ']'
            END

          SET @i = @i + 1
      END

    IF @Verbose = 1
      PRINT '6. Process Completed'
END 
"@;

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

# Install stored procedure.
Install-TruncateStoredProcedure -ConnectionString $SqlConnectionString;

# Truncate tables.
Truncate-DatabaseTable -ConnectionString $SqlConnectionString -Tables $Tables;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############


############### Finalize - End ###############
#endregion