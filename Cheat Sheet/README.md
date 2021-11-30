# Cheat Sheet for PowerShell

This page shows a examples and simple commands that can help you on the way with PowerShell scripts and module.

## Version

### Convert string to type System.Version

This converts an string like "1.0.0" into the type [System.Version] and converts all other chars to an dot.

```powershell
# Replace all other chars than numbers into a dot.
$Data = '4.3.0_3' -replace "([^0-9])", ".";

# Convert string to System.Version.
$Version = [System.Version]::Parse($Data);

# Print result.
$Version;

# Gives the following output.
Major  Minor  Build  Revision
-----  -----  -----  --------
4      3      0      3       
```

## Paths

### Get script path

This returns the executed script path. Takes into account if the scripts runs in PowerShell ISE IDE.

```powershell
# If script running in PowerSHell ISE.
If($psise)
{
    # Set script path.
    $ScriptPath = Split-Path $psise.CurrentFile.FullPath;
}
# Normal PowerShell session.
Else
{
    # Set script path.
    $ScriptPath = $global:PSScriptRoot;
}   
```

