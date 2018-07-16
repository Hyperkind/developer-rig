@ECHO OFF
SETLOCAL

REM https://stackoverflow.com/questions/10175812/how-to-create-a-self-signed-certificate-with-openssl
REM https://stackoverflow.com/questions/2129713

REM Configure path to OpenSSL.
openssl version 2> NUL > NUL
IF ERRORLEVEL 1 PATH %PATH%;%ProgramFiles%\Git\mingw64\bin
openssl version 2> NUL > NUL
IF ERRORLEVEL 1 (
	ECHO Cannot configure path to OpenSSL.
	EXIT /B 1
)

REM Configure the temporary directory.
SET D=%~dp0
SET T=%TEMP%\%RANDOM%
MD "%T%"
CD /D %T%

REM Check for elevation.
net file > NUL 2> NUL
IF ERRORLEVEL 1 (
	ECHO CreateObject ^( "Shell.Application" ^).ShellExecute "cmd.exe", "/c " ^& WScript.Arguments ^( 0 ^), "", "runas" > "%T%\elevate.vbs"
	ECHO Certificate creation will continue in an elevated command prompt.
	cscript //nologo "%T%\elevate.vbs" "%~f0"
	GOTO done
) ELSE (
	SET PAUSE=PAUSE
)

REM Prepare input files.
COPY "%D%*.cnf" > NUL
COPY /B NUL index.txt > NUL
ECHO 01> serial.txt
FOR /L %%I IN (1,1,7) DO ECHO.>> enters.txt
FOR /L %%I IN (1,1,2) DO ECHO y>> yes.txt
SET CA=openssl-ca.cnf

REM Create the certificate authority certificate.
openssl req -x509 -days 99999 -config %CA% -newkey rsa:4096 -sha256 -nodes -out cacert.pem -outform PEM < enters.txt
IF ERRORLEVEL 1 (
	ECHO Cannot create the certificate authority certificate.
	GOTO done
)

REM Create the certificate request.
openssl req -config openssl-server.cnf -newkey rsa:2048 -sha256 -nodes -out servercert.csr -outform PEM < enters.txt
IF ERRORLEVEL 1 (
	ECHO Cannot create the certificate request.
	GOTO done
)

REM Create the server certificate.
DEL %CA%
COPY /B "%D%%CA%"+"%D%openssl-ca.add" %CA%
ECHO unique_subject = no> index.txt.attr
openssl ca -config %CA% -policy signing_policy -extensions signing_req -out servercert.pem -infiles servercert.csr < yes.txt
IF ERRORLEVEL 1 (
	ECHO Cannot create the server certificate.
	GOTO done
)
MOVE /Y cacert.pem "%D%..\ssl\cacert.crt" > NUL
MOVE /Y cakey.pem "%D%..\ssl\cacert.key" > NUL
MOVE /Y servercert.pem "%D%..\ssl\selfsigned.crt" > NUL
MOVE /Y serverkey.pem "%D%..\ssl\selfsigned.key" > NUL
ECHO Import-Certificate -Filepath "%D%..\ssl\cacert.crt" -CertStoreLocation Cert:\LocalMachine\Root > import.ps1
powershell -File import.ps1

:done
SET EXIT_CODE=%ERRORLEVEL%
CD /D %D%
RD /Q /S "%T%"
%PAUSE%
EXIT /B %EXIT_CODE%
