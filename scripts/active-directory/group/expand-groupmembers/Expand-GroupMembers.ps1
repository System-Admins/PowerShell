#requires -version 3
#requires -module ActiveDirectory

<#
.SYNOPSIS
  Get members of nested groups and adds them to the root level group.

.DESCRIPTION
  Takes an backup of current members in groups, get nested members and adds them to the root group.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  11-01-2021
  Purpose/Change: Initial script development
#>

#region begin boostrap
############### Bootstrap - Start ###############

#Clear the screen.
#Clear-Host;

#Import module.
Import-Module -Name ActiveDirectory;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

# Active Directory.
$ActiveDirectory = @{
    SearchBase = 'OU=myOU,DC=contoso,DC=com';
};

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Write to the log.
Function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Category,
        [Parameter(Mandatory=$false)][string]$Text
    )
 
    # If the input is empty.
    If([string]::IsNullOrEmpty($Text))
    {
        # Write to the console.
        Write-Output("");

        # Continue.
        Continue;
    }
 
    # If category is not present.
    If([string]::IsNullOrEmpty($Category))
    {
        # Write to the console.
        Write-Output("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
    Else
    {
        # Write to the console.
        Write-Output("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "][" + $Category + "]: " + $Text);
    }
}

# Get all nested members.
Function Get-ADNestedGroups
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory=$true)]$Identity
    )

    # Get all groups/users of the root group.
    $Members = Get-ADGroupMember -Identity $Identity;

    # Foreach member in the group.
    Foreach($Member in $Members)
    {
        # If the member is a group.
        If($Member.ObjectClass -eq "group")
        {
            #Run the function again against the group.
            $Users += Get-ADNestedGroups -Identity $Member.distinguishedName;
        }
        Else
        {
            # Add the user to the object array.
            $Users += @($Member);
        }
    }

    # Return the users.
    Return ,$Users;
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Write to log.
Write-Log -Text ("Getting all groups in '{0}' (only one level)" -f $ActiveDirectory.SearchBase);

# Get all groups (single level).
$ADGroups = Get-ADGroup -SearchBase $ActiveDirectory.SearchBase -SearchScope OneLevel -Filter *;

# Backup of members.
$Backup = @();

# Forach group.
Foreach($ADGroup in $ADGroups)
{
    # Write to log.
    Write-Log -Text ("Getting all members of the group '{0}'" -f $ADGroup.SamAccountName);

    # Get all members.
    $ADGroupMembers = (Get-ADNestedGroups -Identity $ADGroup.SamAccountName).SamAccountName | Sort-Object -Unique;

    # Add to backup.
    $Backup += [PSCustomObject]@{
        Name = $ADGroup.SamAccountName;
        Members = (Get-ADGroupMember -Identity $ADGroup.SamAccountName).SamAccountName -join ",";
    };

    # If there is members.
    If($ADGroupMembers)
    {
        # Write to log.
        Write-Log -Text ("Adding {0} members to '{1}'" -f $ADGroupMembers.Count, $ADGroup.SamAccountName);

        # Add members to distribution group.
        Add-ADGroupMember -Identity $ADGroup.SamAccountName -Members $ADGroupMembers;
    }
    Else
    {
        # Write to log.
        Write-Log -Text ("No members to add into '{0}'" -f $ADGroup.SamAccountName);
    }

    # Write to log.
    Write-Log;
}

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Write to log.
Write-Log -Text ("Exporting backup to '{0}'" -f ("{0}\GroupMemberBackup.csv" -f [Environment]::GetFolderPath("Desktop")));

# Export backup.
$Backup | Export-Csv -Path ("{0}\GroupMemberBackup.csv" -f [Environment]::GetFolderPath("Desktop")) -Encoding UTF8 -NoTypeInformation -Delimiter ";" -Force;

############### Finalize - End ###############
#endregion
