@ECHO OFF
SETLOCAL

REM Exit with an error if configuration requires elevation.
CALL "%~dp0check-install.cmd"
IF ERRORLEVEL 1 EXIT /B
SET REQUIRES_ELEVATION=0
SET LOCALHOST=localhost.rig.twitch.tv
SET HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts
FIND "%LOCALHOST%" "%HOSTS_FILE%" > NUL
IF ERRORLEVEL 1 SET REQUIRES_ELEVATION=1
powershell -Command "& {Get-ChildItem -Path Cert:\LocalMachine\Root}" | FIND "Twitch Developer Rig CA" > NUL
IF ERRORLEVEL 1 SET REQUIRES_ELEVATION=1
IF %REQUIRES_ELEVATION% == 0 EXIT /B 0
net file > NUL 2> NUL
EXIT /B
