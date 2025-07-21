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
if [[ "$PLATFORM" == "mac" ]]; then
  # macOS-specific paths
  export PATH=/opt/homebrew/opt/python@3.13/libexec/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$(go env GOPATH)/bin:$PATH
  export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
  
  # macOS package manager paths
  if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
  fi
elif [[ "$PLATFORM" == "linux" ]]; then
  # Linux-specific paths
  export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$(go env GOPATH 2>/dev/null || echo "$HOME/go")/bin:$PATH
  
  # Common Java paths on Ubuntu
  if [[ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]]; then
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
  elif [[ -d "/usr/lib/jvm/temurin-21-jdk-amd64" ]]; then
    export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
  fi
  
  # Linux package manager paths
  if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
    export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
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

# Update settings
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 1

# History settings
HIST_STAMPS="yyyy-mm-dd"

# Platform-specific plugins
if [[ "$PLATFORM" == "mac" ]]; then
  plugins=(
    git
    z
    fzf-z
    zsh-autosuggestions
    web-search
    zsh-syntax-highlighting
    you-should-use
    zsh-bat
    macos
  )
elif [[ "$PLATFORM" == "linux" ]]; then
  plugins=(
    git
    z
    fzf-z
    zsh-autosuggestions
    web-search
    zsh-syntax-highlighting
    you-should-use
    zsh-bat
    ubuntu
  )
fi

source $ZSH/oh-my-zsh.sh

# =============================================================================
# EXTERNAL TOOLS INITIALIZATION
# =============================================================================
# P10K theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# SDKMAN (works on both platforms)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Modern CLI tools (check if they exist first)
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v thefuck >/dev/null 2>&1 && eval $(thefuck --alias)
command -v gh >/dev/null 2>&1 && eval "$(gh copilot alias -- zsh)"

# Angular CLI autocompletion (if available)
command -v ng >/dev/null 2>&1 && source <(ng completion script)

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
alias staging='aws --profile default --region=us-east-1 eks update-kubeconfig --name=solidus-staging --role-arn arn:aws:iam::348980842327:role/eksReader'
alias prod='aws --profile prod --region=us-east-1 eks update-kubeconfig --name=solidus-prod2-us-east-1 --role-arn arn:aws:iam::685404473957:role/eksReader'
alias fidelity='aws --profile prod --region=us-east-2 eks update-kubeconfig --name=solidus-fidelity --role-arn arn:aws:iam::685404473957:role/eksReader'
alias prod-asia='aws --profile prod --region=ap-southeast-1 eks update-kubeconfig --name=solidus-prod-ap-southeast-1 --role-arn arn:aws:iam::685404473957:role/eksReader'
alias uat-eu='aws --profile default --region=eu-central-1 eks update-kubeconfig --name=solidus-uat2-eu-central-1 --role-arn arn:aws:iam::348980842327:role/eksReader'
alias rnd='aws --profile default --region=us-east-1 eks update-kubeconfig --name=solidus-rnd --role-arn arn:aws:iam::348980842327:role/eksReader'
alias prod-eu='aws --profile prod --region=eu-central-1 eks update-kubeconfig --name=solidus-prod-eu-central-1 --role-arn arn:aws:iam::685404473957:role/eksReader'

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
  cd ~/workspace/ng-solidus-tardis && ng serve -c=local --port=4200
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
# Show platform info on startup (optional)
if [[ "$PLATFORM" != "unknown" ]]; then
  echo "💻 Platform: $PLATFORM"
fi
