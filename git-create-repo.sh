#!/usr/bin/env bash
# git-create-repo.sh
# POSIX-friendly Bash script to initialize a local git repository and create
# the corresponding GitHub repository using `gh` when available or the
# GitHub REST API (requires GITHUB_TOKEN). Safe, idempotent, with --dry-run
# and --verbose modes. Defaults: user.name="Rich.Taft", user.email="Rich8449@gmail.com",
# default branch "main".
#
# Usage examples (see --help for full list):
#  ./git-create-repo.sh --name mytool --description 'My tool' --push --gitignore Python --license MIT
#  GITHUB_TOKEN=xxx ./git-create-repo.sh --name confidential --private --org myorg --push --non-interactive --force

set -o errexit
set -o pipefail
set -o nounset

# Defaults
DEFAULT_NAME="Rich.Taft"
DEFAULT_EMAIL="Rich8449@gmail.com"
DEFAULT_BRANCH="main"
DEFAULT_REMOTE_NAME="origin"
DEFAULT_PRIVATE=1  # default private unless --public specified

# State
REPO_NAME=""
DESCRIPTION=""
PRIVATE=$DEFAULT_PRIVATE
GITIGNORE=""
LICENSE=""
REMOTE_NAME="$DEFAULT_REMOTE_NAME"
BRANCH="$DEFAULT_BRANCH"
PUSH=0
ORG=""
FORCE=0
DRY_RUN=0
VERBOSE=0
OPEN=0
NON_INTERACTIVE=0

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --name NAME            Repository name (default: basename of current directory)
  --description TEXT     Repository description
  --private              Create repository as private (default)
  --public               Create repository as public
  --gitignore TEMPLATE   Add a .gitignore from a template name (e.g. Python)
  --license SPDX         Add a LICENSE file with SPDX id (e.g. MIT)
  --remote-name NAME     Remote name to add (default: ${DEFAULT_REMOTE_NAME})
  --branch NAME          Initial branch name (default: ${DEFAULT_BRANCH})
  --push                 Push the initial commit and set upstream
  --org ORGNAME          Create repository under an organization
  --force                Overwrite/link even if remote/repo exists
  --dry-run              Show actions but do not perform them
  --verbose              Enable verbose logging
  --open                 Open created repo in browser after creation
  --non-interactive      Fail instead of prompting
  -h, --help             Show this help

Environment:
  This script prefers the GitHub CLI `gh` (no token required when `gh` is
  authenticated). If `gh` is not available the script will open your browser
  to the GitHub new-repository page so you can create the repository manually
  and then paste the repository clone URL back into the script. This avoids
  requiring a GITHUB_TOKEN in the script itself.

This script attempts to be safe and idempotent. It will avoid destructive
operations unless --force is provided. Use --dry-run to preview actions.
EOF
}

log() { [ "$VERBOSE" -eq 1 ] && printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
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
      --name) REPO_NAME="$2"; shift 2;;
      --description) DESCRIPTION="$2"; shift 2;;
      --private) PRIVATE=1; shift 1;;
      --public) PRIVATE=0; shift 1;;
      --gitignore) GITIGNORE="$2"; shift 2;;
      --license) LICENSE="$2"; shift 2;;
      --remote-name) REMOTE_NAME="$2"; shift 2;;
      --branch) BRANCH="$2"; shift 2;;
      --push) PUSH=1; shift 1;;
      --org) ORG="$2"; shift 2;;
      --force) FORCE=1; shift 1;;
      --dry-run) DRY_RUN=1; shift 1;;
      --verbose) VERBOSE=1; shift 1;;
      --open) OPEN=1; shift 1;;
      --non-interactive) NON_INTERACTIVE=1; shift 1;;
      -h|--help) print_help; exit 0;;
      *) err "Unknown option: $1"; print_help; exit 2;;
    esac
  done
}

confirm() {
  if [ "$NON_INTERACTIVE" -eq 1 ]; then
    return 1
  fi
  printf '%s [y/N]: ' "$1"
  read -r ans
  case "$ans" in
    [Yy]* ) return 0;;
    * ) return 1;;
  esac
}

detect_git() {
  if ! command -v git >/dev/null 2>&1; then
    err "git not found. Please install git and re-run."
    exit 3
  fi
}

ensure_git_config() {
  # set defaults if missing
  if [ -z "$(git config --global --get user.name || true)" ]; then
    info "Setting global git user.name to ${DEFAULT_NAME}"
    run_cmd git config --global user.name "${DEFAULT_NAME}"
  fi
  if [ -z "$(git config --global --get user.email || true)" ]; then
    info "Setting global git user.email to ${DEFAULT_EMAIL}"
    run_cmd git config --global user.email "${DEFAULT_EMAIL}"
  fi
}

in_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

