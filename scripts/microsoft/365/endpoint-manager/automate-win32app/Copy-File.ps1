#requires -version 5.1

<#
.SYNOPSIS
  Get software installed on the PC.

.DESCRIPTION
  Goes through the registries (machine & user), files and APPX packages and tries to find software based on parameter input.

.NOTES
  Version:        1.0
  Author:         Alex Ø. T. Hansen (ath@systemadmins.com)
  Creation Date:  14-07-2022
  Purpose/Change: Initial script development.
#>

#region begin boostrap
############### Bootstrap - Start ###############

[cmdletbinding()]

Param
(
    # Source file to copy.
    [Parameter(Mandatory=$true)][string]$SourceFile,

    # Path of destination file.
    [Parameter(Mandatory=$true)][string]$DestinationFile,

    # If destination file should have content replaced.
    [Parameter(Mandatory=$false)][Switch]$FindReplace,

    # Find and replace table.
    [Parameter(Mandatory=$false)][hashtable]$ReplaceTable
)

# Clear screen.
#Clear-Host;

############### Bootstrap - End ###############
#endregion

#region begin input
############### Input - Start ###############

############### Input - End ###############
#endregion

#region begin functions
############### Functions - Start ###############

# Write to the console.
Function Write-Log
{
    [cmdletbinding()]	
		
    Param
    (
        [Parameter(Mandatory=$false)][string]$Text
    )
 
    # If the input is empty.
    If([string]::IsNullOrEmpty($Text))
    {
        $Text = " ";
    }
    Else
    {
        # Write to the console.
        Write-Host("[" + (Get-Date).ToString("dd/MM-yyyy HH:mm:ss") + "]: " + $Text);
    }
}

# Copy file.
Function Copy-File
{
    [cmdletbinding()]	
		
    Param
    (
        # Source file to copy.
        [Parameter(Mandatory=$true)][string]$SourceFile,

        # Path of destination file.
        [Parameter(Mandatory=$true)][string]$DestinationFile,

        # If destination file should have content replaced.
        [Parameter(Mandatory=$false)][Switch]$FindReplace,

        # Find and replace table.
        [Parameter(Mandatory=$false)][hashtable]$ReplaceTable
    )

    # If source file exist.
    If(Test-Path -Path $SourceFile)
    {
        # Write to log.
        Write-Log ("Source file '{0}' exist" -f $SourceFile);

        # Destination folder.
        $DestinationFolderPath = Split-Path -Path $DestinationFile;

        # If target file exist.
        If(Test-Path -Path $DestinationFile)
        {
            # Write to log.
            Write-Log ("Destination file '{0}' exist, removing file" -f $DestinationFile);

            # Removing file.
            Remove-Item -Path $DestinationFile -Force -Confirm:$false | Out-Null;
        }

        # If target folder dont exist.
        If(!(Test-Path -Path $DestinationFolderPath))
        {
            # Write to log.
            Write-Log ("Creating destination folder path '{0}'" -f $DestinationFile);

            # Create folder.
            New-Item -Path $DestinationFolderPath -ItemType Directory -Force -Confirm:$false | Out-Null;
        }

        # Copy file.
        Copy-Item -Path $SourceFile -Destination $DestinationFile -Force -Confirm:$false | Out-Null;

        # If find replace is needed.
        If($FindReplace)
        {
            # Write to log.
            Write-Log ("Will find and replace in destination file '{0}'" -f $DestinationFile);

            # Get content.
            $Contents = Get-Content -Path $DestinationFile -Force -Encoding UTF8 -Raw;

            # Foreach to replace.
            Foreach($Data in $ReplaceTable.GetEnumerator())
            {
                # String to find.
                $Find = $Data.Key;

                # Replace it with.
                $Replace = $Data.Value;

                # Write to log.
                Write-Log ("Will find '{0}' and replace with '{1}'" -f $Find, $Replace);

                # Replace.
                $Contents = $Contents -replace [regex]::escape($Find), $Replace;
            }

            # Write to log.
            Write-Log ("Saving file '{0}'" -f $DestinationFile);

            # Save file.
            $Contents | Set-Content -Path $DestinationFile -Encoding UTF8 -Force -Confirm:$false;

            # Return destination file path.
            Return $DestinationFile;
        }
    }
    # Source file dont exist.
    Else
    {
        # Write to log.
        Write-Log ("Source file '{0}' dont exist" -f $SourceFile);
    }
}

############### Functions - End ###############
#endregion

#region begin main
############### Main - Start ###############

# Copy file.
Copy-File -SourceFile $SourceFile -DestinationFile $DestinationFile -FindReplace -ReplaceTable $ReplaceTable;

############### Main - End ###############
#endregion

#region begin finalize
############### Finalize - Start ###############

############### Finalize - End ###############
#endregion