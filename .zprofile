# Homebrew (macOS only)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval ""
elif [[ -f "/usr/local/bin/brew" ]]; then
    eval ""
fi

# JetBrains Toolbox (macOS only)
if [[ -d "/home/danmarchukov/Library/Application Support/JetBrains/Toolbox/scripts" ]]; then
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/lib/wsl/lib:/mnt/c/Users/d0453/bin:/mnt/c/Program Files/Git/mingw64/bin:/mnt/c/Program Files/Git/usr/local/bin:/mnt/c/Program Files/Git/usr/bin:/mnt/c/Program Files/Git/usr/bin:/mnt/c/Program Files/Git/mingw64/bin:/mnt/c/Program Files/Git/usr/bin:/mnt/c/Users/d0453/bin:/mnt/c/Program Files/Alacritty:/mnt/c/Program Files/Common Files/Oracle/Java/javapath:/mnt/c/Program Files/Zulu/zulu-21/bin:/mnt/c/WINDOWS/system32:/mnt/c/WINDOWS:/mnt/c/WINDOWS/System32/Wbem:/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0:/mnt/c/WINDOWS/System32/OpenSSH:/mnt/c/WINDOWS/AtlasModules:/mnt/c/WINDOWS/AtlasModules/Tools:/mnt/c/WINDOWS/AtlasModules/Scripts:/mnt/c/Program Files/GitHub CLI:/mnt/c/ProgramData/chocolatey/bin:/mnt/c/Program Files/Git/cmd:/mnt/c/Program Files/CMake/bin:/mnt/c/Program Files/LLVM/bin:/mnt/c/Program Files (x86)/LLVM/bin:/mnt/c/Program Files/NVIDIA Corporation/NVIDIA App/NvDLISR:/mnt/c/Program Files (x86)/NVIDIA Corporation/PhysX/Common:/mnt/c/Program Files/Go/bin:/mnt/c/Program Files/dotnet:/mnt/c/Program Files/Warp/bin:/mnt/c/Users/d0453/AppData/Local/Programs/Python/Python314/Scripts:/mnt/c/Users/d0453/AppData/Local/Programs/Python/Python314:/mnt/c/Users/d0453/AppData/Local/Programs/Python/Python313/Scripts:/mnt/c/Users/d0453/AppData/Local/Programs/Python/Python313:/mnt/c/Users/d0453/.cargo/bin:/mnt/c/Users/d0453/AppData/Local/Microsoft/WindowsApps:/mnt/c/Program Files/JetBrains/CLion 2025.1.3/bin:/mnt/c/Program Files/OpenCppCoverage:/mnt/c/Users/d0453/AppData/Local/Programs/Microsoft VS Code/bin:/mnt/c/Users/d0453/go/bin:/mnt/c/Users/d0453/.local/bin:/mnt/c/Program Files/Git/usr/bin/vendor_perl:/mnt/c/Program Files/Git/usr/bin/core_perl:/home/danmarchukov/Library/Application Support/JetBrains/Toolbox/scripts"
fi

# Linuxbrew (Linux only)
if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval ""
fi
