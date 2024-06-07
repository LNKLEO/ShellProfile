Import-Module Posh-Git
Import-Module Terminal-Icons
Import-Module Z
Import-Module PSFzf

Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete

Set-PSReadLineKeyHandler -Key UpArrow -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchBackward()
    [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
}
Set-PSReadLineKeyHandler -Key DownArrow -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchForward()
    [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
}

#Set Alias
Set-Alias code code-insiders

if ($env:OS -eq "Windows_NT") {
    $env:PATH = $env:PATH + $env:PATH + ";C:\SHELL\OMP;C:\SHELL\PSFetch"
    C:\Shell\OMP\OMP init pwsh --config "C:\Shell\ifl.omp.json" | Invoke-Expression
    PSFetch

    $architecture = $env:PROCESSOR_ARCHITECTURE.ToLower().Replace("amd", "x")

    function Enter-Developer-Environment {
        param (
            [string]
            $Target = $architecture,

            [string]
            $Machine = $architecture
        )

        $params = @{
            VsInstallPath   = "C:\Program Files\Microsoft Visual Studio\2022\Preview"
            DevCmdArguments = "-arch=$Target -host_arch=$Machine"
        }

        Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Preview\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
        $_INCLUDE = $env:INCLUDE
        $_LIB = $env:LIB
        $env:INCLUDE = ""
        $env:LIB = ""
        # $env:LIBPATH =  $(Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\Lib\' | Sort-Object Name -Descending)[0].FullName + "\um\" + $Target + ";"
        Enter-VsDevShell @params -SkipAutomaticLocation
        if (!$env:INCLUDE) {
            $env:INCLUDE = $_INCLUDE
        }
        if (!$env:LIB) {
            $env:LIB = $_LIB
        }
        "Developer Environment Initialized"
        ""
        "    Host architecture: $Machine"
        "  Target architecture: $Target"
    }

    Enter-Developer-Environment
}
else {
    /Shell/OMP/OMP init pwsh --config "/Shell/ifl.omp.json" | Invoke-Expression
}

function Edit-Profile {
    if ($env:OS -eq "Windows_NT") {
        code "C:\Shell\PowerShellProfile.ps1"
    }
    else {
        code "/Shell/PowerShellProfile.ps1"
    }
}

function Edit-OMPTheme {
    if ($env:OS -eq "Windows_NT") {
        code "C:\Shell\ifl.omp.json"
    }
    else {
        code "/Shell/ifl.omp.json"
    }
}

function Set-GitProxy {
    git config --global http.proxy http://127.0.0.1:7890
    git config --global https.proxy https://127.0.0.1:7890
}

function Unset-GitProxy {
    git config --global --unset http.proxy
    git config --global --unset https.proxy
}

function Get-BatteryReport {
    powercfg /batteryreport
    .\battery-report.html
    Start-Sleep 1
    Remove-Item .\battery-report.html
}

