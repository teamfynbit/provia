@echo off
setlocal enabledelayedexpansion

:: Universal Windows Installer Script
:: Replace these variables with your actual values
set TOOL_NAME=provia
set GITHUB_USER=teamfynbit
set GITHUB_REPO=provia
set VERSION=latest
set PLATFORM=windows-x64

:: Enable ANSI color support (Windows 10+)
for /f "tokens=2 delims=[]" %%a in ('ver') do set "winver=%%a"
echo !winver! | findstr /r "10\." >nul && (
    :: Try to enable ANSI colors
    reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
)

:: Color codes
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

:: Function to print colored output
goto :main

:print_status
echo %BLUE%[INFO]%NC% %~1
goto :eof

:print_success
echo %GREEN%[SUCCESS]%NC% %~1
goto :eof

:print_warning
echo %YELLOW%[WARNING]%NC% %~1
goto :eof

:print_error
echo %RED%[ERROR]%NC% %~1
goto :eof

:: Function to check if command exists
:command_exists
where "%~1" >nul 2>&1
if %errorlevel% equ 0 (
    set "command_found=true"
) else (
    set "command_found=false"
)
goto :eof

:: Function to create directory if it doesn't exist
:ensure_dir
if not exist "%~1" mkdir "%~1"
goto :eof

:: Function to download file using curl or PowerShell
:download_file
set "url=%~1"
set "output=%~2"

call :print_status "Downloading from: !url!"

:: Validate URL
if "!url!"=="" (
    call :print_error "Download URL is empty"
    exit /b 1
)

:: Try curl first (available in Windows 10+)
call :command_exists curl
if "!command_found!"=="true" (
    curl -L -o "!output!" "!url!"
    if !errorlevel! equ 0 goto :eof
)

:: Fallback to PowerShell
call :print_status "Using PowerShell for download..."
powershell -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%url%' -OutFile '%output%' -UseBasicParsing } catch { Write-Host $_.Exception.Message; exit 1 }"
goto :eof

:: Function to extract zip file
:extract_zip
set "zipfile=%~1"
set "destination=%~2"

call :print_status "Extracting %zipfile% to %destination%..."

:: Use PowerShell to extract
powershell -Command "try { Expand-Archive -Path '%zipfile%' -DestinationPath '%destination%' -Force } catch { Write-Host $_.Exception.Message; exit 1 }"
goto :eof

:: Function to get download URL
:get_download_url
if "%VERSION%"=="latest" (
    call :print_status "Fetching latest release information..."
    
    :: Create temp file for JSON response
    set "temp_json=%temp%\release_info_%random%.json"
    set "release_url=https://api.github.com/repos/%GITHUB_USER%/%GITHUB_REPO%/releases/latest"
    
    call :download_file "!release_url!" "!temp_json!"
    if !errorlevel! neq 0 (
        call :print_error "Failed to fetch release information"
        exit /b 1
    )
    
    :: Extract download URL using PowerShell with better error handling
    set "ps_script=%temp%\extract_url_%random%.ps1"
    echo try { > "!ps_script!"
    echo   $json = Get-Content '%temp_json%' ^| ConvertFrom-Json >> "!ps_script!"
    echo   $asset = $json.assets ^| Where-Object { $_.name -match '%PLATFORM%' -and $_.name -match '.zip' } ^| Select-Object -First 1 >> "!ps_script!"
    echo   if ($asset) { >> "!ps_script!"
    echo     Write-Output $asset.browser_download_url >> "!ps_script!"
    echo   } else { >> "!ps_script!"
    echo     Write-Error "No matching asset found" >> "!ps_script!"
    echo     exit 1 >> "!ps_script!"
    echo   } >> "!ps_script!"
    echo } catch { >> "!ps_script!"
    echo   Write-Error $_.Exception.Message >> "!ps_script!"
    echo   exit 1 >> "!ps_script!"
    echo } >> "!ps_script!"
    
    for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "!ps_script!" 2^>nul') do set "DOWNLOAD_URL=%%i"
    
    :: Cleanup temp files
    del "!temp_json!" >nul 2>&1
    del "!ps_script!" >nul 2>&1
    
    if "!DOWNLOAD_URL!"=="" (
        call :print_error "Could not find download URL for platform: %PLATFORM%"
        call :print_error "Please check if releases are available for your platform"
        exit /b 1
    )
) else (
    set "DOWNLOAD_URL=https://github.com/%GITHUB_USER%/%GITHUB_REPO%/releases/download/%VERSION%/%TOOL_NAME%-%PLATFORM%.zip"
)
goto :eof

