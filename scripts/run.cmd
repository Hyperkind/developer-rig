@ECHO OFF
SETLOCAL

REM Configure the temporary directory.
SET T=%TEMP%\rig%RANDOM%
MD "%T%"

REM Collect command line parameters.
SET NWINDOWS=1
:loop
IF "%~1" == "" GOTO end
IF "%~1" == "-m" (
	CALL :collect MANIFEST_FILE "%~2" "manifest file"
) ELSE IF "%~1" == "-f" (
	CALL :collect FRONTEND_DIRECTORY "%~2" "front-end directory"
	SET /A NWINDOWS+=1
) ELSE IF "%~1" == "-b" (
	CALL :collect BACKEND_FILE "%~2" "back-end file"
	SET /A NWINDOWS+=1
) ELSE IF "%~1" == "-h" (
	GOTO usage
) ELSE IF "%~1" == "-?" (
	GOTO usage
) ELSE IF "%~1" == "/?" (
	GOTO usage
)
IF ERRORLEVEL 1 GOTO done
SHIFT /1
SHIFT /1
GOTO loop
:end

REM For the "hello world" extension, ensure service of the correct directory.
IF EXIST "%FRONTEND_DIRECTORY%\public" SET FRONTEND_DIRECTORY=%FRONTEND_DIRECTORY%\public

REM If necessary, create a panel extension manifest file.
IF "%MANIFEST_FILE%" == "" SET MANIFEST_FILE=..\panel.json
IF EXIST "%MANIFEST_FILE%" (
	ECHO "Using %MANIFEST_FILE%."
) ELSE (
	ECHO "Creating %MANIFEST_FILE%."
	CMD /C yarn create-manifest -t panel -o "%MANIFEST_FILE%"
)

REM Start new command prompts for the different aspects of running the rig.
IF "%FRONTEND_DIRECTORY%" == "" (
	ECHO Front-end hosting was not provided by the developer rig.
) ELSE (
	START "%FRONTEND_DIRECTORY%" CMD /C yarn host -d "%FRONTEND_DIRECTORY%" -p 8080 -l
)
IF "%BACKEND_FILE%" == "" (
	ECHO Back-end hosting was not provided by the developer rig.
) ELSE (
	START "%BACKEND_FILE%" CMD /C node "%BACKEND_FILE%" -l "%MANIFEST_FILE%"
)
START "%MANIFEST_FILE%" CMD /C yarn start -l "%MANIFEST_FILE%"
ECHO Opened %NWINDOWS% other command prompts to run the developer rig.

REM Clean up, report results, and exit.
:done
SET EXIT_CODE=%ERRORLEVEL%
RD /Q /S "%T%"
EXIT /B %EXIT_CODE%

:usage
ECHO usage: %0 [-m manifest-file] [-f front-end-directory] [-b back-end-file]
GOTO done

:collect
IF EXIST "%~2" (
	SET %1=%~2
) ELSE (
	ECHO Cannot open %~3 "%~2".
	"%T%\fail" 2> NUL
)
