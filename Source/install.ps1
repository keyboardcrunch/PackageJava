$ErrorActionPreference= 'silentlycontinue'

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
$Installer = Get-ChildItem -Path $ScriptDir\*.msi

Start-Process -FilePath "msiexec.exe" -ArgumentList " /i $Installer REMOVEOUTOFDATEJRES=1 REBOOT=Disable WEB_ANALYTICS=Disable AUTO_UPDATE=Disable /q" -Wait
	
# Disable Java update policy in registry
if ([System.IntPtr]::Size -eq 4) { # System 32bit
    # Disable Update
    New-ItemProperty -Path "HKLM:\SOFTWARE\JavaSoft\Java Update\Policy" -Name EnableJavaUpdate -PropertyType DWord -Value 00000000 -Force
    # Delete autorun Java Updater (update nagware)
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SunJavaUpdateSched"
} else { # System 64bit
    # Disable Update
    New-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\JavaSoft\Java Update\Policy" -Name EnableJavaUpdate -PropertyType DWord -Value 00000000 -Force
    # Delete autorun Java Updater (update nagware)
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" -Name "SunJavaUpdateSched"
}

# Uninstall Java Auto Updater
Try {
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x {4A03706F-666A-4037-7777-5F2748764D10} /qn /norestart" -Wait
} Catch {
    Write-Host "Skipped uninstall of Java Auto Updater" -ForegroundColor Red
}