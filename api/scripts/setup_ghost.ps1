---
layout: none
sitemap: false
---
$DownloadURL = 'https://github.com/ovsky/ghost-open-toolbox/archive/refs/heads/complete.zip'

$FilePath = "$env:TEMP\ghost_toolbox.zip"

try {
    Invoke-WebRequest -Uri $DownloadURL -UseBasicParsing -OutFile $FilePath;
}
catch {
    Write-Error $_
        Return
}

Expand-Archive -Force $FilePath -DestinationPath $env:TEMP\ghost_toolbox;
Set-Location "$env:TEMP\ghost_toolbox\ghost-open-toolbox-complete"
if (Test-Path "C:\Ghost Toolbox"){
    Remove-Item "C:\Ghost Toolbox" -Recurse
}
New-Item -ItemType Directory -Path "C:\Ghost Toolbox"
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-open-toolbox-complete\wget" -Destination "C:\Ghost Toolbox" -Recurse
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-open-toolbox-complete\toolbox.updater.x64.exe" -Destination "C:\Ghost Toolbox"
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-open-toolbox-complete\VCRUNTIME140_1D.dll" -Destination "C:\Ghost Toolbox"
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-open-toolbox-complete\VCRUNTIME140D.dll" -Destination "C:\Ghost Toolbox"
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-open-toolbox-complete\MSVCP140D.dll" -Destination "C:\Ghost Toolbox"
Start-Process PowerShell -Verb runAs -ArgumentList '-command Copy-Item $env:TEMP\ghost_toolbox\ghost-open-toolbox-complete\run.ghost.cmd C:\Windows\System32\migwiz\dlmanifests\run.ghost.cmd -Force'
Start-Process PowerShell -Verb runAs -ArgumentList '-command Copy-Item $env:TEMP\ghost_toolbox\ghost-open-toolbox-complete\nhcolor.exe C:\Windows\System32\nhcolor.exe -Force'
if((Test-Path -LiteralPath "HKLM:\SOFTWARE\WOW6432Node\GhostSpectre") -ne $true) 
{
    New-Item "HKLM:\SOFTWARE\WOW6432Node\GhostSpectre" -force -ea SilentlyContinue
};
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\GhostSpectre' -Name 'Edition' -Value 'SUPERLITE SE' -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\GhostSpectre' -Name 'Ghost_Revision' -Value '11' -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\GhostSpectre' -Name 'Check_Update' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
Set-Location $env:TEMP
Remove-Item "$env:TEMP\ghost_toolbox" -Recurse
Remove-Item $FilePath
