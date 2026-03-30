
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
. "$HOME/.cargo/env"
export VCPKG_ROOT=/Users/danielmarchukov/vcpkg

# Rich-on-Paper Trading Engine aliases
alias trading-start='cd $(pwd) && ./run_trading_system_macos.sh'
alias trading-test='cd $(pwd) && source env/bin/activate && pytest data-ingestion/src/ && cd build && ctest'
alias trading-build='cd $(pwd) && cmake --build build'

# Created by `pipx` on 2026-03-25 14:53:24
export PATH="$PATH:/home/dmarciukovas/.local/bin"
