$BASE_FOLDER = "D:\DATA\IDS\DFV\WEB\APP"

$INDEXES_FOLDER = $BASE_FOLDER + "\indexes"
$MESSAGES_FOLDER = $BASE_FOLDER + "\messages"
$MESSAGES_BACKUP = $BASE_FOLDER + "\backup\messages"
$FOLDERLIST = Get-ChildItem -Path $MESSAGES_FOLDER

$CURRENT_DAY = (Get-Date -format yyyyMMdd)
$BASE_DAY = (Get-Date).AddDays(-7).ToString("yyyyMMdd")

function create-7zip([String] $aDirectory, [String] $aZipfile){
    [string]$pathToZipExe = "$($Env:ProgramFiles)\7-Zip\7z.exe";
    [Array]$arguments = "a", "-tzip", "$aZipfile", "$aDirectory", "-r", "-x!*.zip";
    & $pathToZipExe $arguments;
}

write-host ""
write-host ""
write-host "-------------------------------------------------------------------"
write-host "Script started"
write-host "-------------------------------------------------------------------"
write-host ""

write-host "Current Day: $CURRENT_DAY"
write-host "Base Day: $BASE_DAY"
write-host "Indexes Folder: $INDEXES_FOLDER"
write-host "Messages Folder: $MESSAGES_FOLDER"
write-host "Messages Backup Faolder: $MESSAGES_BACKUP"

write-host ""
write-host "Stopping DFV service"
get-service -name "JBOSS-MEV-DFV" | stop-service

foreach ($FOLDER in $FOLDERLIST) {
	if (($BASE_DAY -gt $FOLDER.Name) -or ($CURRENT_DAY -lt $FOLDER.Name)) {
		write-host ""
		write-host "Compressing $FOLDER and storing in Backup Folder"
		create-7zip "$MESSAGES_FOLDER\$FOLDER" "$MESSAGES_BACKUP\$FOLDER.zip"

		write-host ""
		write-host "Removing $FOLDER from Messages Folder"
		Remove-Item "$MESSAGES_FOLDER\$FOLDER" -recurse
	}
}

write-host ""
write-host "Removing Indexes"
Remove-Item "$INDEXES_FOLDER\*" -recurse

write-host ""
write-host "Starting DFV service"
get-service -name "JBOSS-MEV-DFV" | set-service -status Running

write-host ""
write-host "-------------------------------------------------------------------"
write-host "Script finished"
write-host "-------------------------------------------------------------------"
write-host ""
write-host ""