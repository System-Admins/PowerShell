#region begin functions
############### Functions - Start ###############

# Convert binary SID to hash string.
function ConvertTo-SQLHashString
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]$Binary
    )

    # Convert binary sid to string.
    $Result = '0x';
    $Binary | ForEach-Object { $Result += ('{0:X}' -f $_).PadLeft(2, '0') };

    # Return string.
    return [string]$Result;
}

# Convert SQL hash to unique identifier (GUID).
function ConvertFrom-SQLHashStringToGuid
{
    [CmdletBinding()]
    param
    (
        # Hash in string format.
        [Parameter(Mandatory = $true)][string]$Hash
    )

    # Remove 0x if it exist.
    $Octet = ($Hash -replace "0x", "");

    # Get octets.
    $Octet1 = $Octet.substring(0, 2);
    $Octet2 = $Octet.substring(2, 2);
    $Octet3 = $Octet.substring(4, 2);
    $Octet4 = $Octet.substring(6, 2);
    $Octet5 = $Octet.substring(8, 2);
    $Octet6 = $Octet.substring(10, 2);
    $Octet7 = $Octet.substring(12, 2);
    $Octet8 = $Octet.substring(14, 2);
    $Octet9 = $Octet.substring(16, 4);
    $Octet10 = $Octet.substring(20, 12);
    
    # Re-arrange octets.
    [string]$Guid = "$Octet4" + "$Octet3" + "$Octet2" + "$Octet1" + "-" + "$Octet6" + "$Octet5" + "-" + "$Octet8" + "$Octet7" + "-" + "$Octet9" + "-" + "$Octet10";

    # Return Guid.
    return $Guid;
}

# Convert Azure AD object id to SQL sid.
function ConvertFrom-AzureAdIdToSqlGuid
{
   
    [CmdletBinding()]
    param
    (
        # Hash in string format.
        [Parameter(Mandatory = $true)][string]$Id
    )

    # Parse ID to as guid.
    [guid]$Guid = [System.Guid]::Parse($Id);

    # Assign byte guid.
    [string]$ByteGuid = "";

    # Foreach byte in the guid.
    foreach ($Byte in $Guid.ToByteArray())
    {
        # Add to string.
        $ByteGuid += [System.String]::Format("{0:X2}", $byte)
    }

    # Return SQL guid hash.
    return "0x" + $ByteGuid;
}


############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Convert Azure AD object id to SQL SID hash.
ConvertFrom-AzureAdIdToSqlGuid -Id "884b53da-5dbf-4d63-a977-dbc58ba70c56";

# Convert SQL sid hash to Azure AD object id.
ConvertFrom-SQLHashStringToGuid -Hash "0xDA534B88BF5D634DA977DBC58BA70C56";

# Convert SQL SID from binary to string (binary is returned from SQL server when querying).
ConvertTo-SQLHashString -Binary $Binary;

############### Main - End ###############
#endregion
