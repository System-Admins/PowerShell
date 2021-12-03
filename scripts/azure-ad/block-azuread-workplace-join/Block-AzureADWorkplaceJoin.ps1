#Setting registry key to block AAD Registration to 3rd party tenants. 
$RegistryLocation = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin\";
$keyname = "BlockAADWorkplaceJoin";

# Test if path exists and create if missing.
if (!(Test-Path -Path $RegistryLocation))
{
    # Create new key.
    New-Item $RegistryLocation | Out-Null;
}

# Force create key with value 1.
New-ItemProperty -Path $RegistryLocation -Name $keyname -PropertyType DWord -Value 1 -Force | Out-Null;