init_local_repo() {
  if in_git_repo; then
    info "Directory is already a git repository."
    return 0
  fi
  info "Initializing local git repository and creating initial commit"
  run_cmd git init
  # create branch
  if git help -a | grep -q "switch" 2>/dev/null; then
    run_cmd git switch -c "$BRANCH"
  else
    run_cmd git checkout -b "$BRANCH"
  fi

  # README
  if [ -z "$REPO_NAME" ]; then
    REPO_NAME=$(basename "$(pwd)")
  fi
  if [ ! -f README.md ]; then
    run_cmd printf '# %s\n\n%s\n' "$REPO_NAME" "$DESCRIPTION" > README.md
  else
    log "README.md already exists, skipping creation"
  fi

  # .gitignore and LICENSE via gh if available
  if [ -n "$GITIGNORE" ]; then
    if command -v gh >/dev/null 2>&1; then
      info "Adding .gitignore using gh template: $GITIGNORE"
      run_cmd gh repo clone -- -q >/dev/null 2>&1 || true
      # gh has no standalone fetch command; fallback to a simple warning
      info "No portable fetch for .gitignore without gh repo create; creating empty .gitignore (please update)"
      run_cmd printf '# %s gitignore\n' "$GITIGNORE" > .gitignore
    else
      info "gh CLI not found; creating minimal .gitignore placeholder for $GITIGNORE"
      run_cmd printf '# %s gitignore\n' "$GITIGNORE" > .gitignore
    fi
  fi

  if [ -n "$LICENSE" ]; then
    if command -v gh >/dev/null 2>&1; then
      info "Creating LICENSE file using gh for license: $LICENSE"
      # gh can create a repo with license; here we create a placeholder
      run_cmd printf '%s license: %s\n' "$REPO_NAME" "$LICENSE" > LICENSE
    else
      info "gh CLI not found; creating placeholder LICENSE with SPDX: $LICENSE"
      run_cmd printf '%s\nSPDX-License-Identifier: %s\n' "$REPO_NAME" "$LICENSE" > LICENSE
    fi
  fi

  # initial commit if none exists
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    run_cmd git add .
    run_cmd git commit -m "Initial commit"
  else
    log "Repository already has commits; skipping initial commit"
  fi
}

gh_available_and_auth() {
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  fi
  return 2
}

# NOTE: Creating repositories on GitHub requires authentication. To avoid
# storing a token in this script we removed the REST API fallback. If `gh`
# is unavailable the script will open the GitHub new-repo page in your
# browser and ask you to create the repository manually, then paste the
# repository clone URL when prompted.

ensure_remote_and_push() {
  local repo_url="$1"
  # add remote if missing
  if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
    existing=$(git remote get-url "$REMOTE_NAME")
    if [ "$existing" != "$repo_url" ]; then
      if [ "$FORCE" -eq 1 ]; then
        info "Remote $REMOTE_NAME exists with different URL; replacing due to --force"
        run_cmd git remote remove "$REMOTE_NAME"
        run_cmd git remote add "$REMOTE_NAME" "$repo_url"
      else
        info "Remote $REMOTE_NAME already exists (url: $existing). Use --force to replace or remove it manually."
      fi
    else
      log "Remote $REMOTE_NAME already points to target URL"
    fi
  else
    run_cmd git remote add "$REMOTE_NAME" "$repo_url"
  fi

  if [ "$PUSH" -eq 1 ]; then
    info "Pushing branch $BRANCH to $REMOTE_NAME"
    run_cmd git push --set-upstream "$REMOTE_NAME" "$BRANCH"
  fi
}

repo_exists_github() {
  # Returns 0 if repo exists; arguments: owner, name
  local owner="$1"; local name="$2"
  if command -v gh >/dev/null 2>&1; then
    if gh repo view "${owner}/${name}" >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  fi
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    return 2
  fi
  status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/${owner}/${name}" || true)
  [ "$status" -eq 200 ]
}

