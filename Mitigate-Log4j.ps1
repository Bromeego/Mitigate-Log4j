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

# The command below will get the details of Disks and select the Device ID for use below
$Drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' | 
    Select-Object DeviceID

# Scan each disk on the system and look for the particular string
$vulnFiles = @()
Write-Host 'Scanning in progress. Please Wait'
foreach ($drive in $Drives) {
    $drive = $drive.DeviceID
    $vulnFiles += Get-ChildItem "$drive\" -Filter log4j-core*.jar -Recurse -ErrorAction SilentlyContinue | 
        ForEach-Object { Select-String 'JndiLookup.class' $_ } | 
        Select-Object -ExpandProperty Path
}

if ($vulnFiles -ne $null) {
    # Output the files found
    $vulnFules

    $Mitigate = Read-Host 'Would you like to Mitigate the Log4j Files? (Y/n)'

    if ($Mitigate -eq 'Y') {

        # Check if we have 7-Zip installed
        $check7zip = Test-Path -Path 'c:\Program Files\7-Zip\7z.exe'

        if ($check7zip -eq $False) {
            # Borrowed from https://gist.github.com/SomeCallMeTom/6dd42be6b81fd0c898fa9554b227e4b4 and tweaked with a couple of try/catches and error catching
            Write-Host '7-Zip is not installed'
            $install7zip = Read-Host 'Would you like to download and install it (Y/n)'
            If ($install7zip -eq 'Y') {
                Try {
                    $dlurl = 'https://7-zip.org/' + (Invoke-WebRequest -UseBasicParsing -Uri 'https://7-zip.org/' -ErrorAction Stop | Select-Object -ExpandProperty Links | Where-Object { ($_.outerHTML -match 'Download') -and ($_.href -like 'a/*') -and ($_.href -like '*-x64.exe') } | Select-Object -First 1 | Select-Object -ExpandProperty href)
                }
                Catch {
                    $ErrorMessage = $_.Exception.Message
                    Write-Warning "$ErrorMessage"
                    Write-Host 'Please download and install 7-Zip'
                    Write-Host 'https://www.7-zip.org/download.html'
                }
                # Modified to work without IE
                # Above code from: https://perplexity.nl/windows-powershell/installing-or-updating-7-zip-using-powershell/
                if ($null -eq $ErrorMessage) {
                    # Create the Installer path
                    $installerPath = Join-Path $env:TEMP (Split-Path $dlurl -Leaf)
                    # Download the file
                    Invoke-WebRequest $dlurl -OutFile $installerPath
                    # Install the file
                    $ExitCode = (Start-Process -FilePath $installerPath -Args '/S' -Verb RunAs -Wait -PassThru).ExitCode
                    if ($ExitCode -eq 0) {
                        Write-Host 'success!' -ForegroundColor Green
                        $check7zip = Test-Path -Path 'c:\Program Files\7-Zip\7z.exe'
                    }
                    else {
                        Write-Host "failed. There was a problem installing 7-Zip. Exit code $ExitCode." -ForegroundColor Red
                    }
                    Remove-Item $installerPath
                }
            }
    
        }

        # If 7-Zip is installed, then lets go!
        if ($check7zip -eq $True) {
            Foreach ($vulnFile in $vulnFiles) {
                # Start removing JndiLookup.class from each of the files we discovered
                Write-Host "Removing JndiLookup.class from $vulnfile ..." -NoNewline
                try {
                    $7zDelArg = "d `"$vulnFile`" org/apache/logging/log4j/core/lookup/JndiLookup.class"
                    Start-Process -NoNewWindow -FilePath 'c:\Program Files\7-Zip\7z.exe' -Args $7zDelArg -Verb RunAs -Wait -ErrorAction Stop | Out-Null
                    Write-Host ' Done' -ForegroundColor Green
                }
                catch {
                    Write-Host ' Error removing file' -ForegroundColor Red
                    $ErrorMessage = $_.Exception.Message
                    Write-Warning "$ErrorMessage"
                }
           
                # Check the file to see if we actually deleted it
                Write-Host 'Doing a sanity check on the file...' -NoNewline
                $check = & 'c:\Program Files\7-Zip\7z.exe' l -r "$vulnFile" | findstr JndiLookup
                if ($null -eq $check) {
                    Write-Host '    File still exists, please try again' -ForegroundColor Red
                    $check
                }
                else {
                    Write-Host '    File has been deleted' -ForegroundColor Green
                }  
            }
        }
        # You are going to have to manually download and install 7-Zip
        else {
            Write-Host 'Please download and install 7-Zip'
            Write-Host 'https://www.7-zip.org/download.html'
        }
    }
    else {
        Write-Host "List of vulnerable files are as follows `n"
        Foreach ($vulnFile in $vulnFiles) {
            Write-Host "$vulnFile"
        }
    }
}
else {
    Write-Host 'No files found'
}


Pause
