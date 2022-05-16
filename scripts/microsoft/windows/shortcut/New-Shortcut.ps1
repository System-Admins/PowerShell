# Function to deploy shorcuts.
Function New-Shortcut
{
    [CmdletBinding()]
    
    Param
    (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Output,
        [Parameter(Mandatory=$false)][string]$Arguments,
        [Parameter(Mandatory=$false)][string]$IconPath
    )

    # Check if file already exists.
    If(Test-Path -Path $Output)
    {
        # Remove file.
        Remove-Item -Path $Output -Force -Confirm:$false | Out-Null;
    }

    # Create object.
    $WScriptShell = New-Object -ComObject WScript.Shell;
    
    # Create shortcut at destination.
    $Shortcut = $WScriptShell.CreateShortcut($Output);

    # Source file for the shortcut.
    $Shortcut.TargetPath = $Path;

    # If arguments is specificied.
    If($IconPath)
    {
        # Arguments for the source file.
        $shortcut.Arguments = $Arguments;
    }

    # If icon location is specificied.
    If($IconPath)
    {
        # Set icon location.
        $Shortcut.IconLocation = $IconPath;
    }

    # Save the shorcut.
    $Shortcut.Save();
}
