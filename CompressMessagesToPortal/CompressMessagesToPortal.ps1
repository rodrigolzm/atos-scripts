$START = "20160414"
$END = "20160425"
$DISCIPLINES = "SH"
$EVENT = "TEV"

$BASE_FOLDER = "D:\DATA\IDS\DFV\WEB\APP\messages"
$FOLDER_LIST = Get-ChildItem -Path $BASE_FOLDER
$DISCIPLINE_LIST = $DISCIPLINES.split(",")

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

write-host "Start of period: $START"
write-host "End of period: $END"
write-host "Discipline: $DISCIPLINES"
write-host "Event: $EVENT"

foreach ($DAY in $FOLDER_LIST) {
	if (($DAY.Name -ge $START) -and ($DAY.Name -le $END)) {
	
		$FOLDER = $BASE_FOLDER + "\" + $DAY
		$SPORT_LIST = Get-ChildItem -Path $FOLDER
		$NAME = $DAY.Name.substring(0,4) + "-" + $DAY.Name.substring(4,2) + "-" + $DAY.Name.substring(6,2)
		
		foreach ($SPORT in $SPORT_LIST) {
			foreach ($DISCIPLINE in $DISCIPLINE_LIST) {
				if ($SPORT.Name -eq $DISCIPLINE) {
					
					$FOLDER = $FOLDER + "\" + $SPORT
					
					write-host ""
					write-host "Compressing messages from $SPORT"
					create-7zip "$FOLDER" "$BASE_FOLDER\$DISCIPLINE $EVENT $NAME.zip"
				}
			}
		}
	}
}

write-host ""
write-host "-------------------------------------------------------------------"
write-host "Script finished"
write-host "-------------------------------------------------------------------"
write-host ""
write-host ""