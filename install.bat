@echo off
setlocal enabledelayedexpansion

:: Universal Windows Installer Script
set "TOOL_NAME=provia"
set "GITHUB_USER=teamfynbit"
set "GITHUB_REPO=provia"
set "VERSION=latest"
set "PLATFORM=windows-x64"

:: Enable ANSI colors (Windows 10 1909+)
for /f "tokens=4-5 delims=. " %%i in ('ver') do set "VERSION_NUM=%%i.%%j"
if %VERSION_NUM% geq 10.0 (
    reg add "HKCU\Console" /v "VirtualTerminalLevel" /t REG_DWORD /d 1 /f >nul 2>&1
)

:: Create ESC character for ANSI codes
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

:: Color definitions
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "BLUE=%ESC%[94m"
set "RESET=%ESC%[0m"

:: If colors don't work, fall back to plain text
if not defined ESC (
    set "RED="
    set "GREEN="
    set "YELLOW="
    set "BLUE="
    set "RESET="
)

:: Main execution
call :main %*
exit /b %errorlevel%

:main
    set "force_install=false"
    set "specified_version="
    
    :: Parse arguments
    :parse_args
    if "%~1"=="" goto :args_done
    if /i "%~1"=="/h" goto :show_help
    if /i "%~1"=="/help" goto :show_help
    if /i "%~1"=="/v" (
        set "specified_version=%~2"
        shift
        shift
        goto :parse_args
    )
    if /i "%~1"=="/f" (
        set "force_install=true"
        shift
        goto :parse_args
    )
    if /i "%~1"=="/force" (
        set "force_install=true"
        shift
        goto :parse_args
    )
    echo %RED%[ERROR]%RESET% Unknown option: %~1
    call :show_help
    exit /b 1
    
    :args_done
    
    :: Use specified version if provided
    if not "%specified_version%"=="" set "VERSION=%specified_version%"
    
    echo %BLUE%[INFO]%RESET% Starting %TOOL_NAME% installation...
    
    :: Check if already installed
    if "%force_install%"=="false" (
        call :check_existing_install
        if !errorlevel! equ 0 exit /b 0
    )
    
    echo %BLUE%[INFO]%RESET% Detected platform: %PLATFORM%
    
    :: Get download URL
    call :get_download_url
    if !errorlevel! neq 0 exit /b 1
    
    echo %BLUE%[INFO]%RESET% Download URL: !DOWNLOAD_URL!
    
    :: Create temp directory
    set "temp_dir=%temp%\%TOOL_NAME%_install_%random%"
    mkdir "!temp_dir!" >nul 2>&1
    
    :: Download and install
    call :download_and_install "!temp_dir!"
    set "install_result=!errorlevel!"
    
    :: Cleanup
    if exist "!temp_dir!" rmdir /s /q "!temp_dir!" >nul 2>&1
    
    if !install_result! equ 0 (
        echo %GREEN%[SUCCESS]%RESET% Installation completed successfully!
        echo.
        echo %BLUE%[INFO]%RESET% You can now use '%TOOL_NAME%' from any command prompt
        echo %YELLOW%[WARNING]%RESET% If the command is not found, please restart your command prompt
    ) else (
        echo %RED%[ERROR]%RESET% Installation failed
        exit /b 1
    )
    
    exit /b 0

:check_existing_install
    :: Check install directory
    set "install_dir=%USERPROFILE%\bin"
    if exist "%install_dir%\%TOOL_NAME%.exe" (
        echo %YELLOW%[WARNING]%RESET% %TOOL_NAME% is already installed at %install_dir%\%TOOL_NAME%.exe
        echo %YELLOW%[WARNING]%RESET% Use /force to reinstall.
        exit /b 0
    )
    
    :: Check if in PATH
    where "%TOOL_NAME%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo %YELLOW%[WARNING]%RESET% %TOOL_NAME% is already available in your PATH
        echo %YELLOW%[WARNING]%RESET% Use /force to reinstall.
        echo %BLUE%[INFO]%RESET% Current version:
        %TOOL_NAME% --version 2>nul || echo Version information not available
        exit /b 0
    )
    
    exit /b 1

:get_download_url
    if "%VERSION%"=="latest" (
        echo %BLUE%[INFO]%RESET% Fetching latest release information...
        
        set "temp_json=%temp%\release_info_%random%.json"
        set "release_url=https://api.github.com/repos/%GITHUB_USER%/%GITHUB_REPO%/releases/latest"
        echo release_url
        
        :: Try curl first
        where curl >nul 2>&1
        if !errorlevel! equ 0 (
            curl -s -L -o "!temp_json!" "!release_url!" 2>nul
        ) else (
            :: Use PowerShell
            powershell -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '!release_url!' -OutFile '!temp_json!' -UseBasicParsing } catch { exit 1 }" >nul 2>&1
        )
        
        if !errorlevel! neq 0 (
            echo %RED%[ERROR]%RESET% Failed to fetch release information
            exit /b 1
        )
        
        :: Parse JSON with PowerShell
        for /f "delims=" %%i in ('powershell -Command "try { $json = Get-Content '!temp_json!' | ConvertFrom-Json; $asset = $json.assets | Where-Object { $_.name -match '%PLATFORM%' -and $_.name -match '\.zip' } | Select-Object -First 1; if ($asset) { $asset.browser_download_url } else { 'NOT_FOUND' } } catch { 'ERROR' }" 2^>nul') do set "DOWNLOAD_URL=%%i"
        
        del "!temp_json!" >nul 2>&1
        
        if "!DOWNLOAD_URL!"=="NOT_FOUND" (
            echo %RED%[ERROR]%RESET% No release found for platform: %PLATFORM%
            exit /b 1
        )
        
        if "!DOWNLOAD_URL!"=="ERROR" (
            echo %RED%[ERROR]%RESET% Failed to parse release information
            exit /b 1
        )
        
        if "!DOWNLOAD_URL!"=="" (
            echo %RED%[ERROR]%RESET% Could not determine download URL
            exit /b 1
        )
    ) else (
        set "DOWNLOAD_URL=https://github.com/%GITHUB_USER%/%GITHUB_REPO%/releases/download/%VERSION%/%TOOL_NAME%-%PLATFORM%.zip"
    )
    exit /b 0

