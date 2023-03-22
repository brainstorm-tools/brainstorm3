@ECHO.
@SET MATLABROOT=
@SET VER_NAME=R2022b
@SET VER_NUMBER=9.13
@SET MCR_FOLDER=v913


@REM ===== SKIP DETECTION =====
@IF DEFINED MATLABROOT (
    @GOTO :TEST_JAVA
)

@REM ===== MATLAB: CHECK DEFAULT FOLDERS =====
@IF EXIST "C:\Program Files\MATLAB\%VER_NAME%\sys\java\jre" (
    @SET "MATLABROOT=C:\Program Files\MATLAB\%VER_NAME%"
    @GOTO :TEST_JAVA
)
@IF EXIST "C:\Program Files (x86)\MATLAB\%VER_NAME%\sys\java\jre" (
    @SET "MATLABROOT=C:\Program Files (x86)\MATLAB\%VER_NAME%"
    @GOTO :TEST_JAVA
)
@REM ===== MCR: CHECK DEFAULT FOLDERS =====
@IF EXIST "C:\Program Files\MATLAB\MATLAB Runtime\%MCR_FOLDER%\sys\java\jre" (
    @SET "MATLABROOT=C:\Program Files\MATLAB\MATLAB Runtime\%MCR_FOLDER%"
    @GOTO :TEST_JAVA
)
@IF EXIST "C:\Program Files (x86)\MATLAB\MATLAB Runtime\%MCR_FOLDER%\sys\java\jre" (
    @SET "MATLABROOT=C:\Program Files (x86)\MATLAB\MATLAB Runtime\%MCR_FOLDER%"
    @GOTO :TEST_JAVA
)
@IF EXIST "C:\Program Files\MATLAB\MATLAB Runtime\%VER_NAME%\sys\java\jre" (
    @SET "MATLABROOT=C:\Program Files\MATLAB\MATLAB Runtime\%VER_NAME%"
    @GOTO :TEST_JAVA
)
@IF EXIST "C:\Program Files (x86)\MATLAB\MATLAB Runtime\%VER_NAME%\sys\java\jre" (
    @SET "MATLABROOT=C:\Program Files (x86)\MATLAB\MATLAB Runtime\%VER_NAME%"
    @GOTO :TEST_JAVA
)

@REM ===== CHECK REGISTRY: MATLAB 64bit =====
@SET MKEY="HKLM\SOFTWARE\MathWorks\MATLAB\%VER_NUMBER%"
@FOR /F "skip=2 tokens=2*" %%A IN ('REG QUERY %MKEY% /v MATLABROOT 2^>NUL') DO @SET MATLABROOT=%%B
@IF DEFINED MATLABROOT (
    @GOTO :TEST_JAVA
)
@REM ===== CHECK REGISTRY: MATLAB 32bit =====
@SET MKEY="HKLM\SOFTWARE\Wow6432Node\MathWorks\MATLAB\%VER_NUMBER%"
@FOR /F "skip=2 tokens=2*" %%A IN ('REG QUERY %MKEY% /v MATLABROOT 2^>NUL') DO @SET MATLABROOT=%%B
@IF DEFINED MATLABROOT (
    @GOTO :TEST_JAVA
)

@REM ===== CHECK REGISTRY: MCR 64bit =====
@SET MKEY="HKLM\SOFTWARE\MathWorks\MATLAB Runtime\%VER_NUMBER%"
@FOR /F "skip=2 tokens=2*" %%A IN ('REG QUERY %MKEY% /v MATLABROOT 2^>NUL') DO @SET MATLABROOT=%%B
@IF DEFINED MATLABROOT (
    @GOTO :TEST_JAVA
)
@REM ===== CHECK REGISTRY: MCR 32bit =====
@SET MKEY="HKLM\SOFTWARE\Wow6432Node\MathWorks\MATLAB Runtime\%VER_NUMBER%"
@FOR /F "skip=2 tokens=2*" %%A IN ('REG QUERY %MKEY% /v MATLABROOT 2^>NUL') DO @SET MATLABROOT=%%B
@IF DEFINED MATLABROOT (
    @GOTO :TEST_JAVA
)

@REM ===== MATLAB NOT FOUND =====
@ECHO.
@ECHO ERROR: Matlab %VER_NAME% does not seem to be installed on your computer.
@ECHO    1) Go to the Brainstorm website
@ECHO    2) Download the Matlab Runtime (%VER_NAME%).
@ECHO.
@pause
@GOTO :END

@REM ===== DETECT JAVA =====
:TEST_JAVA
@ECHO Matlab %VER_NAME% found:
@ECHO %MATLABROOT%
@IF EXIST "%MATLABROOT%\sys\java\jre\win64" (
    @SET JAVA_EXE="%MATLABROOT%\sys\java\jre\win64\jre\bin\java.exe"
    GOTO :RUN_JAVA
)
@IF EXIST "%MATLABROOT%\sys\java\jre\win32" (
    @SET JAVA_EXE="%MATLABROOT%\sys\java\jre\win32\jre\bin\java.exe"
    GOTO :RUN_JAVA
)

@REM ===== JAVA NOT FOUND =====
@ECHO.
@ECHO ERROR: java.exe was not found in "%MATLABROOT%\sys\java\jre\<arch>\jre\bin"
@ECHO.
@pause
@GOTO :END

@REM ===== START BRAINSTORM =====
:RUN_JAVA
@SET PATH=%PATH%;%MATLABROOT%\runtime\win64;%MATLABROOT%\runtime\win32
@ECHO.
@ECHO Please wait...
@ECHO.
@ECHO If it hangs for more than a few minutes: try pressing ENTER.
@ECHO Alternatively, download Brainstorm for a different version of the Matlab Runtime.
@ECHO (See the installation instructions on the Brainstorm website)
@ECHO.
@%JAVA_EXE% -jar brainstorm3.jar %*

:END