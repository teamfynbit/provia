# Universal Windows Installer Script
$TOOL_NAME = "provia"
$GITHUB_USER = "teamfynbit"
$GITHUB_REPO = "provia"
$VERSION = "latest"
$PLATFORM = "windows-x64"

# Color definitions using ANSI escape codes
$RED = "`e[91m"
$GREEN = "`e[92m"
$YELLOW = "`e[93m"
$BLUE = "`e[94m"
$RESET = "`e[0m"

# Function to write colored output
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "",
        [string]$Type = "INFO"
    )
    
    $ColorCode = switch ($Color) {
        "RED" { $RED }
        "GREEN" { $GREEN }
        "YELLOW" { $YELLOW }
        "BLUE" { $BLUE }
        default { "" }
    }
    
    Write-Host "${ColorCode}[$Type]$RESET $Message"
}

function Show-Help {
    Write-Host "Universal Windows Installer for $TOOL_NAME"
    Write-Host ""
    Write-Host "Usage: iwr -useb https://raw.githubusercontent.com/teamfynbit/provia/main/install.ps1 | iex"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  `$env:PROVIA_VERSION     Specify version to install (default: latest)"
    Write-Host "  `$env:PROVIA_FORCE       Set to 'true' to force reinstallation"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  # Install latest version"
    Write-Host "  iwr -useb https://raw.githubusercontent.com/teamfynbit/provia/main/install.ps1 | iex"
    Write-Host ""
    Write-Host "  # Install specific version"
    Write-Host "  `$env:PROVIA_VERSION='v1.2.3'; iwr -useb https://raw.githubusercontent.com/teamfynbit/provia/main/install.ps1 | iex"
    Write-Host ""
    Write-Host "  # Force reinstall"
    Write-Host "  `$env:PROVIA_FORCE='true'; iwr -useb https://raw.githubusercontent.com/teamfynbit/provia/main/install.ps1 | iex"
    Write-Host ""
}

function Test-ExistingInstall {
    param([bool]$ForceInstall)
    
    if (-not $ForceInstall) {
        # Check install directory
        $InstallDir = "$env:USERPROFILE\bin"
        if (Test-Path "$InstallDir\$TOOL_NAME.exe") {
            Write-ColoredOutput "$TOOL_NAME is already installed at $InstallDir\$TOOL_NAME.exe" "YELLOW" "WARNING"
            Write-ColoredOutput "Set `$env:PROVIA_FORCE='true' to reinstall." "YELLOW" "WARNING"
            return $true
        }
        
        # Check if in PATH
        $Command = Get-Command $TOOL_NAME -ErrorAction SilentlyContinue
        if ($Command) {
            Write-ColoredOutput "$TOOL_NAME is already available in your PATH" "YELLOW" "WARNING"
            Write-ColoredOutput "Set `$env:PROVIA_FORCE='true' to reinstall." "YELLOW" "WARNING"
            Write-ColoredOutput "Current version:" "BLUE" "INFO"
            try {
                & $TOOL_NAME --version 2>$null
            } catch {
                Write-Host "Version information not available"
            }
            return $true
        }
    }
    
    return $false
}

function Get-DownloadUrl {
    param([string]$TargetVersion)
    
    if ($TargetVersion -eq "latest") {
        Write-ColoredOutput "Fetching latest release information..." "BLUE" "INFO"
        
        $ReleaseUrl = "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
        
        try {
            # Set TLS 1.2 for older PowerShell versions
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            $Response = Invoke-RestMethod -Uri $ReleaseUrl -UseBasicParsing
            
            $Asset = $Response.assets | Where-Object { 
                $_.name -match $PLATFORM -and $_.name -match '\.zip' 
            } | Select-Object -First 1
            
            if (-not $Asset) {
                Write-ColoredOutput "No release found for platform: $PLATFORM" "RED" "ERROR"
                return $null
            }
            
            return $Asset.browser_download_url
        }
        catch {
            Write-ColoredOutput "Failed to fetch release information" "RED" "ERROR"
            return $null
        }
    }
    else {
        return "https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/download/$TargetVersion/$TOOL_NAME-$PLATFORM.zip"
    }
}

