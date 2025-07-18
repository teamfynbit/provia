# One-Liner Installation Commands

## Universal (Linux/macOS)
```bash
curl -fsSL https://raw.githubusercontent.com/teamfynbit/provia/main/install.sh | bash
```

## Windows (PowerShell)
```powershell
iwr -useb https://raw.githubusercontent.com/teamfynbit/provia/main/install.bat | iex
```

## Windows (Command Prompt)
```cmd
curl -fsSL https://raw.githubusercontent.com/teamfynbit/provia/main/install.bat -o %temp%\install.bat && %temp%\install.bat
```

## Advanced Usage Examples

### Install specific version
```bash
# Linux/macOS
curl -fsSL https://raw.githubusercontent.com/teamfynbit/provia/main/install.sh | bash -s -- -v v1.2.3

# Windows PowerShell
iwr -useb https://raw.githubusercontent.com/teamfynbit/provia/main/install.bat | iex; & $env:temp\install.bat /v v1.2.3
```

### Force reinstallation
```bash
# Linux/macOS
curl -fsSL https://raw.githubusercontent.com/teamfynbit/provia/main/install.sh | bash -s -- --force

# Windows
curl -fsSL https://raw.githubusercontent.com/teamfynbit/provia/main/install.bat -o %temp%\install.bat && %temp%\install.bat /force
```