:download_and_install
    set "temp_dir=%~1"
    set "zip_file=%temp_dir%\%TOOL_NAME%.zip"
    
    echo %BLUE%[INFO]%RESET% Downloading %TOOL_NAME%...
    
    :: Download
    where curl >nul 2>&1
    if !errorlevel! equ 0 (
        curl -L -o "%zip_file%" "%DOWNLOAD_URL%" 2>nul
    ) else (
        powershell -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%zip_file%' -UseBasicParsing } catch { exit 1 }" >nul 2>&1
    )
    
    if !errorlevel! neq 0 (
        echo %RED%[ERROR]%RESET% Failed to download %TOOL_NAME%
        exit /b 1
    )
    
    if not exist "%zip_file%" (
        echo %RED%[ERROR]%RESET% Downloaded file not found
        exit /b 1
    )
    
    echo %BLUE%[INFO]%RESET% Extracting files...
    
    :: Extract
    set "extract_dir=%temp_dir%\extracted"
    powershell -Command "try { Expand-Archive -Path '%zip_file%' -DestinationPath '%extract_dir%' -Force } catch { exit 1 }" >nul 2>&1
    
    if !errorlevel! neq 0 (
        echo %RED%[ERROR]%RESET% Failed to extract files
        exit /b 1
    )
    
    :: Find binary
    set "found_binary="
    for /r "%extract_dir%" %%f in (%TOOL_NAME%.exe) do (
        if exist "%%f" (
            set "found_binary=%%f"
            goto :found_binary
        )
    )
    
    :: Try without .exe extension
    for /r "%extract_dir%" %%f in (%TOOL_NAME%) do (
        if exist "%%f" (
            set "found_binary=%%f"
            goto :found_binary
        )
    )
    
    :found_binary
    if "!found_binary!"=="" (
        echo %RED%[ERROR]%RESET% Could not find %TOOL_NAME% binary in extracted files
        echo %RED%[ERROR]%RESET% Available files:
        dir /s /b "%extract_dir%" 2>nul
        exit /b 1
    )
    
    echo %GREEN%[SUCCESS]%RESET% Binary found: !found_binary!
    
    :: Install
    set "install_dir=%USERPROFILE%\bin"
    if not exist "%install_dir%" mkdir "%install_dir%" >nul 2>&1
    
    copy "!found_binary!" "%install_dir%\%TOOL_NAME%.exe" >nul 2>&1
    if !errorlevel! neq 0 (
        echo %RED%[ERROR]%RESET% Failed to copy binary to install directory
        exit /b 1
    )
    
    echo %GREEN%[SUCCESS]%RESET% %TOOL_NAME% installed to: %install_dir%\%TOOL_NAME%.exe
    
    :: Add to PATH
    call :add_to_path "%install_dir%"
    
    :: Verify
    call :verify_install
    
    exit /b 0

:add_to_path
    set "new_path=%~1"
    
    :: Check if already in PATH
    echo %PATH% | findstr /i /c:"%new_path%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo %BLUE%[INFO]%RESET% Directory already in PATH
        exit /b 0
    )
    
    echo %BLUE%[INFO]%RESET% Adding %new_path% to PATH...
    
    :: Get current user PATH
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "current_path=%%b"
    
    :: Add to PATH
    if "!current_path!"=="" (
        setx PATH "%new_path%" >nul 2>&1
    ) else (
        setx PATH "!current_path!;%new_path%" >nul 2>&1
    )
    
    :: Update current session
    set "PATH=%PATH%;%new_path%"
    
    echo %YELLOW%[WARNING]%RESET% Please restart your command prompt for PATH changes to take effect
    exit /b 0

:verify_install
    echo %BLUE%[INFO]%RESET% Verifying installation...
    
    :: Check if binary exists
    set "install_dir=%USERPROFILE%\bin"
    if not exist "%install_dir%\%TOOL_NAME%.exe" (
        echo %RED%[ERROR]%RESET% Binary not found in install directory
        exit /b 1
    )
    
    echo %GREEN%[SUCCESS]%RESET% Binary verified in install directory
    
    :: Try to run it
    where "%TOOL_NAME%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo %GREEN%[SUCCESS]%RESET% %TOOL_NAME% is available in PATH
    ) else (
        echo %YELLOW%[WARNING]%RESET% %TOOL_NAME% not immediately available in PATH
    )
    
    exit /b 0

:show_help
    echo Universal Windows Installer for %TOOL_NAME%
    echo.
    echo Usage: %~nx0 [OPTIONS]
    echo.
    echo Options:
    echo   /h, /help       Show this help message
    echo   /v VERSION      Specify version to install (default: latest)
    echo   /f, /force      Force reinstallation
    echo.
    echo Examples:
    echo   %~nx0                    # Install latest version
    echo   %~nx0 /v v1.2.3         # Install specific version
    echo   %~nx0 /force            # Force reinstall
    echo.
    exit /b 0  
