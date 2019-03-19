
$MainPage = "https://java.com/en/download/"
$DownloadPage = "https://java.com/en/download/manual.jsp"
$PackageLocation = "\\APPPATH\Java\"
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
$SourceDir = "$ScriptDir\Source\"
$DownloadDir = "$SourceDir\Download\"

# Grab current version from the main Java page
$VerReq = Invoke-WebRequest $MainPage
$Ver = $VerReq.AllElements | Where {$_.TagName -eq "h4"} | Select innerText
$Ver = $Ver.innerText[0]
$Ver = $Ver.Trim()
$FileName = $Ver.Replace(" ", "")
$FileName = $FileName.Replace("Update", "u")
$FileName = "jre-$FileName-"

# Check if content has already been downloaded
$JavaPackage = $PackageLocation + $Ver

Write-Host "Latest version is $Ver" -ForegroundColor Yellow


If (-not( Test-Path $JavaPackage )) {
    # Package yet to be built, build it now.
    write-host "Package doesn't exist, Creating it now."
    $nil = New-Item -Path $JavaPackage -ItemType Directory
    $nil = New-Item -Path "$JavaPackage\x86" -ItemType Directory
    $nil = New-Item -Path "$JavaPackage\x64" -ItemType Directory
    Start-Sleep -s 5
} Else {
    write-host "Package already created." -ForegroundColor Green
}


# Cleanup download directory for new package
Write-Host "Prepping download folder..." -ForegroundColor Green
Get-ChildItem -Path $DownloadDir -Recurse | Remove-Item -force -recurse | Out-Null
Remove-Item $DownloadDir -Force | Out-Null
$nil = New-Item -Path $DownloadDir -ItemType Directory -Force | Out-Null
Start-Sleep -s 3

# Download files 
Import-Module BitsTransfer
$Response = Invoke-WebRequest $DownloadPage
Foreach ( $LinkData in $Response.Links ) {
	If ( $LinkData.innerText -eq "Windows Offline" ) {
		$download = $LinkData.href
		$output = $DownloadDir + $FileName + "i586.exe"
		Start-BitsTransfer -Source $download -Destination $output
	} Elseif ( $LinkData.innerText -eq "Windows Offline (64-bit)" ) {
		$download = $LinkData.href
		$output = $DownloadDir + $FileName + "x64.exe"
		Start-BitsTransfer -Source $download -Destination $output
	} Else {
		Continue
	}
}


# Extract msi files from exe files
$SourceFiles = Get-ChildItem -Path $DownloadDir\*.exe
$LocalLowJava = "$env:LOCALAPPDATA\Oracle\Java" -replace 'Local', 'LocalLow'
# Clearing the Java Temp installer folder, before we start
If ( Test-Path -Path $LocalLowJava ) {
	Remove-Item -Path "$LocalLowJava\*" -Recurse -Force | Out-Null
}

ForEach($sFile in $SourceFiles) {
	# grabbing the java version from the file name
	$jreVersion = Select-String -Pattern '[0-9]u[0-9]+' -InputObject $sFile.Name |
	ForEach-Object -Process {
	  $_.Matches
	} |
	ForEach-Object -Process {
	  $_.Value
	}

	# Converting the Java version to the temp file name structure
	$jreTempVersion = $jreVersion -replace 'u', '.0_'

	# Setting the temp MSI path
	If($sFile -like "*x64*") {
	  $jreTempMSI = "$LocalLowJava\jre1.$($jreTempVersion)_x64\jre1.$($jreTempVersion)64.msi"
	} Else {
	  $jreTempMSI = "$LocalLowJava\jre1.$jreTempVersion\jre1.$jreTempVersion.msi"
	}


	Write-Host -Object "Start grabbing $jreTempMSI"
	# Starting the Java installer
	Start-Process -FilePath $sFile -WindowStyle Hidden
	# Waiting for the MSI to be extracted by the EXE file
	while(!(Test-Path $jreTempMSI)) {
	  Start-Sleep -Seconds 2
	}

	
    Write-Host "Copying MSI file to package directory..." -ForegroundColor Green
	If($sFile -like "*x64*") {
		Copy-Item -Path $jreTempMSI -Destination "$JavaPackage\x64\" -Force | Out-Null
	} Else {
		Copy-Item -Path $jreTempMSI -Destination "$JavaPackage\x86\" -Force | Out-Null
	}

	# $ProcessName = split-path $sFile -Leaf

	# Kill the Java Process
    Write-Host "Killing Java installer..." -ForegroundColor Green
	Start-Process -FilePath "taskkill" -ArgumentList "/F /IM jre*"
	Start-Sleep -Seconds 5
}

# Copy install script to package folders
Write-Host "Copying install script into package directories..." -ForegroundColor Green
Copy-Item -Path "$SourceDir\install.ps1" -Destination "$JavaPackage\x64\" -Force | Out-Null
Copy-Item -Path "$SourceDir\install.ps1" -Destination "$JavaPackage\x86\" -Force | Out-Null
