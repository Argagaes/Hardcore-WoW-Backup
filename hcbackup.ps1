#Hardcore WoW backup script v1.1
#Made by Argagaes at https://github.com/Argagaes/Hardcore-WoW-Backup

Write-Output "Starting Hardcore WoW backup script v1.1 by Argagaes (@argagaes on Discord)"

if (!(Test-Path -Path ".\settings.txt")) {
	Write-Output "Settings.txt is missing! Example file can be found from https://github.com/Argagaes/Hardcore-WoW-Backup"
	return
}

Get-Content ".\settings.txt" | foreach-object -begin {$settings=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $settings.Add($k[0], $k[1]) } }

if (($settings.DataPath -eq $null) -or ($settings.BackupTo -eq $null) -or !(Test-Path -Path $settings.DataPath)) {
	Write-Output "Set data and backup paths into settings.txt!"
	Write-Output "Example entries (WILL NOT WORK DIRECTLY, PLEASE FIND THE CORRECT PATHS FOR YOUR SETUP):"
	Write-Output "DataPath=D:\battlenet\Wow\World of Warcraft\_classic_era_\WTF\Account\{YOUR ACCOUNT}\Hydraxian Waterlords\"
	Write-Output "BackupTo=C:\Users\Argagaes\Desktop\hcbackups\"
	return
}

$settings.TTSReminder = [System.Convert]::ToBoolean($settings.TTSReminder)
$settings.SaveInterval = [int]$settings.SaveInterval

$SubDirs = Get-ChildItem -Path $settings.DataPath

$script:ModifiedMap = @{}

foreach ($file in $SubDirs) {
	Write-Output ("Found character: " + $file.name)
	$tmpFilePath = $file.fullname + "\SavedVariables\Hardcore.lua"
	$script:ModifiedMap.add($file.name, (Get-Item $tmpFilePath).LastWriteTime)
}

$State = 0

if ($settings.TTSReminder) {
	$script:voice = New-Object -ComObject Sapi.spvoice
	$script:voice.rate = 0
}

if (!(Test-Path -Path $settings.BackupTo)) {
	mkdir -Path $($settings.BackupTo) -Force
}

function Backup {
	Write-Output "Creating backup..."
	$NewDirs = Get-ChildItem -Path $settings.DataPath
	$script:NewFound = $false
	foreach ($file in $NewDirs) {
		$tmpFilePath = $file.fullname + "\SavedVariables\Hardcore.lua"

		if ($script:ModifiedMap[$file.name] -eq $null) {
			Write-Output ("Found a new character: " + $file.name)
			$script:ModifiedMap.add($file.name, (Get-Item $tmpFilePath).LastWriteTime)
		}

		$NewLastModified = (Get-Item $tmpFilePath).LastWriteTime

		if (!($NewLastModified -eq $script:ModifiedMap[$file.name])) {
			Write-Output ("Created backup for " + $file.name)
			$script:NewFound = $true
			$OutPath = $settings.BackupTo+$file.name+"\Hardcore-"+(Get-Date).ToString("MM-dd-hh-mm")+".bak*"

			if (!(Test-Path -Path ($settings.BackupTo+$file.name))) {
				mkdir -Path $($settings.BackupTo+$file.name) -Force
			}

			xcopy $tmpFilePath $OutPath /D /S /Y /Q > nul
			$script:ModifiedMap[$file.name] = $NewLastModified
		}
	}
	

	if (!$script:NewFound) {
		Write-Output "Data has not been saved since last backup, remember to /reload!"
		if ($settings.TTSReminder) {
			$script:voice.speak($settings.TTSMessage) > $nul
		}
	}
}

while ($true) {					 										# Loop
	Write-Output "Waiting for WoWClassic process..."
	while ($State -eq 0) {													# Waiting for WoW to open
		$Procs = Get-Process WowClassic -ErrorAction SilentlyContinue   	# Find classic wow instance 
		if (($procs).Count -eq 0) {   
			Start-Sleep -Seconds (1 * 60)				  					# Wait 1 minute if not found
		} else {
			Write-Output "WoWClassic process found! Starting backups"
			$script:State = 1														# Wow was found, move to backup state
		}
	}

	:outer while ($State -eq 1) {
		for ($num = 1 ; $num -le ($settings.SaveInterval * 6) ; $num++) {				# Sleep for the backup interval, but check for wow closing every 10 seconds
			Start-Sleep -Seconds (10)
			$Procs = Get-Process WowClassic -ErrorAction SilentlyContinue   # Find classic wow instance to see if it has been closed
			if (($procs).Count -eq 0) {   									
				Write-Output "WoWClassic has been closed! Stopping backups and going into wait mode"
				Backup
				$script:State = 0
				break outer
			}
		}
		Backup
	}
}