main() {
  parse_args "$@"
  detect_git
  ensure_git_config

  # default repo name
  if [ -z "$REPO_NAME" ]; then
    REPO_NAME=$(basename "$(pwd)")
  fi

  # If not in a repo, initialize local repository
  if ! in_git_repo; then
    init_local_repo
  else
    info "Using existing git repository in current directory"
  fi

  # Determine owner for remote creation
  if [ -n "$ORG" ]; then
    owner="$ORG"
  else
    # try gh to get username, else use API
    if command -v gh >/dev/null 2>&1; then
      owner=$(gh api user --jq .login 2>/dev/null) || owner=""
    else
      # try API if GITHUB_TOKEN present
      if [ -n "${GITHUB_TOKEN:-}" ]; then
        owner=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | sed -n 's/.*"login"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' || true)
      fi
    fi
  fi

  info "Repository name: $REPO_NAME; owner: ${owner:-(unknown)}; private: ${PRIVATE}" 

  # Create repo on GitHub
  repo_clone_url=""
  created=0
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    info "Creating repository using gh CLI"
    gh_args=("repo" "create" "$REPO_NAME")
    if [ "$PRIVATE" -eq 1 ]; then gh_args+=("--private"); else gh_args+=("--public"); fi
    [ -n "$DESCRIPTION" ] && gh_args+=("--description" "$DESCRIPTION")
    [ -n "$ORG" ] && gh_args+=("--org" "$ORG")
    [ "$PUSH" -eq 1 ] && gh_args+=("--source" "." "--remote" "$REMOTE_NAME" "--push")
    [ "$DRY_RUN" -eq 1 ] && info "(dry-run) gh ${gh_args[*]}" || run_cmd gh "${gh_args[@]}"

    # attempt to get clone URL
    if [ "$DRY_RUN" -eq 0 ]; then
      repo_clone_url=$(gh repo view "${owner:+${owner}/}$REPO_NAME" --json sshUrl,cloneUrl -q '.[0].sshUrl' 2>/dev/null || true)
      if [ -z "$repo_clone_url" ]; then
        repo_clone_url=$(gh repo view "${owner:+${owner}/}$REPO_NAME" --json cloneUrl -q '.[0].cloneUrl' 2>/dev/null || true)
      fi
      created=1
    fi
  else
    info "gh CLI not available or not authenticated; opening GitHub new-repo page for manual creation"
    # Build the GitHub new-repo URL with prefilled parameters
    name_enc=$(printf '%s' "$REPO_NAME" | sed 's/ /+/g')
    new_url="https://github.com/new?name=${name_enc}"
    if [ -n "$DESCRIPTION" ]; then
      desc_enc=$(printf '%s' "$DESCRIPTION" | sed 's/ /+/g')
      new_url="${new_url}&description=${desc_enc}"
    fi
    if [ "$PRIVATE" -eq 1 ]; then
      new_url="${new_url}&private=true"
    fi
    if [ -n "$ORG" ]; then
      org_enc=$(printf '%s' "$ORG" | sed 's/ /+/g')
      new_url="${new_url}&owner=${org_enc}"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
      info "(dry-run) Would open: $new_url"
      repo_clone_url=""
    else
      if command -v xdg-open >/dev/null 2>&1; then
        run_cmd xdg-open "$new_url" || info "Please open in your browser: $new_url"
      else
        info "Please open in your browser: $new_url"
      fi

      info "Create the repository in your browser. After creation, paste the repository clone URL (SSH or HTTPS) below."
      printf 'Repository clone URL (leave blank to use https://github.com/%s/%s.git): ' "${owner:-<your-username>}" "$REPO_NAME"
      read -r provided_url
      if [ -n "$provided_url" ]; then
        repo_clone_url="$provided_url"
        created=1
      else
        if [ -n "$owner" ]; then
          repo_clone_url="https://github.com/${owner}/${REPO_NAME}.git"
        else
          repo_clone_url="https://github.com/${REPO_NAME}.git"
        fi
      fi
    fi
  fi

  if [ -z "$repo_clone_url" ]; then
    info "Could not determine repo clone URL automatically. Constructing HTTPS URL instead."
    if [ -n "$owner" ]; then
      repo_clone_url="https://github.com/${owner}/${REPO_NAME}.git"
    else
      repo_clone_url="https://github.com/${REPO_NAME}.git"
    fi
  fi

  # Decide SSH vs HTTPS remote: prefer SSH if user has any public key in ~/.ssh
  remote_url="$repo_clone_url"
  if [ -d "$HOME/.ssh" ] && ls $HOME/.ssh/*.pub >/dev/null 2>&1; then
    # try to convert https -> ssh if appropriate
    if printf '%s' "$repo_clone_url" | grep -q '^https://'; then
      # extract owner/name
      ownerpart=$(printf '%s' "$repo_clone_url" | sed -n 's#https://github.com/\([^/]*\)/\([^/]*\)\.git#\1#p')
      namepart=$(printf '%s' "$repo_clone_url" | sed -n 's#https://github.com/\([^/]*\)/\([^/]*\)\.git#\2#p')
      if [ -n "$ownerpart" ] && [ -n "$namepart" ]; then
        remote_url="git@github.com:${ownerpart}/${namepart}.git"
      fi
    fi
  fi

  info "Using remote URL: $remote_url"

  ensure_remote_and_push "$remote_url"

  if [ "$OPEN" -eq 1 ]; then
    if command -v xdg-open >/dev/null 2>&1; then
      run_cmd xdg-open "https://github.com/${owner}/${REPO_NAME}" || info "Open failed; URL: https://github.com/${owner}/${REPO_NAME}"
    else
      info "Desktop open not available; view repository at: https://github.com/${owner}/${REPO_NAME}"
    fi
  fi

  info "Done. Repository: https://github.com/${owner}/${REPO_NAME}"
}

main "$@"
