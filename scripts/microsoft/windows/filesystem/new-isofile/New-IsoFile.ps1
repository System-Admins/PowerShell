#Requires -Version 5.1;

<#
.SYNOPSIS
    Create an ISO file in Windows.
.DESCRIPTION
    Create an ISO file in Windows using the IMAPI2FS API.
.PARAMETER SourcePath
    Source path of the file or folder.
.PARAMETER DestinationPath
    Destination path of the ISO file.
.PARAMETER BootFilePath
    (Optional) Boot file path.
.PARAMETER Media
    (Optional) Media type.
.PARAMETER Title
    (Optional) Title of the ISO file (shown in Windows when inserted).
.PARAMETER IncludeBaseDirectory
    (Optional) If source path should only contain recursive files and folders, and not the top folder itself.
.PARAMETER Force
    (Optional) If the destination file should be overwritten.
.EXAMPLE
    # Create an ISO file from the folder 'C:\Temp\MyFolder' to 'C:\AnotherTemp\MyFolder.iso'.
    Create-Iso -SourcePath 'C:\Temp\MyFolder' -DestinationPath 'C:\AnotherTemp\MyFolder.iso';
#>

[cmdletbinding()]
[OutputType([string])]
param
(
    # Source path.
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_; })]
    [string]$SourcePath,

    # Destination path.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$DestinationPath = ('{0}\{1}.iso' -f $env:TEMP, (New-Guid).Guid),

    # If the ISO file should be bootable.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf; })]
    [string]$BootFilePath,

    # Media types.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('CDR', 'CDRW', 'DVDRAM', 'DVDPLUSR', 'DVDPLUSRW', 'DVDPLUSR_DUALLAYER', 'DVDDASHR', 'DVDDASHRW', 'DVDDASHR_DUALLAYER', 'DISK', 'DVDPLUSRW_DUALLAYER', 'BDR', 'BDRE')]
    [string]$Media = 'DVDPLUSRW_DUALLAYER',

    # The title of the ISO file.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$Title = (Get-Date).ToString('yyyyMMdd-HHmmss'),

    # If source path should only contain recursive files and folders, and not the top folder itself.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [bool]$IncludeBaseDirectory = $false,

    # If the file should be overwritten.
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch]$Force = $false
)
BEGIN
{
    # Write to log.
    Write-Verbose ("Starting processing '{0}'" -f $MyInvocation.MyCommand.Name);

    # If the version is higher than 5.1.
    if ($PSVersionTable.PSVersion.Major -gt 5)
    {
        # Throw execption.
        throw ('This script requires PowerShell version 5.1. You are running version {0}' -f $PSVersionTable.PSVersion);
    }

    # Get random for write progress function.
    $writeProgressId = Get-Random;

    # Write progress.
    Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Creating ISO file';

    # Define the ISO file class.
    $isoFileClass = @'
public class ISOFile
{
  public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)
  {
    int bytes = 0;
    byte[] buf = new byte[BlockSize];
    var ptr = (System.IntPtr)(&bytes);
    var o = System.IO.File.OpenWrite(Path);
    var i = Stream as System.Runtime.InteropServices.ComTypes.IStream;

    if (o != null)
    {
      while (TotalBlocks-- > 0)
      {
        i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes);
      }
      o.Flush(); o.Close();
    }
  }
}
'@;

    # Supported media types.
    $MediaType = @(
        'UNKNOWN',
        'CDROM',
        'CDR',
        'CDRW',
        'DVDROM',
        'DVDRAM',
        'DVDPLUSR',
        'DVDPLUSRW',
        'DVDPLUSR_DUALLAYER',
        'DVDDASHR', 'DVDDASHRW',
        'DVDDASHR_DUALLAYER',
        'DISK',
        'DVDPLUSRW_DUALLAYER',
        'HDDVDROM',
        'HDDVDR',
        'HDDVDRAM',
        'BDROM',
        'BDR',
        'BDRE'
    );

    # Write to log.
    Write-Verbose -Message ("Media type select is '{0}' with value '{1}'" -f $Media, $MediaType.IndexOf($Media));

    # If the destination path exists.
    if (Test-Path -LiteralPath $DestinationPath -PathType Leaf)
    {
        # If force is set.
        if ($true -eq $Force)
        {
            # Write to log.
            Write-Verbose -Message ("Removing file '{0}'" -f $DestinationPath);

            # Remove the destination path.
            Remove-Item -LiteralPath $DestinationPath -Force;
        }
        # Else force is not set.
        else
        {
            # Throw execption.
            throw ("File '{0}' already exist. Use '-Force' parameter to overwrite if the target file already exists." -f $DestinationPath);

            # Break script.
            break;
        }
    }

    # Get folder path of destination path.
    $folderDestinationPath = Split-Path -Path $DestinationPath -Parent;

    # If folder path don't exist.
    if (!(Test-Path -Path $folderDestinationPath -PathType Container))
    {
        # Try to create folder path for the ISO file.
        try
        {
            # Write to log.
            Write-Verbose -Message ("Trying to create destination folder '{0}' for the ISO file" -f $SourcePath);

            # Create folder path.
            $null = New-Item -Path $folderDestinationPath -ItemType Directory -Force;

            # Write to log.
            Write-Verbose -Message ('Successfully created destination folder' -f $SourcePath);
        }
        # Something went wrong.
        catch
        {
            # Throw execption.
            throw ("Failed to create destination folder '{0}' for the ISO file. {1}" -f $SourcePath, $_.Exception.Message.Trim());
        }
    }
}
PROCESS
{
    # New compiler parameters object.
    $compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters;

    # Set compiler parameter to unsafe.
    $compilerParameters.CompilerOptions = '/unsafe';

    # Add custom type.
    Add-Type -CompilerParameters $compilerParameters -TypeDefinition $isoFileClass;

    # If the boot file switch is set.
    if (-not ([string]::IsNullOrEmpty($BootFilePath)))
    {
        # If the media type is BDR or BDRE.
        if ($Media -eq 'BDR' -or $Media -eq 'BDRE')
        {
            # Throw execption.
            throw ("Bootable 'BDR' and 'BDRE' media is not supported, aborting");
        }

        # Create a new stream.
        $stream = New-Object -ComObject ADODB.Stream -Property @{Type = 1 };

        # Open the stream.
        $stream.Open();

        # Load the boot file.
        $stream.LoadFromFile($bootFilePath);

        # Create new boot options object.
        $bootOptions = New-Object -ComObject IMAPI2FS.BootOptions;

        # Assign the boot image.
        $bootOptions.AssignBootImage($stream);
    }

    # Create boot image.
    $image = New-Object -ComObject IMAPI2FS.MsftFileSystemImage -Property @{VolumeName = $Title };

    # Choose image defaults for media type.
    $image.ChooseImageDefaultsForMediaType($MediaType.IndexOf($Media));

    # Try to add folder/file to the image.
    try
    {
        # Write to log.
        Write-Verbose -Message ("Adding tree '{0}' to image" -f $SourcePath);

        # Add the tree to the image.
        $image.Root.AddTree($SourcePath, $IncludeBaseDirectory);

        # Write to log.
        Write-Verbose -Message ("Successfully added tree '{0}' to image" -f $SourcePath);
    }
    # Something went wrong.
    catch
    {
        # Throw execption.
        throw ("Failed to add tree '{0}' to image. {1}" -f $SourcePath, $_.Exception.Message.Trim());
    }

    # If we should use a boot image.
    if ($null -ne $bootOptions)
    {
        # Add boot to image.
        $image.BootImage = $bootOptions;
    }

    # Try to create the image.
    try
    {
        # Write to log.
        Write-Verbose -Message ("Trying to create image to '{0}'" -f $DestinationPath);

        # Create the result image.
        $resultImage = $image.CreateResultImage();

        # Initiate the ISO file creation.
        [ISOFile]::Create($DestinationPath, $resultImage.ImageStream, $resultImage.BlockSize, $resultImage.TotalBlocks);

        # Write to log.
        Write-Verbose -Message ("Successfully created image to '{0}'" -f $DestinationPath);
    }
    # Something went wrong.
    catch
    {
        # Throw execption.
        throw ("Failed to create image to '{0}'. {1}" -f $DestinationPath, $_.Exception.Message.Trim());
    }
}
END
{
    # Write progress.
    Write-Progress -Id $writeProgressId -Activity $MyInvocation.MyCommand.Name -CurrentOperation 'Creating ISO file' -Completed;

    # Write to log.
    Write-Verbose ("Ending process '{0}'" -f $MyInvocation.MyCommand.Name);

    # Return the destination path.
    return $DestinationPath;
}
