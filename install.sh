#!/bin/bash

# Universal Installer Script
# Replace these variables with your actual values
TOOL_NAME="provia"
GITHUB_USER="teamfynbit"
GITHUB_REPO="provia"
VERSION="latest"  # or specific version like "v1.0.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macos"
            ARCH=$(uname -m)
            if [[ "$ARCH" == "arm64" ]]; then
                PLATFORM="macos-arm64"
            else
                PLATFORM="macos-x64"
            fi
            ;;
        Linux*)
            OS="linux"
            ARCH=$(uname -m)
            case "$ARCH" in
                x86_64|amd64)
                    PLATFORM="linux-x64"
                    ;;
                aarch64|arm64)
                    PLATFORM="linux-arm64"
                    ;;
                *)
                    PLATFORM="linux-x64"
                    print_warning "Unknown architecture $ARCH, defaulting to x64"
                    ;;
            esac
            ;;
        CYGWIN*|MINGW*|MSYS*)
            OS="windows"
            PLATFORM="windows-x64"
            ;;
        *)
            print_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install dependencies
install_dependencies() {
    print_status "Checking and installing dependencies..."
    
    case "$OS" in
        "macos")
            # Check for Homebrew
            if ! command_exists brew; then
                print_status "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            
            # Install required tools
            if ! command_exists curl; then
                print_status "Installing curl..."
                brew install curl
            fi
            
            if ! command_exists unzip; then
                print_status "Installing unzip..."
                brew install unzip
            fi
            ;;
            
        "linux")
            # Detect package manager
            if command_exists apt-get; then
                PKG_MANAGER="apt-get"
                UPDATE_CMD="sudo apt-get update"
                INSTALL_CMD="sudo apt-get install -y"
            elif command_exists yum; then
                PKG_MANAGER="yum"
                UPDATE_CMD="sudo yum check-update"
                INSTALL_CMD="sudo yum install -y"
            elif command_exists dnf; then
                PKG_MANAGER="dnf"
                UPDATE_CMD="sudo dnf check-update"
                INSTALL_CMD="sudo dnf install -y"
            elif command_exists pacman; then
                PKG_MANAGER="pacman"
                UPDATE_CMD="sudo pacman -Sy"
                INSTALL_CMD="sudo pacman -S --noconfirm"
            else
                print_warning "No supported package manager found. Please install curl and unzip manually."
                return
            fi
            
            # Update package lists
            print_status "Updating package lists..."
            $UPDATE_CMD >/dev/null 2>&1 || true
            
            # Install dependencies
            if ! command_exists curl; then
                print_status "Installing curl..."
                $INSTALL_CMD curl
            fi
            
            if ! command_exists unzip; then
                print_status "Installing unzip..."
                $INSTALL_CMD unzip
            fi
            ;;
            
        "windows")
            # For Windows, we assume curl is available (Windows 10+)
            if ! command_exists curl; then
                print_error "curl is not available. Please install curl or use Windows 10+ with built-in curl."
                exit 1
            fi
            ;;
    esac
}

# Function to get download URL
get_download_url() {
    if [[ "$VERSION" == "latest" ]]; then
        # Get latest release
        RELEASE_URL="https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/releases/latest"
        print_status "Fetching latest release information..."
        
        # Extract download URL for the platform
        DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep -o "https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/[^\"]*${PLATFORM}[^\"]*\.zip" | head -1)
        
        if [[ -z "$DOWNLOAD_URL" ]]; then
            print_error "Could not find download URL for platform: $PLATFORM"
            print_error "Available assets:"
            curl -s "$RELEASE_URL" | grep -o "https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/[^\"]*\.zip"
            exit 1
        fi
    else
        # Use specific version
        DOWNLOAD_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/${VERSION}/${TOOL_NAME}-${PLATFORM}.zip"
    fi
}

# Function to download and extract binary
download_and_extract() {
    print_status "Downloading $TOOL_NAME for $PLATFORM..."
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Download the zip file
    if ! curl -L -o "${TOOL_NAME}.zip" "$DOWNLOAD_URL"; then
        print_error "Failed to download $TOOL_NAME"
        cleanup_and_exit 1
    fi
    
    print_status "Extracting $TOOL_NAME..."
    
    # Extract the zip file
    if ! unzip -q "${TOOL_NAME}.zip"; then
        print_error "Failed to extract $TOOL_NAME"
        cleanup_and_exit 1
    fi
    
    # Find the binary
    if [[ "$OS" == "windows" ]]; then
        BINARY_NAME="${TOOL_NAME}.exe"
    else
        BINARY_NAME="$TOOL_NAME"
    fi
    
    # Look for the binary in current directory or subdirectories
    BINARY_PATH=$(find . -name "$BINARY_NAME" -type f | head -1)
    
    if [[ -z "$BINARY_PATH" ]]; then
        print_error "Could not find binary $BINARY_NAME in the extracted files"
        print_error "Available files:"
        find . -type f
        cleanup_and_exit 1
    fi
    
    print_success "Binary found at: $BINARY_PATH"
}

