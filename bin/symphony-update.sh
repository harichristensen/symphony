#!/bin/bash

# Symphony Update Script
# Updates Symphony installation while preserving configuration and state

set -e

SYMPHONY_VERSION="1.0.0"
SYMPHONY_DIR="$HOME/.symphony"
SYMPHONY_BIN="$SYMPHONY_DIR/bin"
SYMPHONY_LIB="$SYMPHONY_DIR/lib"
SYMPHONY_CONFIG="$SYMPHONY_DIR/config"
SYMPHONY_BACKUP="$SYMPHONY_DIR/.backup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# GitHub raw content base URL
REPO_BASE="https://raw.githubusercontent.com/harichristensen/symphony/main"

echo -e "${BLUE}🎼 Symphony Update${NC}"
echo "Updating Symphony to the latest version..."
echo

# Check if Symphony is installed
if [[ ! -d "$SYMPHONY_DIR" ]]; then
    echo -e "${RED}Error: Symphony is not installed${NC}"
    echo "Run the install script first: curl -fsSL https://raw.githubusercontent.com/harichristensen/symphony/main/install.sh | bash"
    exit 1
fi

# Check if there's an active session
if tmux has-session -t symphony 2>/dev/null; then
    echo -e "${YELLOW}Warning: Active Symphony session detected${NC}"
    echo "Consider stopping the session before updating: symphony stop"
    echo
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Update cancelled"
        exit 0
    fi
fi

# Create backup
backup_installation() {
    echo "Creating backup..."
    
    # Create backup directory with timestamp
    local backup_dir="$SYMPHONY_BACKUP/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup bin and lib directories
    if [[ -d "$SYMPHONY_BIN" ]]; then
        cp -r "$SYMPHONY_BIN" "$backup_dir/bin"
    fi
    if [[ -d "$SYMPHONY_LIB" ]]; then
        cp -r "$SYMPHONY_LIB" "$backup_dir/lib"
    fi
    
    echo -e "${GREEN}✓ Backup created at $backup_dir${NC}"
    
    # Clean old backups (keep last 5)
    if [[ -d "$SYMPHONY_BACKUP" ]]; then
        ls -dt "$SYMPHONY_BACKUP"/* | tail -n +6 | xargs rm -rf 2>/dev/null || true
    fi
}

# Download file with error handling
download_file() {
    local url="$1"
    local dest="$2"
    local description="$3"
    
    if curl -fsSL "$url" -o "$dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Updated $description${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Could not update $description (may not exist in repo)${NC}"
        return 1
    fi
}

# Update scripts
update_scripts() {
    echo "Downloading latest scripts..."
    
    # Main CLI scripts
    download_file "$REPO_BASE/bin/symphony" "$SYMPHONY_BIN/symphony" "main CLI"
    download_file "$REPO_BASE/bin/symphony-orchestrator.sh" "$SYMPHONY_BIN/symphony-orchestrator.sh" "orchestrator"
    download_file "$REPO_BASE/bin/symphony-spawn-agent.sh" "$SYMPHONY_BIN/symphony-spawn-agent.sh" "agent spawner"
    download_file "$REPO_BASE/bin/symphony-monitor.sh" "$SYMPHONY_BIN/symphony-monitor.sh" "monitor"
    download_file "$REPO_BASE/bin/symphony-cleanup.sh" "$SYMPHONY_BIN/symphony-cleanup.sh" "cleanup utility"
    download_file "$REPO_BASE/bin/symphony-console.sh" "$SYMPHONY_BIN/symphony-console.sh" "console interface"
    download_file "$REPO_BASE/bin/symphony-update.sh" "$SYMPHONY_BIN/symphony-update.sh" "update script"
    
    # Library scripts
    download_file "$REPO_BASE/lib/tmux-layouts.sh" "$SYMPHONY_LIB/tmux-layouts.sh" "tmux layouts"
    download_file "$REPO_BASE/lib/agent-prompts.sh" "$SYMPHONY_LIB/agent-prompts.sh" "agent prompts"
    download_file "$REPO_BASE/lib/progress-parser.sh" "$SYMPHONY_LIB/progress-parser.sh" "progress parser"
    download_file "$REPO_BASE/lib/git-operations.sh" "$SYMPHONY_LIB/git-operations.sh" "git operations"
    
    # Configuration template (don't overwrite existing)
    if [[ ! -f "$SYMPHONY_CONFIG/symphony.config.yml.example" ]]; then
        download_file "$REPO_BASE/config/symphony.config.yml.example" "$SYMPHONY_CONFIG/symphony.config.yml.example" "config template"
    fi
    
    # Make scripts executable
    chmod +x "$SYMPHONY_BIN"/* 2>/dev/null || true
    chmod +x "$SYMPHONY_LIB"/* 2>/dev/null || true
    
    echo -e "${GREEN}✓ All scripts updated${NC}"
}

# Check for version changes
check_version() {
    if [[ -f "$SYMPHONY_BIN/symphony" ]]; then
        local current_version
        current_version=$(grep "^SYMPHONY_VERSION=" "$SYMPHONY_BIN/symphony" | cut -d'"' -f2)
        echo "Current version: $current_version"
        echo "Checking for updates..."
    fi
}

# Show changelog if available
show_changelog() {
    echo
    echo "Fetching changelog..."
    local changelog_url="$REPO_BASE/CHANGELOG.md"
    local changelog
    
    if changelog=$(curl -fsSL "$changelog_url" 2>/dev/null); then
        echo -e "${BLUE}Recent changes:${NC}"
        echo "$changelog" | head -20
        echo
    else
        echo "No changelog available"
    fi
}

# Restore from backup if update fails
restore_backup() {
    echo -e "${RED}Update failed! Restoring from backup...${NC}"
    
    local latest_backup
    latest_backup=$(ls -dt "$SYMPHONY_BACKUP"/* 2>/dev/null | head -1)
    
    if [[ -n "$latest_backup" && -d "$latest_backup" ]]; then
        if [[ -d "$latest_backup/bin" ]]; then
            rm -rf "$SYMPHONY_BIN"
            cp -r "$latest_backup/bin" "$SYMPHONY_BIN"
        fi
        if [[ -d "$latest_backup/lib" ]]; then
            rm -rf "$SYMPHONY_LIB"
            cp -r "$latest_backup/lib" "$SYMPHONY_LIB"
        fi
        echo -e "${GREEN}✓ Restored from backup${NC}"
    else
        echo -e "${RED}No backup available to restore${NC}"
    fi
}

# Main update flow
main() {
    # Trap errors and restore on failure
    trap 'restore_backup; exit 1' ERR
    
    check_version
    backup_installation
    update_scripts
    
    # Remove error trap after successful update
    trap - ERR
    
    show_changelog
    
    echo -e "${GREEN}🎉 Symphony updated successfully!${NC}"
    echo
    echo "Your configuration and state have been preserved."
    echo "If you encounter issues, backups are available at: $SYMPHONY_BACKUP"
    echo
    
    # Show new version
    if [[ -f "$SYMPHONY_BIN/symphony" ]]; then
        local new_version
        new_version=$(grep "^SYMPHONY_VERSION=" "$SYMPHONY_BIN/symphony" | cut -d'"' -f2)
        echo "Updated to version: $new_version"
    fi
}

# Run update
main "$@"