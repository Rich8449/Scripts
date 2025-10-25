#!/usr/bin/env bash
# git-setup.sh
# POSIX-friendly Bash script to install Git (apt), configure git global settings,
# generate an SSH key (ed25519 or rsa), copy the public key to clipboard, open
# GitHub SSH keys page, and optionally test SSH connectivity.
#
# Usage: git-setup.sh [--type ed25519|rsa] [--bits N] [--passphrase 'p'] [--key-path PATH]
#                    [--force] [--dry-run] [--verbose] [-h|--help]

set -o errexit
set -o pipefail
set -o nounset

# Defaults
DEFAULT_NAME="Rich.Taft"
DEFAULT_EMAIL="Rich8449@gmail.com"
DEFAULT_EDITOR="code --wait"
DEFAULT_BRANCH="main"
DEFAULT_KEY_TYPE="ed25519"
DEFAULT_RSA_BITS=4096
DEFAULT_KEY_PATH="$HOME/.ssh/id_ed25519"

# Flags/state
FORCE=0
DRY_RUN=0
VERBOSE=0
KEY_TYPE="$DEFAULT_KEY_TYPE"
RSA_BITS=$DEFAULT_RSA_BITS
PASSPHRASE=""
KEY_PATH="$DEFAULT_KEY_PATH"

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --type ed25519|rsa       SSH key type (default: ed25519)
  --bits N                 RSA bits (default: ${DEFAULT_RSA_BITS})
  --passphrase 'p'         Passphrase for the key (careful: appears in process list)
  --key-path PATH          Path to private key (default: ${DEFAULT_KEY_PATH})
  --force                  Overwrite existing key/config (backups made)
  --dry-run                Show actions but don't perform them
  --verbose                Print extra debug/logging
  -h, --help               Show this help

This script installs Git using apt-get, configures core git settings,
generates an SSH key (if not present), copies the public key to clipboard
(tries wl-copy, xclip, xsel), opens the GitHub SSH keys page with xdg-open,
and offers to run 'ssh -T git@github.com' to validate the key.
EOF
}

log() { [ "$VERBOSE" -eq 1 ] && printf '%s\n' "$*"; }
info() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] %s\n' "$*"
  else
    log "RUN: $*"
    eval "$@"
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "required command '$1' not found"
    return 1
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --type)
        KEY_TYPE="$2"; shift 2;;
      --bits)
        RSA_BITS="$2"; shift 2;;
      --passphrase)
        PASSPHRASE="$2"; shift 2;;
      --key-path)
        KEY_PATH="$2"; shift 2;;
      --force)
        FORCE=1; shift 1;;
      --dry-run)
        DRY_RUN=1; shift 1;;
      --verbose)
        VERBOSE=1; shift 1;;
      -h|--help)
        print_help; exit 0;;
      *)
        err "Unknown option: $1"; print_help; exit 2;;
    esac
  done
}

ensure_apt_and_sudo() {
  if ! command -v apt-get >/dev/null 2>&1; then
    err "apt-get not found. This script uses apt-get to install Git as requested."
    return 1
  fi
  if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    err "sudo required to install packages (not running as root and sudo missing)."
    return 1
  fi
  return 0
}

install_git_if_missing() {
  if command -v git >/dev/null 2>&1; then
    log "git already installed"
    return 0
  fi
  info "Git not found. Installing git using apt-get..."
  if [ "$DRY_RUN" -eq 1 ]; then
    info "(dry-run) Would run: sudo apt-get update && sudo apt-get install -y git"
  else
    if [ "$EUID" -eq 0 ]; then
      apt-get update && apt-get install -y git
    else
      sudo apt-get update && sudo apt-get install -y git
    fi
  fi
}

cfg_get() { git config --global --get "$1" 2>/dev/null || true; }
cfg_set_if_needed() {
  key="$1"; val="$2"
  cur=$(cfg_get "$key" )
  if [ -z "$cur" ] || [ "$cur" != "$val" ] || [ "$FORCE" -eq 1 ]; then
    info "Setting git config $key -> $val"
    run_cmd git config --global "$key" "$val"
  else
    log "git config $key already set (no change)"
  fi
}

