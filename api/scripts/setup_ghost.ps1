---
layout: none
sitemap: false
---
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "The script has to be run as an administrator"
    Read-Host -Prompt "Press any key to exit."
    Return
}

$DownloadURL = 'https://github.com/shomykohai/ghost-toolbox-src/archive/refs/heads/main.zip'

$FilePath = "$env:TEMP\ghost_toolbox.zip"

try {
    Invoke-WebRequest -Uri $DownloadURL -UseBasicParsing -OutFile $FilePath;
}
catch {
    Write-Error $_
        Return
}

Expand-Archive -Force $FilePath -DestinationPath $env:TEMP\ghost_toolbox;
Set-Location "$env:TEMP\ghost_toolbox\ghost-toolbox-src-main"
if (Test-Path "C:\Ghost Toolbox"){
    Write-Host "Found another instance of Ghost Toolbox directory."
    Write-Host "Removing old Ghost Toolbox."
    Remove-Item "C:\Ghost Toolbox" -Recurse
}
Write-Host "Creating new Ghost Toolbox directory."
New-Item -ItemType Directory -Path "C:\Ghost Toolbox"
Write-Host "Copying files..."
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-toolbox-src-main\wget" -Destination "C:\Ghost Toolbox" -Recurse
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-toolbox-src-main\toolbox.updater.x64.exe" -Destination "C:\Ghost Toolbox"
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-toolbox-src-main\run.ghost.cmd" -Destination "C:\Windows\System32\migwiz\dlmanifests\run.ghost.cmd" -Force
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-toolbox-src-main\nhcolor.exe" -Destination "C:\Windows\System32\nhcolor.exe" -Force
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-toolbox-src-main\ucrtbased.dll" -Destination "C:\Windows\System32\ucrtbased.dll" -Force
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-toolbox-src-main\vcruntime140_1d.dll" -Destination "C:\Windows\System32\vcruntime140_1d.dll" -Force
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-toolbox-src-main\vcruntime140d.dll" -Destination "C:\Windows\System32\vcruntime140d.dll" -Force
Copy-Item -Path "$env:TEMP\ghost_toolbox\ghost-toolbox-src-main\msvcp140d.dll" -Destination "C:\Windows\System32\msvcp140d.dll" -Force


Write-Host "Gaining SE Edition privileges..."
if((Test-Path -LiteralPath "HKLM:\SOFTWARE\WOW6432Node\GhostSpectre") -ne $true) 
{
    New-Item "HKLM:\SOFTWARE\WOW6432Node\GhostSpectre" -force -ea SilentlyContinue
};
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\GhostSpectre' -Name 'Edition' -Value 'SUPERLITE SE' -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\GhostSpectre' -Name 'Ghost_Revision' -Value '17' -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\GhostSpectre' -Name 'Check_Update' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
Set-Location $env:TEMP
Write-Host "Cleanup..."
Remove-Item "$env:TEMP\ghost_toolbox" -Recurse
Remove-Item $FilePath

Write-Host "Done."
Read-Host -Prompt "Press any key to exit."
