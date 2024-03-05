# Variables.
$adminUrl = '';
$username = '';
$password = '';

# Import the module.
Import-Module -Name 'Pnp.PowerShell' -DisableNameChecking -Force;

# Create credential.
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force;
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $securePassword;

# Connect to SharePoint Online.
Connect-PnPOnline -Url $adminUrl -Credentials $credential;

# Get all site collections (exclude builtin).
$siteCollections = Get-PnPTenantSite | Where-Object { $_.Template -notin @(
        'SPSMSITEHOST#0',
        'EHS#1',
        'POINTPUBLISHINGTOPIC#0',
        'POINTPUBLISHINGHUB#0',
        'SRCHCEN#0'
    )
};

# Foreach site collection.
foreach ($siteCollection in $siteCollections)
{
    # Connect to the site collection.
    Connect-PnPOnline -Url $siteCollection.Url `
        -Credentials $credential;

    # Get all subsites.
    $subSites = Get-PnPSubWeb -Recurse `
        -IncludeRootWeb `
        -ErrorAction SilentlyContinue;

    # Foreach subsite.
    foreach ($subSite in $subSites)
    {
        # Connect to the subsite.
        Connect-PnPOnline -Url $subSite.Url -Credentials $credential;

        # Get all lists.
        $lists = Get-PnPList;
        
        # Foreach list.
        foreach ($list in $lists)
        {
            # Get all list items.
            $listItems = Get-PnPListItem -List $list.Id -PageSize 2000;

            # Foreach list item.
            foreach ($listItem in $listItems)
            {
                # Get unique permissions.
                $hasUniquePermissions = Get-PnPProperty -ClientObject $ListItem `
                    -Property 'HasUniqueRoleAssignments';

                # If the list item dont have unique permissions.
                if ($hasUniquePermissions -eq $false)
                {
                    # Continue to the next list item.
                    continue;
                }

                # Try to reset.
                try
                {
                    # Write to log.
                    Write-Information -MessageData ('[{0}] Trying to reset unique permissions' -f $listItem.FieldValues.FileRef) -InformationAction Continue;

                    # Set the list item to inherit permissions.
                    Set-PnPListItemPermission -List $List.Id `
                        -Identity $listItem.Id `
                        -InheritPermissions `
                        -ErrorAction Stop;

                    # Write to log.
                    Write-Information -MessageData ('[{0}] Succesfully reset unique permissions' -f $listItem.FieldValues.FileRef) -InformationAction Continue;
                }
                # Something went wrong.
                catch
                {
                    # Write to log.
                    Write-Information -MessageData ('[{0}] Something went wrong resetting unique permissions' -f $listItem.FieldValues.FileRef) -InformationAction Continue;
                }
            }
        }
    }
}
