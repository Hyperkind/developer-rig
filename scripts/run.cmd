@ECHO OFF
SETLOCAL

REM Configure the temporary directory.
SET T=%TEMP%\rig%RANDOM%
MD "%T%"

REM Collect command line parameters.
:loop
IF "%~1" == "" GOTO end
IF "%~1" == "-m" (
	CALL :collect MANIFEST_FILE "%~2" "manifest file"
) ELSE IF "%~1" == "-f" (
	CALL :collect FRONTEND_DIRECTORY "%~2" "front-end directory"
) ELSE IF "%~1" == "-b" (
	CALL :collect BACKEND_FILE "%~2" "back-end file"
) ELSE (
	GOTO usage
)
IF ERRORLEVEL 1 GOTO done
SHIFT /1
SHIFT /1
GOTO loop
:end

REM Check for elevation and invoke configuration appropriately.
CALL "%~dp0check-configure.cmd"
IF ERRORLEVEL 1 (
	CALL "%~dp0configure.cmd"
	ECHO When configuration completes,
	PAUSE
) ELSE (
	CALL "%~dp0configure.cmd" -
)

REM Provide defaults, if requested.
IF "%MANIFEST_FILE%" == "" IF "%FRONTEND_DIRECTORY%" == "" IF "%BACKEND_FILE%" == "" (
	SET MANIFEST_FILE=..\panel.json
	SET FRONTEND_DIRECTORY=..\my-extension
	SET BACKEND_FILE=..\my-extension\services\backend.js
)

REM For the "hello world" extension, ensure service of the correct directory.
IF EXIST "%FRONTEND_DIRECTORY%\public" SET FRONTEND_DIRECTORY=%FRONTEND_DIRECTORY%\public

REM If necessary, create a panel extension manifest file.
IF "%MANIFEST_FILE%" == "" SET MANIFEST_FILE=..\panel.json
IF EXIST "%MANIFEST_FILE%" (
	ECHO Using extension manifest in %MANIFEST_FILE%.
) ELSE (
	ECHO Creating and using panel extension manifest in %MANIFEST_FILE%.
	CMD /C yarn create-manifest -t panel -o "%MANIFEST_FILE%"
)

REM Start new command prompts for the different aspects of running the rig.
SET NWINDOWS=1
SET S=
IF "%FRONTEND_DIRECTORY%" == "" (
	ECHO Front-end hosting is not being provided by the developer rig.
) ELSE (
	ECHO Hosting front-end in %FRONTEND_DIRECTORY%.
	SET /A NWINDOWS+=1
	SET S=s
	START "%FRONTEND_DIRECTORY%" CMD /C yarn host -d "%FRONTEND_DIRECTORY%" -p 8080 -l
)
IF "%BACKEND_FILE%" == "" (
	ECHO Back-end hosting is not being provided by the developer rig.
) ELSE (
	ECHO Hosting back-end in %BACKEND_FILE%.
	SET /A NWINDOWS+=1
	SET S=s
	START "%BACKEND_FILE%" CMD /C node "%BACKEND_FILE%" -l "%MANIFEST_FILE%"
)
START "%MANIFEST_FILE%" CMD /C yarn start -l "%MANIFEST_FILE%"
ECHO Opened %NWINDOWS% other command prompt%S% to run the developer rig.

:done
SET EXIT_CODE=%ERRORLEVEL%
RD /Q /S "%T%"
EXIT /B %EXIT_CODE%

:usage
ECHO.
ECHO usage: %0 [-m manifest-file] [-f front-end-directory] [-b back-end-file]
ECHO.
ECHO Specify no command line arguments to use defaults for all of them.
GOTO done

:collect
IF EXIST "%~2" (
	SET %1=%~2
) ELSE (
	ECHO Cannot open %~3 "%~2".
	"%T%\fail" 2> NUL
)
