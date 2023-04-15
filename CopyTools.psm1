function Copy-RemoteFolder
{
    <#
    .SYNOPSIS
    Copy-RemoteFolder copies a folder to remote computers.

    .DESCRIPTION
    Copy-RemoteFolder will copy all files and folders contained at the location 
    specified as SourcePath to the location specified as DestinationPath. If the 
    destination does not exist then it will be created. Any files with 
    the same name at the destination folder location will be overwritten.

    .PARAMETER ComputerName

    .PARAMETER SourcePath

    .PARAMETER DestinationPath

    .PARAMETER Check

    .PARAMETER RemoveFirst

    .INPUTS

    .OUTPUTS

    .EXAMPLE
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory=$true, 
            ValueFromPipeline=$true, 
            Position=0)]
            [string[]]$ComputerName,
        [Parameter(
            Mandatory=$true, 
            Position=1)]
            [string]$SourcePath,
        [Parameter(
            Mandatory=$false,
            Position=2)]
            [string]$DestinationPath = "C:\temp",
        [Parameter(
            Mandatory=$false,
            Position=3)]
            [ValidateSet("None", "Name", "Hash")]
            [string]$Check = "Name",
        [Parameter(
            Mandatory=$false)]
            [switch]$RemoveFirst
        )
    begin {
        # Create list of source items for compare
        If ($Check -eq "Hash") {
            $SourceItems = Get-ChildItem -Path $SourcePath | ForEach-Object {Get-FileHash -Algorithm MD5 -Path $_.FullName}
        } elseif ($Check -eq "Name") {
            $SourceItems = Get-ChildItem -Path $SourcePath
        }

        # Get folder name of source
        $SourceFolder = $SourcePath.Split("\")[-1]
        If ($SourceFolder -eq "") {
            $SourceFolder = $SourcePath.Split("\")[-2]
        }

        $DestinationPath = $DestinationPath.Replace(':','$')
    }
    process {
        foreach ($comp in $ComputerName) {
            $output = [ordered]@{ 
                'Name' = $comp
                'Online' = $false
                'Success' = $false
                'Error' = $null
                }
            for ($i = 0; $i -lt 3; $i++) {
                if(Test-Connection -ComputerName $comp -Count 1 -Quiet) {
                    $output.Online = $true
                    break
                }
            }
            if (-Not $output.Online) {
                $output.Error = "Unable to ping $comp"
                [PSCustomObject]$output
                continue
            } else {
                if ($RemoveFirst) {
                    if (Test-Path -Path "\\$comp\$DestinationPath\$SourceFolder" -PathType Container) {
                        Remove-Item  -Path "\\$comp\$DestinationPath\$SourceFolder" -Recurse -Force
                    }
                }
                if (-Not (Test-Path -Path "\\$comp\$DestinationPath" -PathType Container)){
                    New-Item -Path "\\$comp\$DestinationPath" -ItemType Directory | Out-Null
                }
                Copy-Item -Path $SourcePath -Destination "\\$comp\$DestinationPath" -Recurse -Force
                
                $diff = $null
                If ($Check -eq "Hash") {
                    $DestinationItems = Get-ChildItem -Path "\\$comp\$DestinationPath\$SourceFolder" | ForEach-Object {Get-FileHash -Algorithm MD5 -Path $_.FullName}
                    $diff = (Compare-Object -ReferenceObject $SourceItems  -DifferenceObject $DestinationItems -Property Hash -PassThru).Path
                } elseif ($Check -eq "Name") {
                    $DestinationItems = Get-ChildItem -Path "\\$comp\$DestinationPath\$SourceFolder"
                    $diff = (Compare-Object -ReferenceObject $SourceItems  -DifferenceObject $DestinationItems -Property Name -PassThru).Name
                }
                
                if (-Not ($diff)) {
                    $output.Success = $true
                }
                else {
                    $output.Error = $diff
                }
            }
            [PSCustomObject]$output
        }
    }   
}

function Copy-RemoteItem
{
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory=$true, 
            ValueFromPipeline=$true, 
            Position=0)]
            [string[]]$ComputerName,
        [Parameter(
            Mandatory=$true, 
            Position=1)]
            [string]$SourcePath,
        [Parameter(
            Mandatory=$false,
            Position=2)]
            [string]$DestinationPath = "C:\temp",
        [Parameter(
            Mandatory=$false,
            Position=3)]
            [ValidateSet("None", "Name", "Hash")]
            [string]$Check = "Name"
        )
    begin {
        # Create list of source items for compare
        If ($Check -eq "Hash") {
            $SourceHash = Get-FileHash -Algorithm MD5 -Path $SourcePath
        }
        $SourceItem = Get-ChildItem -Path $SourcePath
        $DestinationPath = $DestinationPath.Replace(':','$')
    }
    process {
        foreach ($comp in $ComputerName) {
            $output = [ordered]@{ 
                'Name' = $comp
                'Online' = $false
                'Success' = $false
                'Error' = $null
                }
            for ($i = 0; $i -lt 3; $i++) {
                if(Test-Connection -ComputerName $comp -Count 1 -Quiet) {
                    $output.Online = $true
                    break
                }
            }
            if (-Not $output.Online) {
                $output.Error = "Unable to ping $comp"
                [PSCustomObject]$output
                continue
            } else {
                if (-Not (Test-Path -Path "\\$comp\$DestinationPath" -PathType Container)){
                    New-Item -Path "\\$comp\$DestinationPath" -ItemType Directory | Out-Null
                }
                Copy-Item -Path $SourcePath -Destination "\\$comp\$DestinationPath" -Force
                
                $diff = $null
                If ($Check -eq "Hash") {
                    $DestinationHash = Get-FileHash -Algorithm MD5 -Path "\\$comp\$DestinationPath\$($SourceItem.Name)"
                    $diff = (Compare-Object -ReferenceObject $SourceHash  -DifferenceObject $DestinationHash -Property Hash -PassThru).Path
                } elseif ($Check -eq "Name") {
                    $DestinationItem = Get-ChildItem -Path "\\$comp\$DestinationPath\$($SourceItem.Name)"
                    $diff = (Compare-Object -ReferenceObject $SourceItem  -DifferenceObject $DestinationItem -Property Name -PassThru).Name
                }
                
                if (-Not ($diff)) {
                    $output.Success = $true
                }
                else {
                    $output.Error = $diff
                }
            }
            [PSCustomObject]$output
        }
    }   
}