function Invoke-DownloadAndInstall {
    param([string]$DownloadUrl)
    
    $TempDir = Join-Path $env:TEMP "$TOOL_NAME`_install_$(Get-Random)"
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    
    try {
        $ZipFile = Join-Path $TempDir "$TOOL_NAME.zip"
        
        Write-ColoredOutput "Downloading $TOOL_NAME..." "BLUE" "INFO"
        
        # Download
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipFile -UseBasicParsing
        }
        catch {
            Write-ColoredOutput "Failed to download $TOOL_NAME" "RED" "ERROR"
            return $false
        }
        
        if (-not (Test-Path $ZipFile)) {
            Write-ColoredOutput "Downloaded file not found" "RED" "ERROR"
            return $false
        }
        
        Write-ColoredOutput "Extracting files..." "BLUE" "INFO"
        
        # Extract
        $ExtractDir = Join-Path $TempDir "extracted"
        try {
            Expand-Archive -Path $ZipFile -DestinationPath $ExtractDir -Force
        }
        catch {
            Write-ColoredOutput "Failed to extract files" "RED" "ERROR"
            return $false
        }
        
        # Find binary
        $FoundBinary = $null
        
        # Look for .exe first
        $ExeFiles = Get-ChildItem -Path $ExtractDir -Name "$TOOL_NAME.exe" -Recurse -ErrorAction SilentlyContinue
        if ($ExeFiles) {
            $FoundBinary = $ExeFiles[0].FullName
        } else {
            # Try without .exe extension
            $Files = Get-ChildItem -Path $ExtractDir -Name $TOOL_NAME -Recurse -ErrorAction SilentlyContinue
            if ($Files) {
                $FoundBinary = $Files[0].FullName
            }
        }
        
        if (-not $FoundBinary -or -not (Test-Path $FoundBinary)) {
            Write-ColoredOutput "Could not find $TOOL_NAME binary in extracted files" "RED" "ERROR"
            Write-ColoredOutput "Available files:" "RED" "ERROR"
            Get-ChildItem -Path $ExtractDir -Recurse | ForEach-Object { Write-Host $_.FullName }
            return $false
        }
        
        Write-ColoredOutput "Binary found: $FoundBinary" "GREEN" "SUCCESS"
        
        # Install
        $InstallDir = "$env:USERPROFILE\bin"
        if (-not (Test-Path $InstallDir)) {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        }
        
        $TargetPath = Join-Path $InstallDir "$TOOL_NAME.exe"
        try {
            Copy-Item -Path $FoundBinary -Destination $TargetPath -Force
        }
        catch {
            Write-ColoredOutput "Failed to copy binary to install directory" "RED" "ERROR"
            return $false
        }
        
        Write-ColoredOutput "$TOOL_NAME installed to: $TargetPath" "GREEN" "SUCCESS"
        
        # Add to PATH
        Add-ToPath $InstallDir
        
        # Verify
        Test-Installation
        
        return $true
    }
    finally {
        # Cleanup
        if (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Add-ToPath {
    param([string]$NewPath)
    
    # Check if already in PATH
    $CurrentPath = $env:PATH
    if ($CurrentPath -like "*$NewPath*") {
        Write-ColoredOutput "Directory already in PATH" "BLUE" "INFO"
        return
    }
    
    Write-ColoredOutput "Adding $NewPath to PATH..." "BLUE" "INFO"
    
    # Get current user PATH from registry
    try {
        $UserPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
        
        if ([string]::IsNullOrEmpty($UserPath)) {
            $NewUserPath = $NewPath
        } else {
            $NewUserPath = "$UserPath;$NewPath"
        }
        
        # Set user PATH
        [Environment]::SetEnvironmentVariable("PATH", $NewUserPath, [EnvironmentVariableTarget]::User)
        
        # Update current session
        $env:PATH = "$env:PATH;$NewPath"
        
        Write-ColoredOutput "Please restart your PowerShell session for PATH changes to take effect" "YELLOW" "WARNING"
    }
    catch {
        Write-ColoredOutput "Failed to update PATH" "RED" "ERROR"
    }
}

function Test-Installation {
    Write-ColoredOutput "Verifying installation..." "BLUE" "INFO"
    
    # Check if binary exists
    $InstallDir = "$env:USERPROFILE\bin"
    $BinaryPath = Join-Path $InstallDir "$TOOL_NAME.exe"
    
    if (-not (Test-Path $BinaryPath)) {
        Write-ColoredOutput "Binary not found in install directory" "RED" "ERROR"
        return $false
    }
    
    Write-ColoredOutput "Binary verified in install directory" "GREEN" "SUCCESS"
    
    # Try to find it in PATH
    $Command = Get-Command $TOOL_NAME -ErrorAction SilentlyContinue
    if ($Command) {
        Write-ColoredOutput "$TOOL_NAME is available in PATH" "GREEN" "SUCCESS"
    } else {
        Write-ColoredOutput "$TOOL_NAME not immediately available in PATH" "YELLOW" "WARNING"
    }
    
    return $true
}

# Parse environment variables for options
$TargetVersion = if ($env:PROVIA_VERSION) { $env:PROVIA_VERSION } else { $VERSION }
$ForceInstall = $env:PROVIA_FORCE -eq "true"

# Check for help request
if ($env:PROVIA_HELP -eq "true" -or $args -contains "--help" -or $args -contains "-h") {
    Show-Help
    return
}

Write-ColoredOutput "Starting $TOOL_NAME installation..." "BLUE" "INFO"

# Check if already installed
if (Test-ExistingInstall -ForceInstall $ForceInstall) {
    if (-not $ForceInstall) {
        return
    }
}

Write-ColoredOutput "Detected platform: $PLATFORM" "BLUE" "INFO"

# Get download URL
$DownloadUrl = Get-DownloadUrl -TargetVersion $TargetVersion
if (-not $DownloadUrl) {
    throw "Failed to get download URL"
}

Write-ColoredOutput "Download URL: $DownloadUrl" "BLUE" "INFO"

# Download and install
$InstallResult = Invoke-DownloadAndInstall -DownloadUrl $DownloadUrl

if ($InstallResult) {
    Write-ColoredOutput "Installation completed successfully!" "GREEN" "SUCCESS"
    Write-Host ""
    Write-ColoredOutput "You can now use '$TOOL_NAME' from any PowerShell session" "BLUE" "INFO"
    Write-ColoredOutput "If the command is not found, please restart your PowerShell session" "YELLOW" "WARNING"
} else {
    throw "Installation failed"
}