$DL = $(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

function Update-PowerShell {
    $buildid = $($(Invoke-WebRequest https://powershell.visualstudio.com/PowerShell/_build?definitionId=97).Content | Select-String '"id":([0-9]{6})[^/]*"sourceBranch":"refs/heads/master[^-]*"result":2').Matches[0].Groups[1].Value
    $latest = $($(Invoke-WebRequest "https://powershell.visualstudio.com/2972bb5c-f20c-4a60-8bd9-00ffe9987edc/_apis/build/builds/$buildid}/logs/83") | Select-String "PackageVersion: (.*[0-9])").Matches[0].Groups[1].Value
    $latestcommit = $($(Invoke-WebRequest "https://powershell.visualstudio.com/PowerShell/_build/results?buildId=$buildid}") | Select-String "[0-9a-f]{40}").Matches[0].Value
    $current = $PSVersionTable.PSVersion
    $currentcommit = $($(Get-ItemProperty "C:\Program Files\Powershell\7-preview\pwsh.exe").VersionInfo.ProductVersion | Select-String "[0-9a-f]{40}").Matches[0].Value
    if ($latestcommit -ne $currentcommit) {
        if ($latest -eq $current) {
            Write-Output "Updating PowerShell $current from commit $currentcommit to $latestcommit"
        }
        else {
            Write-Output "Updating PowerShell $current to $latest"
        }
        Invoke-WebRequest "https://powershell.visualstudio.com/2972bb5c-f20c-4a60-8bd9-00ffe9987edc/_apis/build/builds/$buildid}/artifacts?artifactName=artifacts&api-version=7.1&%24format=zip" -OutFile "$DL\PowerShell-$latest.zip" -Resume
        Expand-Archive -Force "$DL\PowerShell-$latest.zip" "$DL\~PowerShell"
        Remove-Item -Force -Recurse "$DL\PowerShell-$latest.zip"
        Copy-Item $(Get-ChildItem ~\Downloads\~PowerShell\artifacts\*win*x64*msi)[0] ~\Downloads\
        Remove-Item -Force -Recurse "$DL\~PowerShell"
        sudo msiexec /i $(Get-ChildItem ~\Downloads\*win*x64*msi)[0] /qb
    }
}


function Update-DotNETSDK {
    $latest = $([System.Text.Encoding]::UTF8.GetString($(Invoke-WebRequest $($(Invoke-WebRequest https://raw.githubusercontent.com/dotnet/sdk/main/documentation/package-table.md).Content | Select-String "\[win-x64-version-main\].*(https.*txt)").Matches[0].Groups[1].Value).Content) | Select-String "installer_version=\`"(.*)\`"").Matches[0].Groups[1].Value
    $current = $($(dotnet --list-sdks | Select-String "(\d{1,})\.\d{1,}\.\d{1,}(\-[a-z0-9\.]+)?").Matches |  Sort-Object { [Int]::Parse($_.Groups[1]) } -Descending)[0].Value
    if ($current -ne $latest) {
        Write-Output "Updating .NET SDK $current to $latest"
        Invoke-WebRequest $($(Invoke-WebRequest https://raw.githubusercontent.com/dotnet/sdk/main/documentation/package-table.md).Content | Select-String "\[win-x64-installer-main\].*(https.*exe)").Matches[0].Groups[1].Value -OutFile "$DL\dotnet-sdk-$latest-x64.exe" -Resume
        &"$DL\dotnet-sdk-$latest-x64.exe" /passive
    }
}

function Update-NodeJS {
    $latest = $($($($(Invoke-WebRequest https://nodejs.org/download/nightly/).Content | Select-String -AllMatches ">(v[^-]*-nightly([0-9]{8})[0-9a-z]*)/.*([0-9:]{5})").Matches | Sort-Object -Descending { $_.Groups[2], $_.Groups[3] }))[0].Groups[1].Value
    $current = $(node -v)
    if ($latest -ne $current) {
        Write-Output "Updating Node.JS $current to $latest"
        Invoke-WebRequest "https://nodejs.org/download/nightly/$latest/node-$latest-x64.msi" -OutFile "$DL\node-$latest-x64.msi" -Resume
        msiexec /i "$DL\node-$latest-x64.msi" /passive
    }
}

function Update-Go {
    class GoVersion {
        [string]$Version
        [ushort]$Major
        [ushort]$Minor
        [string]$Branch
        [ushort]$Revision

        GoVersion([System.Text.RegularExpressions.Match]$m) {
            $this.Version = $m.Groups[1].Value
            $this.Major = $m.Groups[2].Value
            $this.Minor = $m.Groups[3].Value
            $this.Branch = $m.Groups[5].Value
            if ($this.Branch.Length -lt 2) {
                $this.Branch = 'release'
            }
            $this.Revision = $m.Groups[6].Value
        }
    }

    $latest = $($($(Invoke-WebRequest https://go.dev/dl).Content | Select-String  -AllMatches ">go(([0-9]*)`.([0-9]*)((`.|beta|rc)([0-9]*))?).windows-amd64.msi<").Matches | % { [GoVersion]$_ } | Sort-Object -Descending Major, Minor, Branch, Revision)[0].Version
    $current = $(go version | Select-String " go([^ ]*) ").Matches[0].Groups[1].Value
    if ($latest -ne $current) {
        Write-Output "Updating Go $current to $latest"
        Invoke-WebRequest "https://go.dev/dl/go$latest.windows-amd64.msi" -OutFile "$DL\go$latest.windows-amd64.msi" -Resume
        msiexec /i "$DL\go$latest.windows-amd64.msi" /passive
    }
}

function Update-FFmpeg {
    $latest = $($(Invoke-WebRequest -AllowInsecureRedirect https://www.gyan.dev/ffmpeg/builds).Content | Select-String "version: <span id=`"git-version`">(20[0-9]{2}-[0-9]{2}-[0-9]{2}-git-[0-9a-f]{10})").Matches[0].Groups[1].Value
    $current = $(ffmpeg -version | Select-String "ffmpeg version (20[0-9]{2}-[0-9]{2}-[0-9]{2}-git-[0-9a-f]{10})").Matches[0].Groups[1].Value
    if ($latest -gt $current) {
        Write-Output "Updating FFmpeg $current to $latest"
        Invoke-WebRequest "https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z" -OutFile "$DL\ffmpeg-$latest-git-full.7z" -Resume
        # Expand-Archive -Force "$DL\ffmpeg-$latest-git-full.7z" "C:\Program Files\FFmpeg\"
    }
}

function Update-Kodi {
    $latest = $($($(Invoke-WebRequest "https://mirrors.kodi.tv/nightlies/windows/win64/master/").Content | Select-String "KodiSetup-([0-9a-f-]*)-master-x64.exe.*([0-9]{4}.*[0-9]{2})").Matches)[0]
    $latestversion = $latest.Groups[1].Value
    $latest = [DateTime]$latest.Groups[2].Value
    $current = $(Get-ItemProperty "C:\Program Files\Kodi\Kodi.exe").CreationTime
    if ($latest -gt $current) {
        Write-Output "Updating Kodi to $latestversion}"
        Invoke-WebRequest "https://mirrors.kodi.tv/nightlies/windows/win64/master/KodiSetup-$latestversion}-master-x64.exe" -OutFile "$DL\KodiSetup-$latestversion}-master-x64.exe" -Resume
        &"$DL\KodiSetup-$latestversion}-master-x64.exe"
    }
}

function Update-LLVM-PostProcess {
    Push-Location "C:\Program Files\LLVM\bin"

    Remove-Item clang++.exe
    Remove-Item clang-cpp.exe
    Remove-Item clang-cl.exe
    New-Item -ItemType HardLink -Name clang++.exe -Value clang.exe
    New-Item -ItemType HardLink -Name clang-cpp.exe -Value clang.exe
    New-Item -ItemType HardLink -Name clang-cl.exe -Value clang.exe

    Remove-Item ld.lld.exe
    Remove-Item ld64.lld.exe
    Remove-Item wasm-ld.exe
    Remove-Item lld-link.exe
    New-Item -ItemType HardLink -Name ld.lld.exe -Value lld.exe
    New-Item -ItemType HardLink -Name ld64.lld.exe -Value lld.exe
    New-Item -ItemType HardLink -Name wasm-ld.exe -Value lld.exe
    New-Item -ItemType HardLink -Name lld-link.exe -Value lld.exe

    Remove-Item llvm-dlltool.exe
    Remove-Item llvm-lib.exe
    Remove-Item llvm-ranlib.exe
    New-Item -ItemType HardLink -Name llvm-dlltool.exe -Value llvm-ar.exe
    New-Item -ItemType HardLink -Name llvm-lib.exe -Value llvm-ar.exe
    New-Item -ItemType HardLink -Name llvm-ranlib.exe -Value llvm-ar.exe

    Remove-Item llvm-strip.exe
    New-Item -ItemType HardLink -Name llvm-strip.exe -Value llvm-objcopy.exe

    Pop-Location
}

function Update-Affinity {
    $Products = ("Photo","Publisher","Designer")
    $CheckURL = "https://go.seriflabs.com/WindowsUpdate{0}2BetaUnpackaged"
    $MainFilePath = "C:\Program Files\Affinity\{0} 2 Beta\{0}.exe"
    $CurrentVersion = @{}
    $RemoteVersion = @{}

    $Products | % {
        $CurrentVersion[$_] = $(Get-ItemProperty $($MainFilePath -f $_)).VersionInfo.ProductVersion
        $RemoteVersion[$_] = $(Invoke-RestMethod $($CheckURL -f $_)).Version
    }

    $Products | % {
        if ($CurrentVersion[$_] -eq $RemoteVersion[$_]) {
            $RemoteVersion.Remove($_)
        }
    }

    $RemoteVersion.Keys | % {
        Write-Output "Updating Affinity $_ $($CurrentVersion[$_]) to $($RemoteVersion[$_])"
    }

    $RemoteVersion.Keys | % -Parallel {
        $DL = $USING:DL
        $RemoteVersion = $USING:RemoteVersion
        Invoke-WebRequest $("https://affin.co/{0}WinExeBeta" -f $_) -OutFile "$DL\Affinity$($_)2Beta-$($RemoteVersion[$_]).exe" -Resume
    }

    $RemoteVersion.Keys | % {
        $FILE = "$DL\Affinity$($_)2Beta-$($RemoteVersion[$_])"
        $BEG = $($(Format-Hex "$FILE.exe" -Count 0x80000).HexBytes | Join-String -Separator ' ' | Select-String "D0 CF 11 E0 A1 B1 1A E1").Matches[0].Captures[0].Index / 3
        $OFFSET = $(Get-ItemPropertyValue "$FILE.exe" -Name Length) - 0xFFFF8 - $BEG % 16
        $END = $($(Format-Hex "$FILE.exe" -Offset $OFFSET).HexBytes | Join-String -Separator ' ' | Select-String "00 00 00 00 00 00 00 00 4D 5A 90 00 03 00 00 00").Matches[0].Captures[0].Index / 3 + $OFFSET + 8
        $EXE = [System.IO.StreamReader]::new("$FILE.exe")
        $MSI = [System.IO.StreamWriter]::new("$FILE.msi")
        $EXE.BaseStream.Seek($BEG, [System.IO.SeekOrigin]::Begin)
        $EXE.BaseStream.CopyTo($MSI.BaseStream)
        $MSI.BaseStream.SetLength($END - $BEG)
        $EXE.Close()
        $MSI.Close()
    }

    $RemoteVersion.Keys | % {
        sudo msiexec /i "$DL\Affinity$($_)2Beta-$($RemoteVersion[$_]).msi" /qb
        Waiting-MSI
        Write-Output "Affinity$($_)2Beta-$($RemoteVersion[$_]) Installed"
    }
}

function Update-Affinity-PostProcess {
    Push-Location "C:\Program Files\Affinity"

    @("Photo", "Publisher", "Designer") | % { 
        if (-not $(Test-Path $_)) {
            New-Item -Type Junction -Name $_ -Value "$PWD\$_ 2 Beta"
        }
    }

    $FILES = $(Get-ChildItem -Recurse -File | Group-Object { $_.FullName.Split("\", 5)[-1] } | Where-Object { $_.Count -ge 3 } | % { $_.Name })
    $FILES | % {
        $FILE = $_
        New-Item Common\$FILE -Force
        Move-Item Photo\$FILE Common\$FILE -Force
        @("Publisher", "Designer") | % { 
            Remove-Item $_\$FILE
        }
    }
    @("Photo", "Publisher", "Designer") | % { 
        $PRODUCT = $_
        $FILES | % {
            New-Item -Type HardLink -Name $PRODUCT\$_ -Value Common\$_
        }
    }

    Pop-Location
}

function Uninstall-BundledEdge {
    if (([System.Security.Principal.WindowsIdentity]::GetCurrent()).Groups -match "S-1-5-32-544") {
        # Unregister-ScheduledTask *Edge* -Confirm:$false

        # sc delete edgeupdate
        # sc delete edgeupdatem

        # taskkill /f /im MicrosoftEdgeUpdate.exe

        # Get-ChildItem "C:\Program Files (x86)\Microsoft\EdgeWebView\*\Installer" -Recurse | % {
        #     Push-Location $_
        #     Copy-Item C:\SHELL\EDGEUNINSTALLER setup.exe
        #     ./setup.exe --uninstall --force-uninstall --system-level --msedgewebview
        #     Pop-Location
        # }

        Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\*\Installer" -Recurse | % {
            Push-Location $_
            Copy-Item C:\SHELL\EDGEUNINSTALLER setup.exe
            ./setup.exe --uninstall --force-uninstall --system-level --msedge
            Pop-Location
        }

        # Remove-Item -Recurse -Force "C:\Program Files (x86)\Microsoft"

        Remove-Item "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Force -Recurse
    }
    else {
        Write-Output "Run as Administrator and try again"
    }
}

function Start-AngryBirds {
    param (
        [string]
        $Edition
    )

    $SupportedEditions = [Ordered]@{
        "Classic"    = "C:\Angry Birds\Angry Birds\AngryBirds.exe"
        "Seasons"    = "C:\Angry Birds\Angry Birds Seasons\AngryBirdsSeasons.exe"
        "Rio"        = "C:\Angry Birds\Angry Birds Rio\AngryBirdsRio.exe"
        "Space"      = "C:\Angry Birds\Angry Birds Space\AngryBirdsSpace.exe"
        "StarWars"   = "C:\Angry Birds\Angry Birds Star Wars\AngryBirdsStarWars.exe"
        "StarWarsII" = "C:\Angry Birds\Angry Birds Star Wars II\AngryBirdsStarWarsII.exe"
    }

    $Edition = $Edition.Trim();

    if ($SupportedEditions.Keys.Contains($Edition)) {

    }
    else {
        Write-Output "SYNTAX"
        Write-Output "    Start-AngryBirds [-Edition] <Edition>"
        Write-Output ""
        Write-Output "REMARK"
        Write-Output "    Select one of follewing edtion:"
        foreach ($e in $SupportedEditions.GetEnumerator()) {
            $K = $e.Key.PadRight(10)
            $V = $e.Value.Split('\')[2]
            Write-Output "        $K for $V"
        }
    }
}

function Waiting-MSI {
    do {
        Start-Sleep 0.125
    } while (
        $(Get-Process msiexec -IncludeUserName -ErrorAction Ignore | Where-Object { $_.UserName -ne $null }).Count -lt 0 -or
        $(Get-Process sudo -IncludeUserName -ErrorAction Ignore | Where-Object { $_.UserName -ne $null }).Count -lt 0
    )
}