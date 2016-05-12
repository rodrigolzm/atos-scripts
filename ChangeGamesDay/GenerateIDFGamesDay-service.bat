@echo off

rem Generates file with the IDF Games Day

rem The file is stored in the IDF Global Repository.
rem This script should be run once per day, preferably in the morning,
rem about 06:00 am. It can be scheduled using Windows scheduler.

set IDF_CONFIG_DIR=F:\DATA\IDS\IDF\SRV\APP\repository\Common\config
set IDF_DAY_FILE=%IDF_CONFIG_DIR%\day.xml
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
set GAMES_DAY=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%

set "IDF_DAY_FILE_CONTENT=^<day^>^<games-day tag="%GAMES_DAY%" /^>^</day^>"

set LOGNAME=%~n0
set LOGDIR=D:\LOG\IDSIDF\%LOGNAME%
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

call :main >> %LOGFILE% 2>&1
goto :EOF


:logtime
echo %ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2% %time:~0,2%:%time:~3,2%:%time:~6,2% %~1

goto :EOF


:main
set CUR_DIR=%~dp0
cd /d %CUR_DIR%

rem Error exit code of the script
set ERRNUM=

call :logtime "INFO  Script started."
if not exist %IDF_CONFIG_DIR% (
  call :logtime "ERROR Configuration folder in IDF repository cannot be accessed: '%IDF_CONFIG_DIR%'"
  goto :end
)
if not exist %IDF_DAY_FILE% (
  call :logtime "ERROR File does not exist: '%IDF_DAY_FILE%'"
  call :logtime "ERROR Day.xml is never created by this script: it must always exist."
  goto :end
)

call :logtime "INFO  Setting IDF Games Day to '%GAMES_DAY%' in file '%IDF_DAY_FILE%'"
echo %IDF_DAY_FILE_CONTENT% > %IDF_DAY_FILE%

rem gcm -module Services

call :logtime "INFO  Stopping IDF Dispatcher..."

powershell -c "Get-Service 'MEV IDF' | Stop-Service"
if errorlevel 1 (
  call :logtime "ERROR trying to stop Service 'MEV IDF'"
  exit /b 1
)

call :logtime "INFO  Stopped IDF Dispatcher."

call :logtime "INFO  Starting IDF Dispatcher..."
powershell -c "Get-Service 'MEV IDF' | Start-Service"
if errorlevel 1 (
  call :logtime "ERROR trying to stop Resource 'MEV IDF'"
  exit /b 2
)
call :logtime "INFO  Started IDF Dispatcher."


rem check error from restarting service.
if errorlevel 1 (
  set ERRNUM=1
)

:end
call :logtime "INFO  Script finished."
exit /b %ERRNUM%
