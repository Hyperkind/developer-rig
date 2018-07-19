@ECHO OFF
SETLOCAL

REM Configure the temporary directory.
SET T=%TEMP%\cnf%RANDOM%
MD "%T%"

REM Check for elevation.
SET LOCALHOST=localhost.rig.twitch.tv
SET HOSTS="%SystemRoot%\System32\drivers\etc\hosts"
FIND "%LOCALHOST%" %HOSTS% > NUL
IF ERRORLEVEL 1 SET CHECK_FOR_ELEVATION=YES
powershell -Command "& {Get-ChildItem -Path Cert:\LocalMachine\Root}" | FIND "Twitch Developer Rig CA" > NUL
IF ERRORLEVEL 1 SET CHECK_FOR_ELEVATION=YES
IF "%CHECK_FOR_ELEVATION%" == "YES" (
	net file > NUL 2> NUL
	IF ERRORLEVEL 1 (
		REM Continue installation in an elevated command prompt.
		ECHO CreateObject ^( "Shell.Application" ^).ShellExecute "cmd.exe", "/c " ^& WScript.Arguments ^( 0 ^), "", "runas" > "%T%\elevate.vbs"
		ECHO Installation will continue in an elevated command prompt.
		cscript //nologo "%T%\elevate.vbs" "%~f0"
		GOTO done
	) ELSE (
		SET PAUSE=PAUSE
	)
)

REM Add localhost.rig.twitch.tv to /etc/hosts.
FIND "%LOCALHOST%" %HOSTS% > NUL
IF ERRORLEVEL 1 ECHO 127.0.0.1 %LOCALHOST%>> %HOSTS%
FIND "%LOCALHOST%" %HOSTS% > NUL
IF ERRORLEVEL 1 (
	ECHO Cannot update %HOSTS%.  Add "127.0.0.1 %LOCALHOST%" to %HOSTS% manually.
	GOTO done
)

REM Install dependencies.
CD /D "%~dp0.."
CMD /C yarn install
IF ERRORLEVEL 1 (
	ECHO Cannot install developer rig dependencies.
	GOTO done
)

REM Create a panel extension manifest file.
CMD /C yarn create-manifest -t panel -o ../panel.json

REM Clone and configure the "Hello World" extension from GitHub.
SET MY=..\my-extension
IF EXIST %MY%\.git (
	PUSHD %MY%
	git pull
	IF ERRORLEVEL 1 (
		ECHO This is not a valid "Hello World" extension directory.  Please move or remove it before running this script again.
		GOTO done
	)
	POPD
) ELSE IF EXIST %MY% (
	ECHO There is already a file called "%MY%".  Please move or remove it before running this script again.
	GOTO done
) ELSE (
	CMD /C yarn extension-init -d %MY%
	IF ERRORLEVEL 1 (
		ECHO Cannot initialize %MY%
		GOTO done
	)
)
PUSHD %MY%
CMD /C npm install
IF ERRORLEVEL 1 (
	ECHO Cannot install "Hello World" extension dependencies.
	GOTO done
)
POPD

REM Create CA and rig and localhost SSL certificates.
CALL "%~dp0make-cert.cmd" -

:done
SET EXIT_CODE=%ERRORLEVEL%
RD /Q /S %T%
%PAUSE%
EXIT /B %EXIT_CODE%