generate_ssh_key() {
  pub="${KEY_PATH}.pub"
  if [ -f "$KEY_PATH" ] && [ "$FORCE" -ne 1 ]; then
    info "SSH key $KEY_PATH already exists. Use --force to overwrite or provide --key-path."
    return 0
  fi
  if [ -f "$KEY_PATH" ] && [ "$FORCE" -eq 1 ]; then
    ts=$(date +%Y%m%d%H%M%S)
    backup_private="${KEY_PATH}.bak.${ts}"
    backup_pub="${pub}.bak.${ts}"
    info "Backing up existing keys to $backup_private and $backup_pub"
    run_cmd mv "$KEY_PATH" "$backup_private"
    [ -f "$pub" ] && run_cmd mv "$pub" "$backup_pub"
  fi

  mkdir -p "$(dirname "$KEY_PATH")"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "(dry-run) Would generate SSH key: type=$KEY_TYPE path=$KEY_PATH"
    return 0
  fi

  if [ "$KEY_TYPE" = "ed25519" ]; then
    if [ -n "$PASSPHRASE" ]; then
      ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$DEFAULT_EMAIL" -N "$PASSPHRASE"
    else
      ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$DEFAULT_EMAIL" -N ""
    fi
  else
    # rsa
    if [ -n "$PASSPHRASE" ]; then
      ssh-keygen -t rsa -b "$RSA_BITS" -f "$KEY_PATH" -C "$DEFAULT_EMAIL" -N "$PASSPHRASE"
    else
      ssh-keygen -t rsa -b "$RSA_BITS" -f "$KEY_PATH" -C "$DEFAULT_EMAIL" -N ""
    fi
  fi

  # Permissions
  run_cmd chmod 600 "$KEY_PATH"
  run_cmd chmod 644 "$pub" || true
}

copy_pubkey_to_clipboard_or_print() {
  pub="${KEY_PATH}.pub"
  if [ ! -f "$pub" ]; then
    err "Public key $pub not found"
    return 1
  fi
  content=$(cat "$pub")
  if command -v wl-copy >/dev/null 2>&1; then
    info "Copying public key to clipboard via wl-copy"
    run_cmd printf '%s' "$content" | wl-copy
    return 0
  elif command -v xclip >/dev/null 2>&1; then
    info "Copying public key to clipboard via xclip"
    run_cmd printf '%s' "$content" | xclip -selection clipboard
    return 0
  elif command -v xsel >/dev/null 2>&1; then
    info "Copying public key to clipboard via xsel"
    run_cmd printf '%s' "$content" | xsel --clipboard --input
    return 0
  else
    info "No clipboard tool found (wl-copy/xclip/xsel). Printing public key below:\n"
    printf '%s\n' "$content"
    return 0
  fi
}

open_github_keys_page() {
  url="https://github.com/settings/keys"
  if command -v xdg-open >/dev/null 2>&1 && [ "$DISPLAY" != "" ] 2>/dev/null || command -v xdg-open >/dev/null 2>&1; then
    info "Opening GitHub SSH keys page in default browser"
    run_cmd xdg-open "$url" || info "Could not open browser; URL: $url"
  else
    info "No desktop environment detected or xdg-open missing. Please open: $url"
  fi
}

prompt_yes_no() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'y' # assume yes in dry-run
    return 0
  fi
  while true; do
    read -r -p "$1 [y/n]: " yn
    case "$yn" in
      [Yy]* ) return 0;;
      [Nn]* ) return 1;;
      * ) echo "Please answer y or n.";;
    esac
  done
}

test_ssh_to_github() {
  info "Testing SSH connection to github.com (this will attempt to contact GitHub)"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "(dry-run) Would run: ssh -T git@github.com"
    return 0
  fi
  if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" || ssh -T git@github.com 2>&1 | grep -q "authenticated"; then
    info "SSH authentication worked (GitHub responded)."
    return 0
  else
    info "SSH test finished. Output above may indicate success or failure."
    return 1
  fi
}

main() {
  parse_args "$@"

  # Basic checks
  if ! ensure_apt_and_sudo; then
    err "Environment check failed. This script requires apt-get and sudo (or root)."
    exit 3
  fi

  install_git_if_missing

  # git configs
  cfg_set_if_needed user.name "$DEFAULT_NAME"
  cfg_set_if_needed user.email "$DEFAULT_EMAIL"
  cfg_set_if_needed core.editor "$DEFAULT_EDITOR"
  cfg_set_if_needed init.defaultBranch "$DEFAULT_BRANCH"

  # difftool -> VS Code
  # Set difftool command and default tool
  info "Configuring VS Code as difftool"
  run_cmd git config --global diff.tool vscode
  run_cmd git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'
  run_cmd git config --global difftool.prompt false

  # SSH key generation
  generate_ssh_key

  # Copy pubkey to clipboard or print
  copy_pubkey_to_clipboard_or_print

  # Open GitHub SSH keys page
  open_github_keys_page

  # Prompt to add the key and optionally test
  if prompt_yes_no "Have you added the SSH key to your GitHub account and want to test SSH now?"; then
    if ! test_ssh_to_github; then
      err "SSH test failed or inconclusive. Check that your public key is added to GitHub and that your SSH agent has the key loaded."
      exit 4
    fi
  else
    info "Skipping SSH test. You can run: ssh -T git@github.com to test later."
  fi

  info "Done."
}

main "$@"