function Copy-UserFolder {
    <#
    .SYNOPSIS
    Copy-UserFolder copies the user folder contents from one location to another.

    .DESCRIPTION
    Copy-UserFolder will copy all files and folders contained at the location 
    specified as Source to the location specified as Destination. If the 
    destination folder does not exist then it will be created. Any files with 
    the same name at the destination folder location will be overwritten.
    
    In order to copy between computers, you may specify admin share paths as the
    Source and Destination.

    This process excludes any hidden system files (such as ntuser.dat) as well 
    as a few others. A log file named copy.log is created at the destination's 
    parent location

    .PARAMETER Source
    Specifies the user folder to be copied. 

    .PARAMETER Destination
    Specifies the destination folder for copied files and folders.

    .PARAMETER Exclude
    Specifies a list of folders at the root of the source folder to exclude. By
    default: "Appdata","Contacts","Links","Saved Games","Searches", and 
    "OneDrive" are excluded. If you specify this parameter then these
    folders will be replaced by the specified list. If you wish to include all 
    folders then specify an empty array as @().

    .PARAMETER Purge
    Enables removal of files on Destination which do not appear in the source.

    .PARAMETER Force
    Bypasses user confirmation and begins copying immediately.

    .PARAMETER WhatIf
    Displays the robocopy commands which would be run and exits without making
    any changes. 

    .INPUTS
    None. You cannot pipe objects to Copy-UserFolder.

    .OUTPUTS
    None. Copy-UserFolder does not return anything.

    .EXAMPLE
    C:\PS> Copy-UserFolder -Source {{SOURCE_HOSTNAME}}\C$\Users\{{USERNAME}} -Destination {{DEST_HOSTNAME}}\C$\Users\{{USERNAME}}
    
    #>

    [CmdletBinding(PositionalBinding=$false)]
    param(
        # User folder location
        [Parameter(Mandatory)]
        [String]
        $Source,
        
        # Copy Destination location
        [Parameter(Mandatory)]
        [String]
        $Destination,

        # Custom Folder Exclusions list
        [Parameter()]
        [String[]]
        $Exclude = @("Appdata","Contacts","Links","Saved Games","Searches","OneDrive"),

        # Remove files not present
        [Parameter()]
        [switch]
        $Purge,

        # Do not confirm
        [Parameter()]
        [switch]
        $Force,

        # Do Nothing
        [Parameter()]
        [switch]
        $WhatIf
    )

    #----------------------------- Setup steps ---------------------------------
    $DirsToCopy = Get-ChildItem -Path $Source -Attributes "!System+Hidden,!Hidden" -Exclude $Exclude -Directory
    $DirsToExclude = Get-ChildItem -Path $Source -Attributes "!System+Hidden,!Hidden" -Directory | Where-Object { $Exclude -contains $_.Name }
    if (-Not (Test-Path -Path "$Destination" -PathType Container)) {
        New-Item -Path "$Destination" -ItemType Container -Force | Out-Null
    }
    if ($Purge) {
        $PurgeFlag = "/PURGE"
        $Op = "Copy and Purge"
    } else {
        $PurgeFlag = " "
        $Op = "Copy"
    }

    #------------------------ Double Check with user ---------------------------
    if(-Not $WhatIf) {
        if (-Not $Force) {
            Write-Output @"
This process will copy files and folders from the source folder to the 
destination folder, excluding hidden system files and the folders listed below.

Source: $($Source.trimend('\'))
Destination: $($Destination.trimend('\'))
Folders Excluded: $(($DirsToExclude.foreach({$_.Name})).foreach({"`"$_`""}) -join ', ')
Folders to $($Op): $(($DirsToCopy.foreach({$_.Name})).foreach({"`"$_`""}) -join ', ')
"@
            $Confirm = Read-Host -Prompt "Would you like to continue (Y, n)"
            while($Confirm -ne "Y")
            {
                if ($Confirm -eq 'n') {return}
                $Confirm = Read-Host -Prompt "Invalid Response. Would you like to continue (Y, n)"
            }
        }
    }

    if (-Not $WhatIf) {
        Write-Output "Beginning copy from $($Source.trimend('\')) to $($Destination.trimend('\'))"

        $logdir = "`"$($(Get-Item -Path $Destination).Parent.FullName)\copy.log`""
    }

    #---------------------- Copy all files in root folder ----------------------
    $fromdir = "`"$($Source.trimend('\'))`""
    $todir = "`"$($Destination.trimend('\'))`""
    if ($WhatIf) {
        Write-Output "What if: Performing the operation `'robocopy $fromdir $todir /ZB /XA:SH /XF `"ntuser*`" /MT:4 /FFT /R:3 /LOG+:$logdir /TEE /NP /NJH`'"
    } else {
        Write-Output @"
------------------------------------------------------------------------------
Starting copy from $(($fromdir.split('\')[-1]).trimend('"')) to $(($todir.split('\')[-1]).trimend('"'))
------------------------------------------------------------------------------
"@
        Start-Process "Robocopy.exe" -ArgumentList "$fromdir $todir /ZB /XA:SH /XF `"ntuser*`" /MT:4 /FFT /R:3 /LOG+:$logdir /TEE /NP /NJH" -WorkingDirectory "$((Get-Location).ProviderPath)" -NoNewWindow -Wait -PassThru
    }

    #------------------- Copy all Folders in root recursively ------------------
    foreach ($dir in $DirsToCopy) {
        $fromdir = "`"$($Source.trimend('\'))\$($dir.Name)`""
        $todir = "`"$($Destination.trimend('\'))\$($dir.Name)`""
        if ($WhatIf) {
            Write-Output "What if: Performing the operation `'robocopy $fromdir $todir /E $PurgeFlag /ZB /MT:4 /FFT /R:3 /LOG+:$logdir /TEE /NP /NJH`'"
        } else {
            Write-Output @"
------------------------------------------------------------------------------
Starting copy from $(($fromdir.split('\')[-1]).trimend('"')) to $(($todir.split('\')[-1]).trimend('"'))
------------------------------------------------------------------------------
"@
            Start-Process "Robocopy.exe" -ArgumentList "$fromdir $todir /E $PurgeFlag /ZB /MT:4 /FFT /R:3 /LOG+:$logdir /TEE /NP /NJH" -WorkingDirectory "$((Get-Location).ProviderPath)" -NoNewWindow -Wait -PassThru
        }
    }

    if (-Not $WhatIf) {
        Write-Output "Operation Complete - Log available at `"$($(Get-Item -Path $Destination).Parent.FullName)\copy.log`""
    }

}

Export-ModuleMemeber -function 'Copy-RemoteFolder'
Export-ModuleMemeber -function 'Copy-RemoteItem'
Export-ModuleMemeber -function 'Copy-UserFolder'