#Requires -Version 7.2;
#Requires -Modules PnP.PowerShell;

<#
.SYNOPSIS
  Get all users from a SharePoint site collection (does not check sub-sites).

.DESCRIPTION
  Uses PnP PowerShell to get all users from a SharePoint site collection.
  Returns a list of users with their login name.

.PARAMETER SiteUrl
  The URL of the SharePoint site collection.

.Example
   .\Get-SpoSiteUser.ps1 -SiteUrl 'https://contoso.sharepoint.com/sites/sales';

.NOTES
  Version:        1.0
  Author:         Alex Hansen (ath@systemadmins.com)
  Creation Date:  04-09-2024
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Parameters - Start ###############

[cmdletbinding()]
[OutputType([System.Collections.Generic.List[string]])]
param
(
  [Parameter(Mandatory = $true)]
  [string]$SiteUrl
)

############### Parameters - End ###############
#endregion

#region begin bootstrap
############### Bootstrap - Start ###############

# Import required modules.
Import-Module -Name PnP.PowerShell -ErrorAction Stop;

############### Bootstrap - End ###############
#endregion

#region begin variables
############### Variables - Start ###############

############### Variables - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Try to connect to the SharePoint site.
try
{
  # Write to log.
  Write-Information ('Please sign in to the SharePoint site using the interactive login dialog') -InformationAction Continue;

  # Connect to the SharePoint site.
  Connect-PnPOnline -Url $SiteUrl -Interactive -WarningAction SilentlyContinue -ErrorAction Stop;

  # Write to log.
  Write-Information ('Successfully logged in to the SharePoint site') -InformationAction Continue;
}
catch
{
  # Write error message.
  Write-Error -Message 'Failed to connect to the SharePoint site.';
}

# Get all lists in the site.
$siteLists = Get-PnPList

# Only get document libraries.
$documentLibraries = $siteLists | Where-Object { $_.BaseTemplate -eq 101 -and $_.Hidden -eq $false };

# Object array for items with unique permissions.
$users = @();

# Foreach document library.
foreach ($documentLibrary in $documentLibraries)
{
  # Get role assignments.
  Get-PnPProperty -ClientObject $documentLibrary -Property HasUniqueRoleAssignments, RoleAssignments;

  # Foreach role assignment for the document library.
  foreach ($roleAssignment in $documentLibrary.RoleAssignments)
  {
    # Get role assignment property.
    Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings, Member;

    # Get the principal type.
    $permissionType = $RoleAssignment.Member.PrincipalType;

    # If the principal type is a SharePoint group.
    if ($permissionType -eq 'SharePointGroup')
    {
      # Get the members of the SharePoint group.
      $groupMembers = Get-PnPGroupMember -Identity $RoleAssignment.Member.LoginName;

      # Foreach group member.
      foreach ($groupMember in $groupMembers)
      {
        # Get login name.
        $loginName = ($groupMember.LoginName -split '\|')[-1];

        # If the group member is not already in the users array.
        if ($users -notcontains $loginName)
        {
          # Add the group member to the users array.
          $users += $loginName;
        }
      }
    }

    # Else if the principal type is a user.
    else
    {
      # Get login name.
      $loginName = ($RoleAssignment.Member.LoginName -split '\|')[-1];

      # If the user is not already in the users array.
      if ($users -notcontains $loginName)
      {
        # Add the user to the users array.
        $users += $loginName;
      }
    }
  }

  # Get all items in the document library.
  $listItems = Get-PnPListItem -List $documentLibrary -PageSize 2000;

  # Foreach list item.
  foreach ($listItem in $listItems)
  {
    # Get the list item's unique permissions.
    $hasUniqueRoleAssignment = Get-PnPProperty -ClientObject $ListItem -Property HasUniqueRoleAssignments, RoleAssignments;

    # If the list item has unique permissions.
    if ($hasUniqueRoleAssignment)
    {
      # Foreach role assignment for the list item.
      foreach ($roleAssignment in $listItem.RoleAssignments)
      {
        # Get role assignment property.
        Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings, Member;

        # Get the principal type.
        $permissionType = $RoleAssignment.Member.PrincipalType;

        # If the principal type is a SharePoint group.
        if ($permissionType -eq 'SharePointGroup')
        {
          # Get the members of the SharePoint group.
          $groupMembers = Get-PnPGroupMember -Identity $RoleAssignment.Member.LoginName;

          # Foreach group member.
          foreach ($groupMember in $groupMembers)
          {
            # Get login name.
            $loginName = ($groupMember.LoginName -split '\|')[-1];

            # If the group member is not already in the users array.
            if ($users -notcontains $loginName)
            {
              # Add the group member to the users array.
              $users += $loginName;
            }
          }
        }

        # Else if the principal type is a user.
        else
        {
          # Get login name.
          $loginName = ($RoleAssignment.Member.LoginName -split '\|')[-1];

          # If the user is not already in the users array.
          if ($users -notcontains $loginName)
          {
            # Add the user to the users array.
            $users += $loginName;
          }
        }
      }
    }
  }
}

# Enforce only unique users.
$users = $users | Sort-Object -Unique;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

# Return users.
return $users;

############### Finalize - End ###############
#endregion
