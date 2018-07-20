@ECHO OFF
SETLOCAL

REM https://stackoverflow.com/questions/10175812/how-to-create-a-self-signed-certificate-with-openssl
REM https://stackoverflow.com/questions/2129713

REM Determine if this script needs to run.
powershell -Command "& {Get-ChildItem -Path Cert:\LocalMachine\Root}" | FIND "Twitch Developer Rig CA" > NUL
IF NOT ERRORLEVEL 1 EXIT /B 0

REM Configure path to OpenSSL.
openssl version 2> NUL > NUL
IF ERRORLEVEL 1 PATH %PATH%;%ProgramFiles%\Git\mingw64\bin
openssl version 2> NUL > NUL
IF ERRORLEVEL 1 (
	ECHO Cannot configure path to OpenSSL.
	EXIT /B 1
)

REM Create the temporary directory.
SET D=%~dp0
SET T=%TEMP%\mkc%RANDOM%
MD "%T%"
CD /D %T%

REM Check for elevation.
net file > NUL 2> NUL
IF ERRORLEVEL 1 (
	REM Continue installation in an elevated command prompt.
	ECHO CreateObject^("Shell.Application"^).ShellExecute "cmd.exe", "/c " ^& WScript.Arguments^(0^), "", "runas" > "%T%\elevate.vbs"
	ECHO Certificate creation will continue in an elevated command prompt.
	cscript //nologo "%T%\elevate.vbs" "%~f0 %~1"
	GOTO done
) ELSE IF "%~1" == "" (
	SET PAUSE=PAUSE
) ELSE (
	SET PAUSE=
)

REM Prepare input files.
COPY "%D%*.cnf" > NUL
COPY /B NUL index.txt > NUL
openssl rand -hex 4 > serial.txt
FOR /L %%I IN (1,1,7) DO ECHO.>> enters.txt
FOR /L %%I IN (1,1,2) DO ECHO y>> yes.txt
SET CA=openssl-ca.cnf

REM Create the certificate authority certificate.
openssl req -x509 -days 99999 -config %CA% -newkey rsa:4096 -sha256 -nodes -out cacert.pem -outform PEM < enters.txt
IF ERRORLEVEL 1 (
	ECHO Cannot create the certificate authority certificate.
	GOTO done
)

REM Create the certificate requests for the rig and localhost.
ECHO DNS.1 = localhost.rig.twitch.tv> rig.dns
ECHO DNS.1 = localhost> localhost.dns
FOR %%I IN (rig localhost) DO (
	DEL openssl-server.cnf
	COPY /B "%D%openssl-server.cnf"+%%I.dns openssl-server.cnf > NUL
	openssl req -config openssl-server.cnf -newkey rsa:2048 -sha256 -nodes -out %%Icert.csr -outform PEM < enters.txt
	IF ERRORLEVEL 1 (
		ECHO Cannot create the %%I certificate request.
		GOTO done
	)
	REN serverkey.pem %%Ikey.pem
)

REM Create the server certificates for the rig and localhost.
DEL %CA%
COPY /B "%D%%CA%"+"%D%openssl-ca.add" %CA%
ECHO unique_subject = no> index.txt.attr
FOR %%I IN (rig localhost) DO (
	openssl ca -config %CA% -policy signing_policy -extensions signing_req -out %%Icert.pem -infiles %%Icert.csr < yes.txt
	IF ERRORLEVEL 1 (
		ECHO Cannot create the %%I server certificate.
		GOTO done
	)
)

REM Move all desired files to the rig ssl and extension conf directories.
MOVE /Y cacert.pem "%D%..\ssl\cacert.crt" > NUL
MOVE /Y cakey.pem "%D%..\ssl\cacert.key" > NUL
MOVE /Y rigcert.pem "%D%..\ssl\selfsigned.crt" > NUL
MOVE /Y rigkey.pem "%D%..\ssl\selfsigned.key" > NUL
IF NOT EXIST "%D%..\..\my-extension\conf" MD "%D%..\..\my-extension\conf"
MOVE /Y localhostcert.pem "%D%..\..\my-extension\conf\server.crt" > NUL
MOVE /Y localhostkey.pem  "%D%..\..\my-extension\conf\server.key" > NUL
IF ERRORLEVEL 1 (
	ECHO Cannot place the extension server certificates.
	GOTO done
)

REM Import the CA certificate into the local machine's root certificate store.
ECHO Import-Certificate -Filepath "%D%..\ssl\cacert.crt" -CertStoreLocation Cert:\LocalMachine\Root > import.ps1
powershell -File import.ps1
IF ERRORLEVEL 1 (
	ECHO Cannot import the CA certificate into the local machine's root certificate store.
	GOTO done
)

REM If Firefox is installed, allow it to use the certificates in the local machine's root certificate store.
SET FF=%ProgramFiles%\Mozilla Firefox\defaults\pref
IF EXIST "%FF%" (
	ECHO pref^("security.enterprise_roots.enabled", true^); > "%FF%\twitch-developer-rig.js"
	ECHO NOTE:  you must restart Firefox before running the developer rig.
	SET PAUSE=PAUSE
)

:done
SET EXIT_CODE=%ERRORLEVEL%
CD /D %D%
RD /Q /S "%T%"
%PAUSE%
EXIT /B %EXIT_CODE%
