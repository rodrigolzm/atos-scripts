@echo off
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
set GAMES_DAY=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%

set LOGNAME=%~n0
set LOGDIR=D:\LOG\DFV\backup-script
set LOGFILE=%LOGDIR%\%LOGNAME%.log.%GAMES_DAY%

md %LOGDIR% >nul 2>&1
if not exist %LOGDIR% (
  echo Cannot create log directory %LOGDIR%
  exit /b 1
)
echo. >> %LOGFILE% 2>nul
if not exist %LOGFILE% (
  echo Cannot create log file %LOGFILE%
  exit /b 1
)

powershell -File %ATOS_HOME%\scripts\ps1\backupMessagesFromDFV.ps1 > %LOGFILE%