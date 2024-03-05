#Requires -Module MicrosoftTeams;

# Import module.
Import-Module -Name MicrosoftTeams;

# Exclude list if removal should be skipped for some users.
$excludeMembers = @(
    'svc.maersktankers@penfieldmarine1.onmicrosoft.com'
);

# Connect to Microsoft Teams.
Connect-MicrosoftTeams;

# Get all the teams in the tenant.
$teams = Get-Team;

# Foreach team.
foreach ($team in $teams)
{
    # Get members of the team.
    $members = Get-TeamUser -GroupId $team.GroupId;

    # Foreach member.
    foreach ($member in $members)
    {
        # If the member is in the exclude list.
        if ($excludeMembers -contains $member.User)
        {
            # Skip the member.
            continue;
        }

        # Write to log.
        Write-Information -MessageData ('[{0}][{1}] Removing member from the team' -f $team.DisplayName, $member.User) `
            -InformationAction Continue;

        # Try to remove the member from the team.
        try
        {
            # Write to log.
            Write-Information -MessageData ('[{0}][{1}] Trying to remove member from the team' -f $team.DisplayName, $member.User) `
                -InformationAction Continue;

            # Remove the member from the team.
            Remove-TeamUser -GroupId $team.GroupId -User $member.User -ErrorAction Stop;

            # Write to log.
            Write-Information -MessageData ('[{0}][{1}] Successfully removed member from the team' -f $team.DisplayName, $member.User) `
                -InformationAction Continue;
        }
        # Something went wrong.
        catch
        {
            # Write to log.
            Write-Information -MessageData ('[{0}][{1}] Something went wrong while removing member from the team' -f $team.DisplayName, $member.User) `
                -InformationAction Continue;
        }
    }
}
