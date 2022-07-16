Function Upload-FileToAzBlob
{
    [cmdletBinding()]
    
    Param
    (
        [string]$SourceFile,
        [switch]$KeepName,
        [string]$URL,
        [string]$Token

    )

    # Get file object.
    $File = Get-Item -Path $SourceFile;

    # If we don't need to keep the same name.
    If(!($KeepName))
    {
        # Create file name.
        $Name = ('{0}_{1}' -f (Get-Date).ToString("yyyyMMdd_HHmmss"), $File.Name);
    }
    # Name need to be the same.
    Else
    {
        # Keep file name.
        $Name = $File.Name;
    }

    # The SAS token.
    $Uri = '{0}/{1}{2}' -f $URL, $Name, $Token;

    # Define required headers.
    $Headers = @{
        'x-ms-blob-type' = 'BlockBlob'
    };

    # Upload file.
    Invoke-RestMethod -Uri $Uri -Method Put -Headers $Headers -InFile $File;
}

# Upload file to blob container.
Upload-FileToAzBlob -SourceFile "....\filename.something" `
                    -KeepName:$false `
                    -URL "https://<storageaccountname>.blob.core.windows.net/<container>"  `
                    -Token '?sp=acw&st=2022-03-25T14:06:26Z&se=2030-03-25T22:06:26Z&spr=https&sv=2020-08-04&sr=c&sig=Mdku1bmyTXVhLohEC5MWCtW4f8xyl0YKQSoHz%2BLnFDY%3D';