:: Function to find binary in extracted files
:find_binary
set "search_dir=%~1"
set "binary_name=%~2"
set "found_binary="

for /r "%search_dir%" %%f in ("%binary_name%") do (
    if exist "%%f" (
        set "found_binary=%%f"
        goto :found_binary_done
    )
)

:: Also try without .exe extension
set "binary_name_no_ext=%TOOL_NAME%"
for /r "%search_dir%" %%f in ("%binary_name_no_ext%") do (
    if exist "%%f" (
        set "found_binary=%%f"
        goto :found_binary_done
    )
)

:found_binary_done
set "%~3=!found_binary!"
goto :eof

:: Function to add directory to PATH
:add_to_path
set "new_path=%~1"

:: Check if directory is already in PATH
echo %PATH% | findstr /i /c:"%new_path%" >nul
if %errorlevel% equ 0 (
    call :print_status "Directory already in PATH"
    goto :eof
)

:: Add to user PATH permanently
call :print_status "Adding %new_path% to user PATH..."
for /f "skip=2 tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "current_path=%%b"
if "!current_path!"=="" (
    setx PATH "%new_path%" >nul
) else (
    setx PATH "!current_path!;%new_path%" >nul
)

:: Add to current session PATH
set "PATH=%PATH%;%new_path%"
call :print_warning "Please restart your command prompt for PATH changes to take effect"
goto :eof

:: Function to verify installation
:verify_installation
call :print_status "Verifying installation..."

:: Check if binary exists in install directory
set "install_dir=%USERPROFILE%\bin"
if exist "!install_dir!\%TOOL_NAME%.exe" (
    call :print_success "%TOOL_NAME%.exe found in install directory"
) else (
    call :print_error "Binary not found in install directory"
    exit /b 1
)

:: Check if command is available in PATH
call :command_exists "%TOOL_NAME%"
if "!command_found!"=="true" (
    call :print_success "%TOOL_NAME% is now available in your PATH"
    
    :: Try to get version or help
    %TOOL_NAME% --version >nul 2>&1
    if !errorlevel! equ 0 (
        call :print_success "Installation completed successfully!"
    ) else (
        %TOOL_NAME% --help >nul 2>&1
        if !errorlevel! equ 0 (
            call :print_success "Installation completed successfully!"
        ) else (
            call :print_success "Installation completed (binary is accessible)"
        )
    )
) else (
    call :print_warning "Installation completed but %TOOL_NAME% is not immediately available"
    call :print_warning "Please restart your command prompt for PATH changes to take effect"
)
goto :eof

:: Function to show help
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
goto :eof

:: Main function
:main
set "force_install=false"
set "specified_version="

:: Parse command line arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="/h" goto :show_help_and_exit
if /i "%~1"=="/help" goto :show_help_and_exit
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
call :print_error "Unknown option: %~1"
call :show_help
exit /b 1

:show_help_and_exit
call :show_help
exit /b 0

:args_done

:: Use specified version if provided
if not "%specified_version%"=="" set "VERSION=%specified_version%"

call :print_status "Starting %TOOL_NAME% installation..."

