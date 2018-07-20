@ECHO OFF
SETLOCAL

REM Exit with an error if installation requires elevation.
SET REQUIRES_ELEVATION=0
IF NOT EXIST "%ProgramFiles%\Git\cmd\git.exe" SET REQUIRES_ELEVATION=1
IF NOT EXIST "%ProgramFiles%\nodejs\node.exe" SET REQUIRES_ELEVATION=1
IF NOT EXIST "%SystemDrive%\Python27\python.exe" SET REQUIRES_ELEVATION=1
IF NOT EXIST "%ProgramFiles(x86)%\Yarn\bin\yarn.cmd" SET REQUIRES_ELEVATION=1
IF %REQUIRES_ELEVATION% == 0 EXIT /B 0
net file > NUL 2> NUL
EXIT /B
