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
    $latestbuild = $($(Invoke-WebRequest https://powershell.visualstudio.com/PowerShell/_build?definitionId=32).Content | Select-String "buildId=([0-9]{6})").Matches[0].Groups[1].Value
    $latest = $($(Invoke-WebRequest "https://powershell.visualstudio.com/PowerShell/_build/results?buildId=${latestbuild}") | Select-String "[0-9a-f]{40}").Matches[0].Value
    $current = $($(Get-ItemProperty C:\PowerShell\pwsh.exe).VersionInfo.ProductVersion | Select-String "[0-9a-f]{40}").Matches[0].Value
    if ($latest -ne $current) {
        $version = $(Get-ItemProperty C:\PowerShell\pwsh.exe).VersionInfo.FileVersion
        Write-Output "Updating PowerShell ${version} ${current} to ${latest}"
        Invoke-WebRequest "https://powershell.visualstudio.com/2972bb5c-f20c-4a60-8bd9-00ffe9987edc/_apis/build/builds/${latestbuild}/artifacts?artifactName=build&api-version=7.1&%24format=zip" -OutFile "${DL}\PowerShell-${latest}.zip" -Resume
        Expand-Archive -Force "${DL}\PowerShell-${latest}.zip" "${DL}\~PowerShell"
        Expand-Archive -Force "${DL}\~PowerShell\build\build.zip" "${DL}\~PowerShell"
        Remove-Item -Force -Recurse C:\PowerShell.old
        Move-Item -Force C:\PowerShell\ C:\PowerShell.old
        Move-Item -Force "${DL}\~PowerShell\publish" C:\PowerShell
        Remove-Item -Force -Recurse "${DL}\~PowerShell"
    }
}


function Update-DotNETSDK {
    $latest = $([System.Text.Encoding]::UTF8.GetString($(Invoke-WebRequest $($(Invoke-WebRequest https://raw.githubusercontent.com/dotnet/installer/main/README.md).Content | Select-String "\[win-x64-version-main\].*(https.*txt)").Matches[0].Groups[1].Value).Content) | Select-String "installer_version=\`"(.*)\`"").Matches[0].Groups[1].Value
    $current = $(dotnet --list-sdks | Select-String "[^ ]*").Matches | Select-Object -ExpandProperty Value
    if (-not $current.Contains($latest)) {
        Write-Output "Updating .NET SDK ${current} to ${latest}"
        Invoke-WebRequest $($(Invoke-WebRequest https://raw.githubusercontent.com/dotnet/installer/main/README.md).Content | Select-String "\[win-x64-installer-main\].*(https.*exe)").Matches[0].Groups[1].Value -OutFile "${DL}\dotnet-sdk-${latest}-x64.exe" -Resume
        &"${DL}\dotnet-sdk-${latest}-x64.exe" /passive
    }
}

function Update-NodeJS {
    $latest = $($($($(Invoke-WebRequest https://nodejs.org/download/nightly/).Content | Select-String -AllMatches ">(v[^-]*-nightly([0-9]{8})[0-9a-z]*)/.*([0-9:]{5})").Matches | Sort-Object -Descending { $_.Groups[2], $_.Groups[3] }))[0].Groups[1].Value
    $current = $(node -v)
    if ($latest -ne $current) {
        Write-Output "Updating Node.JS ${current} to ${latest}"
        Invoke-WebRequest "https://nodejs.org/download/nightly/${latest}/node-${latest}-x64.msi" -OutFile "${DL}\node-${latest}-x64.msi" -Resume
        msiexec /i "${DL}\node-${latest}-x64.msi" /passive
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

    $latest = $($($(Invoke-WebRequest https://go.dev/dl).Content | Select-String  -AllMatches ">go(([0-9]*)`.([0-9]*)((`.|beta|rc)([0-9]*))?).windows-amd64.msi<").Matches | ForEach-Object { [GoVersion]$_ } | Sort-Object -Descending Major, Minor, Branch, Revision)[0].Version
    $current = $(go version | Select-String " go([^ ]*) ").Matches[0].Groups[1].Value
    if ($latest -ne $current) {
        Write-Output "Updating Go ${current} to ${latest}"
        Invoke-WebRequest "https://go.dev/dl/go${latest}.windows-amd64.msi" -OutFile "${DL}\go${latest}.windows-amd64.msi" -Resume
        msiexec /i "${DL}\go${latest}.windows-amd64.msi" /passive
    }
}

function Update-FFmpeg {
    $latest = $($(Invoke-WebRequest -AllowInsecureRedirect https://www.gyan.dev/ffmpeg/builds).Content | Select-String "version: <span id=`"git-version`">(20[0-9]{2}-[0-9]{2}-[0-9]{2}-git-[0-9a-f]{10})").Matches[0].Groups[1].Value
    $current = $(ffmpeg -version | Select-String "ffmpeg version (20[0-9]{2}-[0-9]{2}-[0-9]{2}-git-[0-9a-f]{10})").Matches[0].Groups[1].Value
    if ($latest -gt $current) {
        Write-Output "Updating FFmpeg ${current} to ${latest}"
        Invoke-WebRequest "https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z" -OutFile "${DL}\ffmpeg-${latest}-git-full.7z" -Resume
        # Expand-Archive -Force "${DL}\ffmpeg-${latest}-git-full.7z" "C:\Program Files\FFmpeg\"
    }
}

function Update-Kodi {
    $latest = $($($(Invoke-WebRequest "https://mirrors.kodi.tv/nightlies/windows/win64/master/").Content | Select-String "KodiSetup-([0-9a-f-]*)-master-x64.exe.*([0-9]{4}.*[0-9]{2})").Matches)[0]
    $latestversion = $latest.Groups[1].Value
    $latest = [DateTime]$latest.Groups[2].Value
    $current = $(Get-ItemProperty "C:\Program Files\Kodi\Kodi.exe").CreationTime
    if ($latest -gt $current) {
        Write-Output "Updating Kodi to ${latestversion}"
        Invoke-WebRequest "https://mirrors.kodi.tv/nightlies/windows/win64/master/KodiSetup-${latestversion}-master-x64.exe" -OutFile "${DL}\KodiSetup-${latestversion}-master-x64.exe" -Resume
        &"${DL}\KodiSetup-${latestversion}-master-x64.exe"
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

function Update-Affinity-PostProcess {
    Push-Location "C:\Program Files\Affinity"

    Get-ChildItem -Recurse -File | Group-Object { $_.FullName.Split("\", 5)[-1] } | ? { $_.Count -ge 3 } | Select-Object -Property Name |
        % {
            New-Item Common\$($_.Name) -Force
            Copy-Item Photo\$($_.Name) Common\$($_.Name) -Force
            Remove-Item Photo\$($_.Name)
            New-Item -Type HardLink -Name Photo\$($_.Name) -Value Common\$($_.Name)
            Remove-Item Publisher\$($_.Name)
            New-Item -Type HardLink -Name Publisher\$($_.Name) -Value Common\$($_.Name)
            Remove-Item Designer\$($_.Name)
            New-Item -Type HardLink -Name Designer\$($_.Name) -Value Common\$($_.Name)
        }

    Pop-Location
}

function Uninstall-BundledEdge {
    if (([System.Security.Principal.WindowsIdentity]::GetCurrent()).Groups -match "S-1-5-32-544") {
        # Unregister-ScheduledTask *Edge* -Confirm:$false

        # sc delete edgeupdate
        # sc delete edgeupdatem

        # taskkill /f /im MicrosoftEdgeUpdate.exe

        # Get-ChildItem "C:\Program Files (x86)\Microsoft\EdgeWebView\*\Installer" -Recurse | Foreach-Object {
        #     Push-Location $_
        #     Copy-Item C:\SHELL\EDGEUNINSTALLER setup.exe
        #     ./setup.exe --uninstall --force-uninstall --system-level --msedgewebview
        #     Pop-Location
        # }

        Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\*\Installer" -Recurse | Foreach-Object {
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

if (Test-Path -Path C:\PowerShell.old)
{
    Remove-Item -Force -Recurse C:\PowerShell.old
}