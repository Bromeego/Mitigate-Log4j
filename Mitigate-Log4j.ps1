# Calling Powershell as Admin and setting Execution Policy to Bypass to avoid Cannot run Scripts error
param ([switch]$Elevated)
function CheckAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((CheckAdmin) -eq $false) {
    if ($elevated) {
        # could not elevate, quit
    }
    else {
        # Detecting Powershell (powershell.exe) or Powershell Core (pwsh), will return true if Powershell Core (pwsh)
        if ($IsCoreCLR) { $PowerShellCmdLine = 'pwsh.exe' } else { $PowerShellCmdLine = 'powershell.exe' }
        $CommandLine = "-noprofile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments + ' -Elevated'
        Start-Process "$PSHOME\$PowerShellCmdLine" -Verb RunAs -ArgumentList $CommandLine
    }
    Exit
}

# Check if we have 7-Zip installed
$check7zip = Test-Path -Path 'c:\Program Files\7-Zip\7z.exe'

if ($check7zip -eq $False) {
    # Borrowed from https://gist.github.com/SomeCallMeTom/6dd42be6b81fd0c898fa9554b227e4b4 and tweaked with a couple of try/catches and error catching
    Write-Host '7-Zip is not installed'
    $install7zip = Read-Host 'Would you like to download and install it (Y/n)'
    If ($install7zip -eq 'Y') {
        $dlurl = 'https://7-zip.org/' + (Invoke-WebRequest -UseBasicParsing -Uri 'https://7-zip.org/' | Select-Object -ExpandProperty Links | Where-Object { ($_.outerHTML -match 'Download') -and ($_.href -like 'a/*') -and ($_.href -like '*-x64.exe') } | Select-Object -First 1 | Select-Object -ExpandProperty href)
        # modified to work without IE
        # above code from: https://perplexity.nl/windows-powershell/installing-or-updating-7-zip-using-powershell/
        $installerPath = Join-Path $env:TEMP (Split-Path $dlurl -Leaf)
        Try { 
            Invoke-WebRequest $dlurl -OutFile $installerPath 
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Warning "$ErrorMessage"
            Write-Host 'Please download and install 7-Zip'
            Write-Host 'https://www.7-zip.org/download.html'
        }
        if ($ErrorMessage -ne $null) {
            $ExitCode = (Start-Process -FilePath $installerPath -Args '/S' -Verb RunAs -Wait -PassThru).ExitCode
            if ($ExitCode -eq 0) {
                Write-Host 'success!' -ForegroundColor Green
            }
            else {
                Write-Host "failed. There was a problem installing 7-Zip. Exit code $ExitCode." -ForegroundColor Red
            }
            Remove-Item $installerPath
        }
    }
    $check7zip = Test-Path -Path 'c:\Program Files\7-Zip\7z.exe'
}

# If 7-Zip is installed, then lets go!
if ($check7zip -eq $True) {
    Write-Host 'Gathering Drive Information...'
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3'
    foreach ($disk in $disks) {

        $diskname = "$($volume.DeviceID)\"
        
        Write-Host "`n** Checking $diskname... ** `n"
     
        Write-Host '** Searching for log4j-core*.jar files... ** `n'
        Get-ChildItem -Path $diskname -Filter log4j-core*.jar -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $check = $null
            Write-Host "`n`n *** File found $($_.FullName) ***"
            
            # Find any log4j-core*.jar files and remove org/apache/logging/log4j/core/lookup/JndiLookup.class with zip.exe -q -d command.
            Write-Host "Removing JndiLookup.class from `"$($_.FullName)`"..." -NoNewline
            try {
                &  'c:\Program Files\7-Zip\7z.exe' d "$($_.FullName)" 'org/apache/logging/log4j/core/lookup/JndiLookup.class' | Out-Null
                Write-Host ' Done' -ForegroundColor Green
            }
            catch {
                Write-Host ' Error removing file' -ForegroundColor Red
            }
           
            # Use unzip -l (List) | findstr JndiLookup sanity check on the file to make sure that JndiLookup.Class has been removed.
            Write-Host 'Doing a sanity check on the file to make sure that JndiLookup.Class has been removed'
            $check = & 'c:\Program Files\7-Zip\7z.exe' l -r "$($_.FullName)" | findstr JndiLookup
            if ($check -ne $null) {
                Write-Host '    Looks like the JndiLookup.class file still exists, please try again'
                $check
            }
            else {
                Write-Host "    The file has been removed `"$($_.FullName)`""
            }       
        }
        Write-Host "** Finished checking $diskname **`n"     
    }
}
# You are going to have to manually download and install 7-Zip
else {
    Write-Host 'Please download and install 7-Zip'
    Write-Host 'https://www.7-zip.org/download.html'
}


Pause
