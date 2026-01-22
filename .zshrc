#!/usr/bin/env zsh

# =============================================================================
# PLATFORM DETECTION
# =============================================================================
case "$(uname -s)" in
  Darwin*)
    export PLATFORM="mac"
    ;;
  Linux*)
    export PLATFORM="linux"
    ;;
  *)
    export PLATFORM="unknown"
    ;;
esac

# =============================================================================
# P10K INSTANT PROMPT
# =============================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# =============================================================================
# PLATFORM-SPECIFIC PATHS AND ENVIRONMENT
# =============================================================================
# Set GOPATH without expensive go env call (use default location)
export GOPATH="${GOPATH:-$HOME/go}"

if [[ "$PLATFORM" == "mac" ]]; then
  # macOS-specific paths
  export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
  export PATH=/opt/homebrew/opt/python@3.13/libexec/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$GOPATH/bin:$JAVA_HOME/bin:$PATH

  # macOS package manager paths
  if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
  fi

  # Rustup (takes precedence over Homebrew rust)
  if [[ -d "$HOME/.cargo/bin" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
elif [[ "$PLATFORM" == "linux" ]]; then
  # Linux-specific paths
  export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$GOPATH/bin:$PATH

  # Common Java paths on Ubuntu
  if [[ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]]; then
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
  elif [[ -d "/usr/lib/jvm/temurin-21-jdk-amd64" ]]; then
    export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
  fi

  # Add Java bin to PATH if JAVA_HOME is set
  [[ -n "$JAVA_HOME" ]] && export PATH="$JAVA_HOME/bin:$PATH"

  # Linux package manager paths
  if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
    export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
  fi

  # Rustup (takes precedence over system rust)
  if [[ -d "$HOME/.cargo/bin" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
fi

# =============================================================================
# COMMON ENVIRONMENT VARIABLES
# =============================================================================
export ZSH="$HOME/.oh-my-zsh"
export LANG=en_US.UTF-8
export GITLAB_USER=danielius.m

# Editor preferences
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# =============================================================================
# OH-MY-ZSH CONFIGURATION
# =============================================================================
ZSH_THEME="powerlevel10k/powerlevel10k"

# Performance optimizations (based on profiling research)
DISABLE_AUTO_UPDATE="true"           # Disable auto-update checks (55.73% → ~20% improvement)
DISABLE_MAGIC_FUNCTIONS="true"       # Disable magic functions for better paste performance
DISABLE_UPDATE_PROMPT="true"         # Don't prompt for updates
DISABLE_COMPFIX="true"               # Skip permission checks on completion files
zstyle ':omz:update' mode disabled   # Disable auto-update (use `omz update` manually)
ZSH_COMPDUMP="$HOME/.cache/.zcompdump-$ZSH_VERSION"  # Move completion dump to cache
DISABLE_UNTRACKED_FILES_DIRTY="true" # Faster git status in large repos

# History settings
HIST_STAMPS="yyyy-mm-dd"

# Platform-specific plugins
# Note: zsh-syntax-highlighting MUST be last for proper functionality
if [[ "$PLATFORM" == "mac" ]]; then
  plugins=(
    git
    z
    fzf-z
    zsh-autosuggestions
    web-search
    you-should-use
    zsh-bat
    macos
    zsh-syntax-highlighting
  )
elif [[ "$PLATFORM" == "linux" ]]; then
  plugins=(
    git
    z
    fzf-z
    zsh-autosuggestions
    web-search
    you-should-use
    zsh-bat
    ubuntu
    zsh-syntax-highlighting
  )
fi

# Smart completion initialization (30.76% → ~10% improvement)
# Only rebuild completion cache once per day instead of every shell startup
# Must be done BEFORE sourcing oh-my-zsh
autoload -Uz compinit
if [[ -n ${ZSH_COMPDUMP}(#qNmh+24) ]]; then
  # Completion dump is older than 24 hours, regenerate it
  compinit
else
  # Use cached completion dump (much faster)
  compinit -C
fi

source $ZSH/oh-my-zsh.sh

# =============================================================================
# EXTERNAL TOOLS INITIALIZATION
# =============================================================================
# P10K theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# SDKMAN - Lazy load to improve startup time
export SDKMAN_DIR="$HOME/.sdkman"
if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
  # Add SDKMAN candidates to PATH without loading the full init script
  export PATH="$SDKMAN_DIR/candidates/*/current/bin:$PATH"

  # Lazy load sdkman
  sdk() {
    unset -f sdk
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    sdk "$@"
  }
fi

# Modern CLI tools - Lazy load to improve startup time
# Note: zoxide is integrated via oh-my-zsh z plugin, no separate init needed

# thefuck - lazy load wrapper
if command -v thefuck >/dev/null 2>&1; then
  fuck() {
    TF_PYTHONIOENCODING=$PYTHONIOENCODING
    export TF_SHELL=zsh
    export TF_ALIAS=fuck
    export TF_SHELL_ALIASES=$(alias)
    export TF_HISTORY=$(fc -ln -10)
    export PYTHONIOENCODING=utf-8
    TF_CMD=$(thefuck THEFUCK_ARGUMENT_PLACEHOLDER $@) && eval $TF_CMD
    unset TF_HISTORY
    export PYTHONIOENCODING=$TF_PYTHONIOENCODING
    test -n "$TF_CMD" && print -s $TF_CMD
  }
fi

# gh copilot - lazy load wrapper
if command -v gh >/dev/null 2>&1; then
  ghcs() {
    eval "$(gh copilot suggest -t shell "$*")"
  }
  ghce() {
    eval "$(gh copilot explain "$*")"
  }
fi

# Angular CLI autocompletion - lazy load on first ng usage
if command -v ng >/dev/null 2>&1; then
  ng() {
    unfunction ng
    eval "$(command ng completion script)"
    ng "$@"
  }
fi

# FZF - fuzzy finder with keybindings and completion
if command -v fzf >/dev/null 2>&1; then
  # Set up fzf key bindings and fuzzy completion
  if [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
  else
    # Homebrew FZF installation
    [[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]] && source /opt/homebrew/opt/fzf/shell/completion.zsh
    [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]] && source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
  fi

  # FZF configuration for better UI
  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --inline-info"

  # Use fd instead of find if available
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
fi

# Load secrets if available
if [[ -f "$HOME/.secrets" ]]; then
  chmod +x "$HOME/.secrets"
  source "$HOME/.secrets"
fi

# =============================================================================
# CUSTOM SEARCH ENGINES
# =============================================================================
ZSH_WEB_SEARCH_ENGINES=(glab "https://gitlab.com/search?group_id=14299196&scope=blobs&search=")

# =============================================================================
# PLATFORM-SPECIFIC ALIASES
# =============================================================================
if [[ "$PLATFORM" == "mac" ]]; then
  # macOS-specific aliases
  alias aerospace-config="vim ~/.aerospace.toml"
elif [[ "$PLATFORM" == "linux" ]]; then
  # Linux-specific aliases
  alias i3-config="vim ~/.config/i3/config"
  alias sway-config="vim ~/.config/sway/config"
fi

# =============================================================================
# COMMON ALIASES
# =============================================================================
# Configuration files
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias tmxf="vim ~/.config/tmux/tmux.conf"

# Source configs
alias stmx="tmux source-file ~/.config/tmux/tmux.conf"
alias szsh="source ~/.zshrc"

# Neovim variants
alias cvim="NVIM_APPNAME=NvChad nvim"
alias kvim="NVIM_APPNAME=KickstartNvim nvim"

# Kubernetes environments (AWS CLI should work on both platforms)

# =============================================================================
# SOLIDUS DEVELOPMENT FUNCTIONS
# =============================================================================
# Environment variables for Solidus services
solidusenv() {
  export OTEL_TRACES_EXPORTER=jaeger
  export AWS_JAVA_V1_DISABLE_DEPRECATION_ANNOUNCEMENT=true
  export AWS_DEFAULT_OUTPUT=json
  export AWS_DEFAULT_REGION=us-east-2
  export AWS_PROFILE=default
  export KAFKA_BOOTSTRAPSERVERS=localhost:29092
}

# Individual service runners
run-auth() {
  solidusenv
  cd ~/workspace/solidus-auth-service && mvn spring-boot:run
}

run-confm() {
  solidusenv
  cd ~/workspace/solidus-configuration-manager && mvn spring-boot:run
}

run-data() {
  solidusenv
  cd ~/workspace/solidus-data-api && mvn spring-boot:run
}

run-opsadmin() {
  cd ~/workspace/solidus-operations-admin && mvn spring-boot:run
}

run-streamexec() {
  solidusenv
  cd ~/workspace/solidus-streaming-executor && mvn spring-boot:run
}

run-currency() {
  solidusenv
  cd ~/workspace/solidus-currency-converter && mvn spring-boot:run
}

run-schema() {
  solidusenv
  cd ~/workspace/solidus-schema-normalizer && mvn spring-boot:run
}

run-pipeline() {
  solidusenv
  cd ~/workspace/solidus-pipeline-enricher && mvn spring-boot:run
}

run-rest() {
  solidusenv
  cd ~/workspace/solidus-rest && mvn spring-boot:run
}

run-clientstore() {
  solidusenv
  cd ~/workspace/solidus-client-store && mvn spring-boot:run
}

run-ucm() {
  cd ~/workspace/solidus-ucm-aggregation && mvn spring-boot:run
}

run-tardis() {
  cd ~/workspace/ng-solidus-tardis && npm run start-max-local
}

run-csportal() {
  cd ~/workspace/ng-solidus-cs-portal && ng serve -c=local --port=4201
}

# Enhanced local development runner with proper signal handling
runlocal() {
  local services=(auth confm data streamexec)
  local pids=()

  # Function to cleanup all background processes
  cleanup() {
    echo "\n🛑 Shutting down all services..."
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        echo "Stopping process $pid"
        kill -TERM "$pid" 2>/dev/null
      fi
    done

    # Wait a bit for graceful shutdown
    sleep 3

    # Force kill any remaining processes
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        echo "Force stopping process $pid"
        kill -KILL "$pid" 2>/dev/null
      fi
    done

    echo "✅ All services stopped"
    exit 0
  }

  # Set up signal trap
  trap cleanup INT TERM

  echo "🚀 Starting Solidus services..."

  # Start each service in background
  for service in "${services[@]}"; do
    echo "Starting $service..."
    run-$service &
    pids+=($!)
    sleep 2  # Brief delay between starts
  done

  echo "✅ All services started. PIDs: ${pids[*]}"
  echo "Press Ctrl+C to stop all services"

  # Wait for all background processes
  wait
}

# Alternative tmux-based runner for separate panes
runlocal-tmux() {
  local session_name="solidus-dev"

  # Check if tmux is available
  if ! command -v tmux >/dev/null 2>&1; then
    echo "❌ tmux not found. Please install tmux first."
    return 1
  fi

  # Kill existing session if it exists
  tmux kill-session -t "$session_name" 2>/dev/null

  # Create new tmux session
  tmux new-session -d -s "$session_name" -n 'auth'

  # Start auth service in first window
  tmux send-keys -t "$session_name:auth" 'run-auth' Enter

  # Create windows for other services
  tmux new-window -t "$session_name" -n 'confm'
  tmux send-keys -t "$session_name:confm" 'run-confm' Enter

  tmux new-window -t "$session_name" -n 'data'
  tmux send-keys -t "$session_name:data" 'run-data' Enter

  tmux new-window -t "$session_name" -n 'streamexec'
  tmux send-keys -t "$session_name:streamexec" 'run-streamexec' Enter

  # Attach to session
  echo "🚀 Starting Solidus services in tmux session '$session_name'"
  echo "Use 'tmux kill-session -t $session_name' to stop all services"
  tmux attach-session -t "$session_name"
}

# =============================================================================
# PLATFORM INFORMATION
# =============================================================================
# Platform detection is complete - no output on startup for faster loading

# =============================================================================
# ADDITIONAL TOOLS
# =============================================================================
export PATH=~/.groundcover/bin:$PATH

# =============================================================================
# NVM LAZY LOADING (Performance optimization)
# =============================================================================
# This dramatically improves shell startup time by deferring NVM initialization
# until it's actually needed. NVM will auto-load when you use node, npm, nvm, etc.
export NVM_DIR="$HOME/.nvm"

# Add node to PATH using cached default version (avoids slow ls command)
if [[ -s "$NVM_DIR/alias/default" ]]; then
  # Use the default alias to find the version quickly (add 'v' prefix if missing)
  local DEFAULT_VERSION=$(cat $NVM_DIR/alias/default)
  [[ $DEFAULT_VERSION != v* ]] && DEFAULT_VERSION="v$DEFAULT_VERSION"
  export PATH="$NVM_DIR/versions/node/$DEFAULT_VERSION/bin:$PATH"
elif [[ -d "$NVM_DIR/versions/node" ]]; then
  # Fallback: add the first version found (using glob instead of ls)
  local node_versions=($NVM_DIR/versions/node/*)
  if [[ ${#node_versions[@]} -gt 0 ]]; then
    export PATH="${node_versions[-1]}/bin:$PATH"
  fi
fi

# Lazy load nvm (node/npm/npx are already in PATH, so only nvm needs lazy loading)
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm "$@"
}

# =============================================================================
# KUBERNETES ENVIRONMENT ALIASES
# =============================================================================








# =============================================================================
# PERFORMANCE HELPERS
# =============================================================================
# Compile zsh config and plugins for faster loading
zsh-compile() {
  echo "Compiling .zshrc..."
  zcompile ~/.zshrc

  echo "Compiling oh-my-zsh files..."
  for file in ~/.oh-my-zsh/**/*.zsh; do
    [[ -f "$file" && ! -f "${file}.zwc" || "$file" -nt "${file}.zwc" ]] && zcompile "$file"
  done

  echo "Compiling custom plugins..."
  for file in ~/.oh-my-zsh/custom/**/*.zsh; do
    [[ -f "$file" && ! -f "${file}.zwc" || "$file" -nt "${file}.zwc" ]] && zcompile "$file"
  done

  echo "✅ Compilation complete! Restart your shell for best performance."
}

# Auto-compile .zshrc if it's been modified since last compile
# Note: Disabled auto-compile as it adds 250-500ms to startup. Run `zsh-compile` manually when needed.
# if [[ ! -f ~/.zshrc.zwc || ~/.zshrc -nt ~/.zshrc.zwc ]]; then
#   zcompile ~/.zshrc &!
# fi


alias devops='aws --profile default --region=us-east-1 eks update-kubeconfig --name=devops-eks  --role-arn arn:aws:iam::348980842327:role/eksAdmin'
alias esma='aws --profile esmacicd --region=eu-central-1 eks update-kubeconfig --name=solidus-esma --role-arn arn:aws:iam::696791035699:role/eksAdmin && pushd ~/dev/source && git pull && cd helm && curl --header "PRIVATE-TOKEN: $PTK" "https://gitlab.com/api/v4/projects/31892187/repository/files/helm%2Fvalues%2Eyaml/raw?ref=esma" > values.yaml && popd'
alias schwab='aws eks update-kubeconfig --region us-east-1 --profile schwab --name=solidus-schwab --role-arn=arn:aws:iam::630609837183:role/eksAdmin && pushd ~/dev/source && git pull && cd helm && curl --header "PRIVATE-TOKEN: $PTK" "https://gitlab.com/api/v4/projects/31892187/repository/files/helm%2Fvalues%2Eyaml/raw?ref=schwab" > values.yaml && popd'

alias staging='aws --profile default --region=us-east-1 eks update-kubeconfig --name=solidus-staging --role-arn arn:aws:iam::348980842327:role/eksMaintainer'
alias prod='aws --profile prod --region=us-east-1 eks update-kubeconfig --name=solidus-prod2-us-east-1 --role-arn arn:aws:iam::685404473957:role/eksMaintainer'
alias fidelity='aws --profile prod --region=us-east-2 eks update-kubeconfig --name=solidus-fidelity  --role-arn arn:aws:iam::685404473957:role/eksMaintainer'
alias uat-eu='aws --profile default --region=eu-central-1 eks update-kubeconfig --name=solidus-uat2-eu-central-1 --role-arn arn:aws:iam::348980842327:role/eksMaintainer'
alias rnd='aws --profile default --region=us-east-1 eks update-kubeconfig --name=solidus-rnd --role-arn arn:aws:iam::348980842327:role/eksMaintainer'
alias prod-eu='aws --profile prod --region=eu-central-1 eks update-kubeconfig --name=solidus-prod-eu-central-1 --role-arn arn:aws:iam::685404473957:role/eksMaintainer'
alias prod-asia='aws --profile prod --region=ap-southeast-1 eks update-kubeconfig --name=solidus-prod-ap-southeast-1 --role-arn arn:aws:iam::685404473957:role/eksMaintainer'