# Function to install binary
install_binary() {
    print_status "Installing $TOOL_NAME..."
    
    case "$OS" in
        "macos"|"linux")
            # Determine install location
            if [[ -w "/usr/local/bin" ]]; then
                INSTALL_DIR="/usr/local/bin"
            elif [[ -w "$HOME/.local/bin" ]]; then
                INSTALL_DIR="$HOME/.local/bin"
                mkdir -p "$INSTALL_DIR"
            else
                INSTALL_DIR="$HOME/bin"
                mkdir -p "$INSTALL_DIR"
            fi
            
            # Copy binary
            cp "$BINARY_PATH" "$INSTALL_DIR/$TOOL_NAME"
            chmod +x "$INSTALL_DIR/$TOOL_NAME"
            
            # Handle macOS Gatekeeper
            if [[ "$OS" == "macos" ]]; then
                print_status "Handling macOS Gatekeeper..."
                
                # Remove quarantine attribute
                xattr -d com.apple.quarantine "$INSTALL_DIR/$TOOL_NAME" 2>/dev/null || true
                
                # Try to run the binary to trigger Gatekeeper
                print_status "Attempting to verify binary with Gatekeeper..."
                if "$INSTALL_DIR/$TOOL_NAME" --version >/dev/null 2>&1 || "$INSTALL_DIR/$TOOL_NAME" --help >/dev/null 2>&1; then
                    print_success "Binary verified successfully"
                else
                    print_warning "Gatekeeper verification failed. You may need to:"
                    print_warning "1. Go to System Preferences > Security & Privacy"
                    print_warning "2. Click 'Allow Anyway' for $TOOL_NAME"
                    print_warning "3. Or run: sudo spctl --add '$INSTALL_DIR/$TOOL_NAME'"
                fi
            fi
            
            # Add to PATH if necessary
            if [[ "$INSTALL_DIR" == "$HOME/bin" ]] || [[ "$INSTALL_DIR" == "$HOME/.local/bin" ]]; then
                add_to_path "$INSTALL_DIR"
            fi
            ;;
            
        "windows")
            # For Windows, install to a directory in PATH or add to PATH
            INSTALL_DIR="$HOME/bin"
            mkdir -p "$INSTALL_DIR"
            
            cp "$BINARY_PATH" "$INSTALL_DIR/${TOOL_NAME}.exe"
            
            # Add to PATH (this affects current session only)
            export PATH="$INSTALL_DIR:$PATH"
            
            print_warning "Note: You may need to add $INSTALL_DIR to your system PATH permanently"
            print_warning "Or restart your terminal for the changes to take effect"
            ;;
    esac
    
    print_success "$TOOL_NAME installed to: $INSTALL_DIR"
}

# Function to add directory to PATH
add_to_path() {
    local dir="$1"
    local shell_rc=""
    
    # Determine shell configuration file
    if [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bashrc"
        [[ -f "$HOME/.bash_profile" ]] && shell_rc="$HOME/.bash_profile"
    elif [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.profile"
    fi
    
    # Check if directory is already in PATH
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        print_status "Adding $dir to PATH in $shell_rc"
        echo "export PATH=\"$dir:\$PATH\"" >> "$shell_rc"
        export PATH="$dir:$PATH"
        print_warning "Please restart your terminal or run: source $shell_rc"
    fi
}

# Function to verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    if command_exists "$TOOL_NAME"; then
        print_success "$TOOL_NAME is now available in your PATH"
        
        # Try to get version
        if "$TOOL_NAME" --version 2>/dev/null; then
            print_success "Installation completed successfully!"
        elif "$TOOL_NAME" --help 2>/dev/null; then
            print_success "Installation completed successfully!"
        else
            print_success "Installation completed (binary is accessible but version/help not available)"
        fi
    else
        print_error "Installation failed: $TOOL_NAME is not in PATH"
        print_error "You may need to restart your terminal or check the installation directory"
        return 1
    fi
}

# Function to cleanup temporary files
cleanup_and_exit() {
    local exit_code=${1:-0}
    if [[ -n "$TMP_DIR" ]] && [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
    exit $exit_code
}

# Function to display help
show_help() {
    echo "Universal Installer for $TOOL_NAME"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -v, --version   Specify version to install (default: latest)"
    echo "  -f, --force     Force reinstallation"
    echo ""
    echo "Examples:"
    echo "  $0                    # Install latest version"
    echo "  $0 -v v1.2.3         # Install specific version"
    echo "  $0 --force           # Force reinstall"
}

# Main installation function
main() {
    local force_install=false
    local specified_version=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                specified_version="$2"
                shift 2
                ;;
            -f|--force)
                force_install=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Use specified version if provided
    if [[ -n "$specified_version" ]]; then
        VERSION="$specified_version"
    fi
    
    print_status "Starting $TOOL_NAME installation..."
    
    # Check if already installed
    if command_exists "$TOOL_NAME" && [[ "$force_install" != true ]]; then
        print_warning "$TOOL_NAME is already installed. Use --force to reinstall."
        print_status "Current version:"
        "$TOOL_NAME" --version 2>/dev/null || echo "Version information not available"
        exit 0
    fi
    
    # Detect OS and architecture
    detect_os
    print_status "Detected platform: $PLATFORM"
    
    # Install dependencies
    install_dependencies
    
    # Get download URL
    get_download_url
    print_status "Download URL: $DOWNLOAD_URL"
    
    # Download and extract
    download_and_extract
    
    # Install binary
    install_binary
    
    # Verify installation
    verify_installation
    
    # Cleanup
    cleanup_and_exit 0
}

# Set trap for cleanup on exit
trap cleanup_and_exit EXIT

# Run main function
main "$@"