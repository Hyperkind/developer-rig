@ECHO OFF
SETLOCAL

SET T=%TEMP%\%RANDOM%
MD "%T%"

REM Check for elevation.
SET HOSTS="%SystemRoot%\System32\drivers\etc\hosts"
FIND localhost.rig.twitch.tv %HOSTS% > nul
IF ERRORLEVEL 1 (
	net file > nul 2> nul
	IF ERRORLEVEL 1 (
		ECHO CreateObject ^( "Shell.Application" ^).ShellExecute "cmd.exe", "/c " ^& WScript.Arguments ^( 0 ^), "", "runas" > "%T%\elevate.vbs"
		ECHO Installation will continue in an elevated command prompt.
		cscript //nologo "%T%\elevate.vbs" "%~f0"
		GOTO done
	) ELSE (
		SET PAUSE=PAUSE
	)
)

REM Add localhost.rig.twitch.tv to /etc/hosts.
FIND localhost.rig.twitch.tv %HOSTS% > nul
IF ERRORLEVEL 1 ECHO '127.0.0.1 localhost.rig.twitch.tv' >> %HOSTS%
IF ERRORLEVEL 1 (
	ECHO Cannot update %HOSTS%.  Add "127.0.0.1 localhost.rig.twitch.tv" to %HOSTS% manually.
	GOTO done
)

REM Install dependencies.
CD /D "%~dp0.."
yarn install
IF ERRORLEVEL 1 (
	ECHO Cannot install developer rig dependencies.
	GOTO done
)

REM Create a panel extension manifest file.
yarn create-manifest -t panel -o ../panel.json

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
	yarn extension-init -d %MY%
	IF ERRORLEVEL 1 (
		ECHO Cannot initialize %MY%
		GOTO done
	)
)
PUSHD %MY%
npm install
IF ERRORLEVEL 1 (
	ECHO Cannot install "Hello World" extension dependencies.
	GOTO done
)
npm run cert
IF ERRORLEVEL 1 (
	ECHO Cannot create SSL certificates for the "Hello World" extension.
	GOTO done
)
POPD

:done
SET EXIT_CODE=%ERRORLEVEL%
RD /Q /S %T%
EXIT /B %EXIT_CODE%
