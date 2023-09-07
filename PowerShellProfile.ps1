Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete
Set-PSReadLineOption -PredictionViewStyle ListView

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
    code $PROFILE
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

function Update-DotNETSDK {
    $latest = $([System.Text.Encoding]::UTF8.GetString($(Invoke-WebRequest $($(Invoke-WebRequest https://raw.githubusercontent.com/dotnet/installer/main/README.md).Content | Select-String "\[win-x64-version-main\].*(https.*txt)").Matches[0].Groups[1].Value).Content) | Select-String "installer_version=\`"(.*)\`"").Matches[0].Groups[1].Value
    $current = $(dotnet --list-sdks | Select-String "[^ ]*").Matches | Select-Object -ExpandProperty Value
    if (-Not $current.Contains($latest)) {
        Write-Output "Updating .NET SDK to ${latest} (from ${current})"
        Invoke-WebRequest $($(Invoke-WebRequest https://raw.githubusercontent.com/dotnet/installer/main/README.md).Content | Select-String "\[win-x64-installer-main\].*(https.*exe)").Matches[0].Groups[1].Value -OutFile "${DL}\dotnet-sdk-${latest}-x64.exe" -Resume
        &"${DL}\dotnet-sdk-${latest}-x64.exe" /passive
    }
}

function Update-NodeJS {
    $latest = $($($($(Invoke-WebRequest https://nodejs.org/download/nightly/).Content | Select-String -AllMatches ">(v[^-]*-nightly([0-9]{8})[0-9a-z]*)/.*([0-9:]{5})").Matches | Sort-Object -Descending { $_.Groups[2], $_.Groups[3] }))[0].Groups[1].Value
    $current = $(node -v)
    if ($latest -ne $current) {
        Write-Output "Updating Node.JS to ${latest} (from ${current})"
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

    $latest = $($($(Invoke-WebRequest https://go.dev/dl).Content | Select-String  -AllMatches ">go(([0-9]*)`.([0-9]*)((`.|beta|rc)([0-9]*))?).windows-amd64.msi<").Matches | ForEach-Object { [GoVersion]$_ } | Sort-Object -Descending Major, Minor, Branch, Revision)[0]
    $current = $(go version | Select-String " go([^ ]*) ").Matches[0].Groups[1].Value
    if ($latest -eq $current) {
        Write-Output "Updating Go ${current} to ${latest}"
        Invoke-WebRequest "https://go.dev/dl/go${latest}.windows-amd64.msi" -OutFile "${DL}\go${latest}.windows-amd64.msi" -Resume
        msiexec /i "${DL}\go${latest}.windows-amd64.msi" /passive
    }
}

function Update-Kodi {
    $latest = $($($(Invoke-WebRequest "https://mirrors.kodi.tv/nightlies/windows/win64/master/").Content | Select-String "KodiSetup-([0-9a-f-]*)-master-x64.exe.*([0-9]{4}.*[0-9]{2})").Matches)[0]
    $latestversion = $latest.Groups[1].Value
    $latest = [DateTime]$latest.Groups[2].Value
    $current = $(Get-ItemProperty 'C:\Program Files\Kodi\Kodi.exe').CreationTime
    if ($latest -gt $current) {
        Write-Output "Updating Kodi to ${latestversion}"
        Invoke-WebRequest "https://mirrors.kodi.tv/nightlies/windows/win64/master/KodiSetup-${latestversion}-master-x64.exe" -OutFile "${DL}\KodiSetup-${latestversion}-master-x64.exe" -Resume
        &"${DL}\KodiSetup-${latestversion}-master-x64.exe"
    }
}

function Uninstall-UselessPackages {
    winget uninstall Cortana
    winget uninstall Clipchamp

    $(Remove-Item "HKCR:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Force -Recurse)
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
