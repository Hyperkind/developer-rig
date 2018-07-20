@ECHO OFF
SETLOCAL

REM Create the temporary directory.
SET T=%TEMP%\cnf%RANDOM%
MD "%T%"

REM Check for elevation.
CALL "%~dp0check-configure.cmd"
IF ERRORLEVEL 1 (
	REM Continue configuration in an elevated command prompt.
	ECHO CreateObject^("Shell.Application"^).ShellExecute "cmd.exe", "/c " ^& WScript.Arguments^(0^), "", "runas" > "%T%\elevate.vbs"
	ECHO Installation will continue in an elevated command prompt.
	cscript //nologo "%T%\elevate.vbs" "%~f0 %~1"
	GOTO done
) ELSE IF "%~1" == "" (
	SET PAUSE=PAUSE
) ELSE (
	SET PAUSE=
)

REM Run the installation script first.
CALL "%~dp0install.cmd" -
IF ERRORLEVEL 1 GOTO done

REM Install dependencies.
CD /D "%~dp0.."
IF NOT EXIST node_modules (
	CMD /C yarn install
	IF ERRORLEVEL 1 (
		ECHO Cannot install developer rig dependencies.
		GOTO done
	)
)

REM Clone from GitHub and configure the "Hello World" extension.
SET MY=..\my-extension
SET WANTS_NPM_INSTALL=NO
IF EXIST %MY%\.git (
	PUSHD %MY%
	git remote update
	IF NOT ERRORLEVEL 1 (
		git status -uno | FIND "up to date" > NUL
		IF ERRORLEVEL 1 (
			SET WANTS_NPM_INSTALL=YES
			git pull --ff-only
		) ELSE IF NOT EXIST node_modules (
			SET WANTS_NPM_INSTALL=YES
		)
	)
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
IF "%WANTS_NPM_INSTALL%" == "YES" (
	CMD /C npm install
	IF ERRORLEVEL 1 (
		ECHO Cannot install "Hello World" extension dependencies.
		GOTO done
	)
)
POPD

REM Add localhost.rig.twitch.tv to /etc/hosts.
SET LOCALHOST=localhost.rig.twitch.tv
SET HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts
FIND "%LOCALHOST%" "%HOSTS_FILE%" > NUL
IF ERRORLEVEL 1 ECHO 127.0.0.1 %LOCALHOST%>> "%HOSTS_FILE%"
FIND "%LOCALHOST%" "%HOSTS_FILE%" > NUL
IF ERRORLEVEL 1 (
	ECHO Cannot update "%HOSTS_FILE%".
	ECHO Add "127.0.0.1 %LOCALHOST%" to "%HOSTS_FILE%" manually.
	GOTO done
)

REM Create CA and rig and localhost SSL certificates.
CALL "%~dp0make-cert.cmd" -

:done
SET EXIT_CODE=%ERRORLEVEL%
IF NOT %EXIT_CODE% == 0 %PAUSE% TYPE NUL
RD /Q /S %T%
EXIT /B %EXIT_CODE%