:: Check if already installed (more thorough check)
if "%force_install%"=="false" (
    set "install_dir=%USERPROFILE%\bin"
    if exist "!install_dir!\%TOOL_NAME%.exe" (
        call :print_warning "%TOOL_NAME% is already installed at !install_dir!\%TOOL_NAME%.exe"
        call :print_warning "Use /force to reinstall."
        
        :: Try to show version
        call :command_exists "%TOOL_NAME%"
        if "!command_found!"=="true" (
            call :print_status "Current installation:"
            %TOOL_NAME% --version 2>nul || %TOOL_NAME% --help 2>nul || echo Binary is accessible
        ) else (
            call :print_warning "Binary exists but not in PATH. Consider using /force to reinstall."
        )
        exit /b 0
    )
    
    :: Also check if it's in PATH but installed elsewhere
    call :command_exists "%TOOL_NAME%"
    if "!command_found!"=="true" (
        call :print_warning "%TOOL_NAME% is already available in your PATH"
        call :print_warning "Use /force to reinstall."
        call :print_status "Current version:"
        %TOOL_NAME% --version 2>nul || %TOOL_NAME% --help 2>nul || echo Version information not available
        exit /b 0
    )
)

call :print_status "Detected platform: %PLATFORM%"

:: Get download URL
call :get_download_url
if !errorlevel! neq 0 exit /b 1

call :print_status "Download URL: !DOWNLOAD_URL!"

:: Create temporary directory
set "temp_dir=%temp%\%TOOL_NAME%_install_%random%"
call :ensure_dir "!temp_dir!"

:: Download the zip file
set "zip_file=!temp_dir!\%TOOL_NAME%.zip"
call :download_file "!DOWNLOAD_URL!" "!zip_file!"
if !errorlevel! neq 0 (
    call :print_error "Failed to download %TOOL_NAME%"
    rmdir /s /q "!temp_dir!" >nul 2>&1
    exit /b 1
)

:: Verify download
if not exist "!zip_file!" (
    call :print_error "Downloaded file not found"
    rmdir /s /q "!temp_dir!" >nul 2>&1
    exit /b 1
)

:: Extract the zip file
set "extract_dir=!temp_dir!\extracted"
call :extract_zip "!zip_file!" "!extract_dir!"
if !errorlevel! neq 0 (
    call :print_error "Failed to extract %TOOL_NAME%"
    rmdir /s /q "!temp_dir!" >nul 2>&1
    exit /b 1
)

:: Find the binary
set "binary_name=%TOOL_NAME%.exe"
call :find_binary "!extract_dir!" "!binary_name!" found_binary_path

if "!found_binary_path!"=="" (
    call :print_error "Could not find binary %binary_name% in the extracted files"
    call :print_error "Available files:"
    dir /s /b "!extract_dir!" 2>nul
    rmdir /s /q "!temp_dir!" >nul 2>&1
    exit /b 1
)

call :print_success "Binary found at: !found_binary_path!"

:: Install binary
call :print_status "Installing %TOOL_NAME%..."

:: Determine install location
set "install_dir=%USERPROFILE%\bin"
call :ensure_dir "!install_dir!"

:: Copy binary
copy "!found_binary_path!" "!install_dir!\%TOOL_NAME%.exe" >nul
if !errorlevel! neq 0 (
    call :print_error "Failed to copy binary to install directory"
    rmdir /s /q "!temp_dir!" >nul 2>&1
    exit /b 1
)

call :print_success "%TOOL_NAME% installed to: !install_dir!\%TOOL_NAME%.exe"

:: Add to PATH
call :add_to_path "!install_dir!"

:: Verify installation
call :verify_installation

:: Cleanup
rmdir /s /q "!temp_dir!" >nul 2>&1

call :print_success "Installation completed successfully!"
echo.
call :print_status "You can now use '%TOOL_NAME%' from any command prompt"
call :print_warning "If the command is not found, please restart your command prompt"

exit /b 0