@ECHO OFF
SETLOCAL

REM Create the temporary directory.
SET T=%TEMP%\%RANDOM%
MD "%T%"

REM Check for elevation.
CALL "%~dp0check-install.cmd"
IF ERRORLEVEL 1 (
	ECHO CreateObject^("Shell.Application"^).ShellExecute "cmd.exe", "/c " ^& WScript.Arguments^(0^), "", "runas" > "%T%\elevate.vbs"
	ECHO Installation will continue in an elevated command prompt.
	cscript //nologo "%T%\elevate.vbs" "%~f0 %~1"
	GOTO done
) ELSE IF "%~1" == "" (
	SET PAUSE=PAUSE
) ELSE (
	SET PAUSE=
)

REM Create the PowerShell script to download installers.
SET DL="%T%\dl.ps1"
ECHO [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" >> %DL%
ECHO $client = new-object System.Net.WebClient >> %DL%
ECHO $client.DownloadFile^($args[0], $args[1]^) >> %DL%
SET DL=powershell -file %DL%

REM Download and invoke installers for Git, Node, Python 2, and Yarn.
IF EXIST "%ProgramFiles%\Git\cmd\git.exe" (
	ECHO Git is already installed.
	GOTO skip_git
)
ECHO Downloading Git...
%DL% "https://github.com/git-for-windows/git/releases/download/v2.18.0.windows.1/Git-2.18.0-64-bit.exe" "%T%\Git-2.18.0-64-bit.exe"
IF ERRORLEVEL 1 GOTO done
ECHO Installing Git...
SET INFO="%T%\git.info"
ECHO [Setup]>> %INFO%
ECHO Components=icons,icons\desktop,ext,ext\shellhere,ext\guihere,gitlfs,assoc,assoc_sh>> %INFO%
ECHO SSHOption=OpenSSH>> %INFO%
ECHO CURLOption=WinSSL>> %INFO%
ECHO PerformanceTweaksFSCache=Enabled>> %INFO%
ECHO UseCredentialManager=Enabled>> %INFO%
ECHO EnableSymlinks=Enabled>> %INFO%
"%T%\Git-2.18.0-64-bit.exe" /LOADINF=%INFO% /VERYSILENT /NORESTART /RESTARTEXITCODE=3
IF %ERRORLEVEL% == 3 (
	SET MUST_RESTART=yes
) ELSE IF ERRORLEVEL 1 (
	GOTO done
)
:skip_git
IF EXIST "%ProgramFiles%\nodejs\node.exe" (
	ECHO Node is already installed.
	GOTO skip_node
)
CALL :doit Node "https://nodejs.org/dist/v8.11.3/node-v8.11.3-x64.msi"
IF ERRORLEVEL 1 GOTO done
:skip_node
IF EXIST "%SystemDrive%\Python27\python.exe" (
	ECHO Python 2 is already installed.
	GOTO skip_python
)
CALL :doit "Python 2" "https://www.python.org/ftp/python/2.7.15/python-2.7.15.amd64.msi" "ADDLOCAL=DefaultFeature,SharedCRT,Extensions,TclTk,Documentation,Tools,pip_feature,PrependPath"
IF ERRORLEVEL 1 GOTO done
:skip_python
IF EXIST "%ProgramFiles(x86)%\Yarn\bin\yarn.cmd" (
	ECHO Yarn is already installed.
	GOTO skip_yarn
)
CALL :doit Yarn "https://yarnpkg.com/latest.msi"
IF ERRORLEVEL 1 GOTO done
:skip_yarn

REM Clean up, report results, and exit.
:done
SET EXIT_CODE=%ERRORLEVEL%
RD /Q /S %T%
IF NOT %EXIT_CODE% == 0 (
	ECHO Installation failed
) ELSE IF "%MUST_RESTART%" == "yes" (
	ECHO You must restart your machine before using the Developer Rig.
	SET PAUSE=PAUSE
)
%PAUSE%
EXIT /B %EXIT_CODE%

REM Download and invoke an installer.
:doit
ECHO Downloading %~1...
SET I="%T%\installer.msi"
IF EXIST %I% DEL /F /Q %I%
%DL% %2 %I%
IF NOT ERRORLEVEL 1 (
	ECHO Installing %~1...
	msiexec /i %I% /quiet /qn /norestart %~3
)
