# Connect to Azure.
$Account = Connect-AzAccount;

# Get Azure SQL database token.
$AccessToken = (Get-AzAccessToken -Resource "https://database.windows.net/");

# Export access token to the desktop.
$AccessToken.Token | Out-File -FilePath ("{0}\AccessToken.txt" -f [Environment]::GetFolderPath("Desktop")) -Encoding utf8 -Force;
