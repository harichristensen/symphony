#!/bin/bash

set -e

# Symphony Installer
# Installs Symphony tmux orchestration system

SYMPHONY_VERSION="1.0.0"
SYMPHONY_DIR="$HOME/.symphony"
SYMPHONY_BIN="$SYMPHONY_DIR/bin"
SYMPHONY_LIB="$SYMPHONY_DIR/lib"
SYMPHONY_CONFIG="$SYMPHONY_DIR/config"
SYMPHONY_RUNTIME="$SYMPHONY_DIR/.runtime"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub raw content base URL
REPO_BASE="https://raw.githubusercontent.com/harichristensen/symphony/main"

echo -e "${BLUE}🎼 Symphony Installer v${SYMPHONY_VERSION}${NC}"
echo "Installing Symphony tmux orchestration system..."
echo

# Check dependencies
check_dependencies() {
    echo "Checking dependencies..."
    
    # Check tmux
    if ! command -v tmux &> /dev/null; then
        echo -e "${RED}Error: tmux is required but not installed.${NC}"
        echo "Install tmux first:"
        echo "  macOS: brew install tmux"
        echo "  Ubuntu/Debian: sudo apt-get install tmux"
        echo "  CentOS/RHEL: sudo yum install tmux"
        exit 1
    fi
    
    # Check tmux version (need 3.0+)
    tmux_version=$(tmux -V | cut -d' ' -f2)
    if [[ $(echo "$tmux_version 3.0" | tr ' ' '\n' | sort -V | head -n1) != "3.0" ]]; then
        echo -e "${YELLOW}Warning: tmux version $tmux_version detected. Version 3.0+ recommended.${NC}"
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Error: git is required but not installed.${NC}"
        exit 1
    fi
    
    # Check claude
    if ! command -v claude &> /dev/null; then
        echo -e "${RED}Error: claude CLI is required but not installed.${NC}"
        echo "Install Claude Code first: https://docs.anthropic.com/claude-code"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All dependencies found${NC}"
}

# Create directory structure
create_directories() {
    echo "Creating directory structure..."
    
    mkdir -p "$SYMPHONY_BIN"
    mkdir -p "$SYMPHONY_LIB"
    mkdir -p "$SYMPHONY_CONFIG"
    mkdir -p "$SYMPHONY_RUNTIME/sessions"
    mkdir -p "$SYMPHONY_RUNTIME/worktrees"
    mkdir -p "$SYMPHONY_RUNTIME/state"
    mkdir -p "$SYMPHONY_RUNTIME/logs"
    
    echo -e "${GREEN}✓ Created ~/.symphony directory structure${NC}"
}

# Download file with error handling
download_file() {
    local url="$1"
    local dest="$2"
    local description="$3"
    
    if curl -fsSL "$url" -o "$dest"; then
        echo -e "${GREEN}✓ Downloaded $description${NC}"
    else
        echo -e "${RED}✗ Failed to download $description from $url${NC}"
        exit 1
    fi
}

# Download all Symphony scripts
download_scripts() {
    echo "Downloading Symphony scripts..."
    
    # Main CLI scripts
    download_file "$REPO_BASE/bin/symphony" "$SYMPHONY_BIN/symphony" "main CLI"
    download_file "$REPO_BASE/bin/symphony-orchestrator.sh" "$SYMPHONY_BIN/symphony-orchestrator.sh" "orchestrator"
    download_file "$REPO_BASE/bin/symphony-spawn-agent.sh" "$SYMPHONY_BIN/symphony-spawn-agent.sh" "agent spawner"
    download_file "$REPO_BASE/bin/symphony-monitor.sh" "$SYMPHONY_BIN/symphony-monitor.sh" "monitor"
    download_file "$REPO_BASE/bin/symphony-cleanup.sh" "$SYMPHONY_BIN/symphony-cleanup.sh" "cleanup utility"
    
    # Library scripts
    download_file "$REPO_BASE/lib/tmux-layouts.sh" "$SYMPHONY_LIB/tmux-layouts.sh" "tmux layouts"
    download_file "$REPO_BASE/lib/agent-prompts.sh" "$SYMPHONY_LIB/agent-prompts.sh" "agent prompts"
    download_file "$REPO_BASE/lib/progress-parser.sh" "$SYMPHONY_LIB/progress-parser.sh" "progress parser"
    download_file "$REPO_BASE/lib/git-operations.sh" "$SYMPHONY_LIB/git-operations.sh" "git operations"
    
    # Configuration template
    download_file "$REPO_BASE/config/symphony.config.yml.example" "$SYMPHONY_CONFIG/symphony.config.yml.example" "config template"
    
    # Make scripts executable
    chmod +x "$SYMPHONY_BIN"/*
    chmod +x "$SYMPHONY_LIB"/*
    
    echo -e "${GREEN}✓ All scripts downloaded and made executable${NC}"
}

# Setup PATH
setup_path() {
    echo "Setting up PATH..."
    
    # Detect shell
    shell_profile=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        if [[ -f "$HOME/.bash_profile" ]]; then
            shell_profile="$HOME/.bash_profile"
        else
            shell_profile="$HOME/.bashrc"
        fi
    else
        echo -e "${YELLOW}Warning: Could not detect shell. Add $SYMPHONY_BIN to your PATH manually.${NC}"
        return
    fi
    
    # Check if PATH is already set
    if grep -q "\.symphony/bin" "$shell_profile" 2>/dev/null; then
        echo -e "${GREEN}✓ PATH already configured in $shell_profile${NC}"
        return
    fi
    
    # Add to PATH
    echo "" >> "$shell_profile"
    echo "# Symphony orchestration system" >> "$shell_profile"
    echo "export PATH=\"\$HOME/.symphony/bin:\$PATH\"" >> "$shell_profile"
    
    echo -e "${GREEN}✓ Added Symphony to PATH in $shell_profile${NC}"
    echo -e "${YELLOW}Note: Restart your shell or run 'source $shell_profile' to use Symphony${NC}"
}

# Create initial project config if in a git repo
create_project_config() {
    if [[ -d ".git" ]]; then
        echo "Detected git repository. Creating initial Symphony configuration..."
        
        if [[ ! -f "symphony.config.yml" ]]; then
            cp "$SYMPHONY_CONFIG/symphony.config.yml.example" "symphony.config.yml"
            echo -e "${GREEN}✓ Created symphony.config.yml in current directory${NC}"
            echo -e "${YELLOW}Edit symphony.config.yml to configure agent lanes for your project${NC}"
        else
            echo -e "${GREEN}✓ symphony.config.yml already exists${NC}"
        fi
    fi
}

# Installation complete message
show_completion() {
    echo
    echo -e "${GREEN}🎉 Symphony installation complete!${NC}"
    echo
    echo "Next steps:"
    echo "1. Restart your shell or run: source ~/.zshrc (or ~/.bashrc)"
    echo "2. In a git repository, run: symphony init"
    echo "3. Configure agent lanes in symphony.config.yml"
    echo "4. Start orchestrating: symphony start"
    echo
    echo "Documentation: https://github.com/harichristensen/symphony/blob/main/README.md"
    echo "Issues: https://github.com/harichristensen/symphony/issues"
    echo
}

# Main installation flow
main() {
    check_dependencies
    create_directories
    download_scripts
    setup_path
    create_project_config
    show_completion
}

# Handle interruption
trap 'echo -e "\n${RED}Installation interrupted${NC}"; exit 1' INT

# Run installation
main "$@"