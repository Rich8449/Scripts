#!/usr/bin/env bash
# git-create-repo.sh — Create a GitHub repository and link it to the current directory.
#
# Authentication:
#   Preferred: GitHub CLI (gh) — run `gh auth login` if not authenticated.
#   Fallback:  Set GITHUB_TOKEN env var with 'repo' scope.
#              Create a token at: https://github.com/settings/tokens/new?scopes=repo
#              Never hardcode tokens in this script or expose them in shell history.
#
# Usage:
#   ./git-create-repo.sh [OPTIONS]
#
# Exit codes:
#   0  success
#   1  general error
#   2  missing dependency (git, gh, or curl)
#   3  authentication failure
#   4  repo already exists and --force not specified
#   5  push failed

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
readonly DEFAULT_USER_NAME="Rich.Taft"
readonly DEFAULT_USER_EMAIL="Rich8449@gmail.com"
readonly DEFAULT_BRANCH="main"
readonly DEFAULT_REMOTE="origin"

# ── State (overridden by flags) ───────────────────────────────────────────────
REPO_NAME=""
DESCRIPTION=""
VISIBILITY="private"
GITIGNORE_TEMPLATE=""
LICENSE_SPDX=""
REMOTE_NAME="$DEFAULT_REMOTE"
BRANCH="$DEFAULT_BRANCH"
PUSH=false
ORG=""
FORCE=false
DRY_RUN=false
VERBOSE=false
OPEN_BROWSER=false
NON_INTERACTIVE=false

AUTH_METHOD=""   # "gh" or "curl"
REMOTE_URL=""
REMOTE_PROTOCOL=""

# ── Logging ───────────────────────────────────────────────────────────────────
log()     { echo "[git-create-repo] $*"; }
info()    { $VERBOSE && echo "[verbose] $*" || true; }
warn()    { echo "[warn] $*" >&2; }
err()     { echo "[error] $*" >&2; }

run() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
    else
        info "Running: $*"
        "$@"
    fi
}

confirm() {
    local prompt="$1"
    if $NON_INTERACTIVE; then
        err "Prompt required but --non-interactive set: $prompt"
        exit 1
    fi
    read -r -p "$prompt [y/N] " _answer
    [[ "$_answer" =~ ^[Yy]$ ]]
}

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create a GitHub repository and link it to the current directory.

Authentication:
  Preferred:  GitHub CLI (gh) — run \`gh auth login\` if not authenticated.
  Fallback:   export GITHUB_TOKEN=<token>  (requires 'repo' scope)
              Create token: https://github.com/settings/tokens/new?scopes=repo

Options:
  --name NAME           Repo name (default: basename of current directory)
  --description TEXT    Repository description
  --public              Make repository public (default: private)
  --private             Make repository private (default)
  --gitignore TEMPLATE  Gitignore template name (e.g. Python, Node, Go)
  --license SPDX        License SPDX identifier (e.g. MIT, Apache-2.0)
  --remote-name NAME    Remote name (default: origin)
  --branch NAME         Default branch name (default: main)
  --push                Push initial commit and set upstream (default: do not push)
  --org ORGNAME         Create repo under an organization
  --force               Overwrite local remote or replace remote repo if it exists
  --dry-run             Print actions without executing them
  --verbose             Extra debug logging
  --open                Open the created repo in the browser after creation
  --non-interactive     Fail on prompts instead of asking
  -h, --help            Show this help

Examples:
  # Public repo, initial commit, push, Python gitignore, MIT license:
  ./git-create-repo.sh --name mytool --description 'My tool' --public \\
      --push --gitignore Python --license MIT

  # Private org repo, non-interactive:
  GITHUB_TOKEN=xxx ./git-create-repo.sh --name confidential --private \\
      --org myorg --push --non-interactive --force
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)             REPO_NAME="$2";           shift 2 ;;
            --description)      DESCRIPTION="$2";         shift 2 ;;
            --public)           VISIBILITY="public";       shift ;;
            --private)          VISIBILITY="private";      shift ;;
            --gitignore)        GITIGNORE_TEMPLATE="$2";   shift 2 ;;
            --license)          LICENSE_SPDX="$2";         shift 2 ;;
            --remote-name)      REMOTE_NAME="$2";          shift 2 ;;
            --branch)           BRANCH="$2";               shift 2 ;;
            --push)             PUSH=true;                 shift ;;
            --org)              ORG="$2";                  shift 2 ;;
            --force)            FORCE=true;                shift ;;
            --dry-run)          DRY_RUN=true;              shift ;;
            --verbose)          VERBOSE=true;              shift ;;
            --open)             OPEN_BROWSER=true;         shift ;;
            --non-interactive)  NON_INTERACTIVE=true;      shift ;;
            -h|--help)          usage; exit 0 ;;
            *) err "Unknown option: $1"; usage >&2; exit 1 ;;
        esac
    done
}

# ── Dependency & auth checks ──────────────────────────────────────────────────
check_deps() {
    if ! command -v git &>/dev/null; then
        err "git is not installed. Install it with your OS package manager (e.g. sudo apt-get install git)."
        exit 2
    fi
    info "git: $(git --version)"
}

detect_auth_method() {
    if command -v gh &>/dev/null; then
        info "gh CLI found: $(gh --version | head -1)"
        if gh auth status &>/dev/null 2>&1; then
            info "gh is authenticated"
            AUTH_METHOD="gh"
            return
        else
            warn "gh is installed but not authenticated. Run: gh auth login"
        fi
    fi

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        if ! command -v curl &>/dev/null; then
            err "curl is required when using GITHUB_TOKEN but is not installed."
            exit 2
        fi
        info "Using GITHUB_TOKEN with curl"
        AUTH_METHOD="curl"
        return
    fi

    if $DRY_RUN; then
        warn "No authentication found — dry-run will proceed with placeholder values."
        AUTH_METHOD="none"
        return
    fi
    err "No authentication found. Either:"
    err "  1. Install gh (https://cli.github.com) and run: gh auth login"
    err "  2. Set GITHUB_TOKEN with 'repo' scope: https://github.com/settings/tokens/new?scopes=repo"
    exit 3
}

# ── Git global config ─────────────────────────────────────────────────────────
ensure_git_config() {
    local current_name current_email
    current_name=$(git config --global user.name 2>/dev/null || true)
    current_email=$(git config --global user.email 2>/dev/null || true)

    if [[ -z "$current_name" ]]; then
        log "git user.name not set — defaulting to '$DEFAULT_USER_NAME'"
        run git config --global user.name "$DEFAULT_USER_NAME"
    fi
    if [[ -z "$current_email" ]]; then
        log "git user.email not set — defaulting to '$DEFAULT_USER_EMAIL'"
        run git config --global user.email "$DEFAULT_USER_EMAIL"
    fi
}

# ── .gitignore ────────────────────────────────────────────────────────────────
fetch_gitignore() {
    [[ -z "$GITIGNORE_TEMPLATE" ]] && return
    local url="https://raw.githubusercontent.com/github/gitignore/main/${GITIGNORE_TEMPLATE}.gitignore"
    if $DRY_RUN; then
        echo "[dry-run] Would fetch .gitignore template '$GITIGNORE_TEMPLATE' from $url"
        return
    fi
    if curl -fsSL "$url" -o .gitignore 2>/dev/null; then
        info "Created .gitignore from template '$GITIGNORE_TEMPLATE'"
    else
        warn "Could not fetch .gitignore template '$GITIGNORE_TEMPLATE' — skipping."
    fi
}

# ── LICENSE ───────────────────────────────────────────────────────────────────
fetch_license() {
    [[ -z "$LICENSE_SPDX" ]] && return
    if $DRY_RUN; then
        echo "[dry-run] Would create LICENSE for '$LICENSE_SPDX'"
        return
    fi

    local key url body
    key=$(echo "$LICENSE_SPDX" | tr '[:upper:]' '[:lower:]')
    url="https://api.github.com/licenses/${key}"

    body=$(curl -fsSL -H "Accept: application/vnd.github+json" "$url" 2>/dev/null || true)
    if [[ -n "$body" ]]; then
        # Use python3 if available for reliable JSON parsing; fall back to a sed heuristic
        local text=""
        if command -v python3 &>/dev/null; then
            text=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('body',''))" 2>/dev/null || true)
        fi
        if [[ -n "$text" ]]; then
            printf '%s\n' "$text" > LICENSE
            info "Created LICENSE file for '$LICENSE_SPDX'"
            return
        fi
    fi

    warn "Could not fetch LICENSE for '$LICENSE_SPDX' — creating placeholder."
    printf '# License: %s\n# Replace this file with the full license text.\n' "$LICENSE_SPDX" > LICENSE
}

# ── Local repo init ───────────────────────────────────────────────────────────
init_local_repo() {
    if git rev-parse --git-dir &>/dev/null 2>&1; then
        log "Existing git repo detected in $(git rev-parse --show-toplevel)"
        if $FORCE; then
            log "--force specified; continuing to link remote."
        else
            log "Will use existing repo. Use --force to suppress this message."
        fi
        return
    fi

    log "No git repo found — initializing..."
    if $DRY_RUN; then
        echo "[dry-run] git init"
        echo "[dry-run] git symbolic-ref HEAD refs/heads/$BRANCH"
        echo "[dry-run] Would create README.md"
        [[ -n "$GITIGNORE_TEMPLATE" ]] && fetch_gitignore
        [[ -n "$LICENSE_SPDX" ]]       && fetch_license
        echo "[dry-run] git add -A && git commit -m 'Initial commit'"
        return
    fi

    git init
    git symbolic-ref HEAD "refs/heads/${BRANCH}"

    if [[ ! -f README.md ]]; then
        printf '# %s\n' "$REPO_NAME" > README.md
        [[ -n "$DESCRIPTION" ]] && printf '\n%s\n' "$DESCRIPTION" >> README.md
        info "Created README.md"
    fi

    fetch_gitignore
    fetch_license

    git add -A
    git commit -m "Initial commit"
    log "Initial commit created."
}

# ── GitHub repo creation ──────────────────────────────────────────────────────
_gh_owner_prefix() {
    # Returns "ORG/" if --org is set, else ""
    [[ -n "$ORG" ]] && echo "${ORG}/" || echo ""
}

create_github_repo_gh() {
    local repo_slug
    repo_slug="$(_gh_owner_prefix)${REPO_NAME}"

    local gh_args=("$repo_slug")
    [[ "$VISIBILITY" == "private" ]] && gh_args+=("--private") || gh_args+=("--public")
    [[ -n "$DESCRIPTION" ]] && gh_args+=("--description" "$DESCRIPTION")

    if $DRY_RUN; then
        echo "[dry-run] gh repo create ${gh_args[*]}"
        return
    fi

    local output
    if output=$(gh repo create "${gh_args[@]}" 2>&1); then
        log "GitHub repository '$repo_slug' created."
        info "$output"
    else
        # Check whether it already exists
        if gh repo view "$repo_slug" &>/dev/null 2>&1; then
            handle_existing_repo
        else
            err "gh repo create failed: $output"
            exit 1
        fi
    fi
}

create_github_repo_curl() {
    local api_url is_private json http_code body full_response

    if [[ -n "$ORG" ]]; then
        api_url="https://api.github.com/orgs/${ORG}/repos"
    else
        api_url="https://api.github.com/user/repos"
    fi

    [[ "$VISIBILITY" == "private" ]] && is_private="true" || is_private="false"
    json=$(printf '{"name":"%s","description":"%s","private":%s}' \
        "$REPO_NAME" "$DESCRIPTION" "$is_private")

    if $DRY_RUN; then
        echo "[dry-run] POST $api_url"
        echo "[dry-run] Body: $json"
        return
    fi

    full_response=$(curl -sS -w "\n%{http_code}" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/json" \
        -d "$json" \
        "$api_url" 2>/dev/null)
    http_code=$(printf '%s' "$full_response" | tail -1)
    body=$(printf '%s' "$full_response" | head -n -1)

    case "$http_code" in
        201)
            log "GitHub repository '${ORG:+${ORG}/}${REPO_NAME}' created." ;;
        401|403)
            err "GitHub API auth failed (HTTP $http_code). Verify GITHUB_TOKEN has 'repo' scope."
            exit 3 ;;
        422)
            handle_existing_repo ;;
        *)
            err "GitHub API error (HTTP $http_code): $body"
            exit 1 ;;
    esac
}

handle_existing_repo() {
    local repo_slug="$(_gh_owner_prefix)${REPO_NAME}"
    warn "Repository '$repo_slug' already exists on GitHub."

    if ! $FORCE; then
        err "Use --force to link to the existing repo or delete and recreate it."
        exit 4
    fi

    if ! $NON_INTERACTIVE && confirm "Delete and recreate '$repo_slug'? This is DESTRUCTIVE and cannot be undone."; then
        log "Deleting '$repo_slug'..."
        if [[ "$AUTH_METHOD" == "gh" ]]; then
            gh repo delete "$repo_slug" --yes
            create_github_repo_gh
        else
            local owner
            owner=$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
                https://api.github.com/user 2>/dev/null \
                | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])" 2>/dev/null || true)
            curl -fsSL -X DELETE \
                -H "Authorization: token $GITHUB_TOKEN" \
                "https://api.github.com/repos/${ORG:-$owner}/${REPO_NAME}" >/dev/null
            create_github_repo_curl
        fi
    else
        log "Linking to existing remote '$repo_slug'."
    fi
}

create_github_repo() {
    if [[ "$AUTH_METHOD" == "gh" ]]; then
        create_github_repo_gh
    else
        create_github_repo_curl
    fi
}

# ── SSH vs HTTPS detection ────────────────────────────────────────────────────
detect_remote_protocol() {
    if ls ~/.ssh/id_*.pub &>/dev/null 2>&1; then
        info "SSH public key found. Testing GitHub agent..."
        local ssh_exit=0
        # Exit 1 = authenticated; 255 = no agent or key not registered with GitHub
        ssh -T git@github.com -o StrictHostKeyChecking=no -o BatchMode=yes &>/dev/null || ssh_exit=$?
        if [[ $ssh_exit -eq 1 ]]; then
            log "SSH: authenticated. Using SSH remote URL."
            REMOTE_PROTOCOL="ssh"
        else
            log "SSH: key found but agent not live or key not added to GitHub (exit $ssh_exit). Using HTTPS."
            REMOTE_PROTOCOL="https"
        fi
    else
        info "No ~/.ssh/id_*.pub found. Using HTTPS remote URL."
        REMOTE_PROTOCOL="https"
    fi
}

resolve_github_owner() {
    if [[ -n "$ORG" ]]; then
        echo "$ORG"
        return
    fi
    if [[ "$AUTH_METHOD" == "gh" ]]; then
        gh api user --jq .login 2>/dev/null
    else
        curl -fsSL \
            -H "Authorization: token $GITHUB_TOKEN" \
            https://api.github.com/user 2>/dev/null \
            | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])" 2>/dev/null
    fi
}

build_remote_url() {
    if $DRY_RUN; then
        REMOTE_URL="<remote-url-would-go-here>"
        return
    fi

    detect_remote_protocol

    local owner
    owner=$(resolve_github_owner)
    if [[ -z "$owner" ]]; then
        err "Could not determine GitHub owner for remote URL."
        exit 1
    fi

    if [[ "$REMOTE_PROTOCOL" == "ssh" ]]; then
        REMOTE_URL="git@github.com:${owner}/${REPO_NAME}.git"
    else
        REMOTE_URL="https://github.com/${owner}/${REPO_NAME}.git"
    fi
    info "Remote URL: $REMOTE_URL"
}

# ── Remote linking ────────────────────────────────────────────────────────────
link_remote() {
    build_remote_url

    if $DRY_RUN; then
        echo "[dry-run] git remote add $REMOTE_NAME $REMOTE_URL"
        return
    fi

    if git remote get-url "$REMOTE_NAME" &>/dev/null 2>&1; then
        local existing
        existing=$(git remote get-url "$REMOTE_NAME")
        if [[ "$existing" == "$REMOTE_URL" ]]; then
            info "Remote '$REMOTE_NAME' already points to $REMOTE_URL — no change."
            return
        fi
        if $FORCE; then
            log "Updating remote '$REMOTE_NAME': $existing → $REMOTE_URL"
            git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
        else
            err "Remote '$REMOTE_NAME' already exists ($existing). Use --force to update it."
            exit 1
        fi
    else
        git remote add "$REMOTE_NAME" "$REMOTE_URL"
        log "Remote '$REMOTE_NAME' set to $REMOTE_URL"
    fi
}

# ── Push ──────────────────────────────────────────────────────────────────────
push_to_remote() {
    if ! $PUSH; then
        info "Skipping push (--push not specified)."
        return
    fi

    log "Pushing '$BRANCH' to '$REMOTE_NAME'..."
    if ! run git push --set-upstream "$REMOTE_NAME" "$BRANCH"; then
        err "Push failed."
        exit 5
    fi
    log "Push succeeded. Remote: $REMOTE_URL"
}

# ── Verify & open ─────────────────────────────────────────────────────────────
verify_repo() {
    $DRY_RUN && { echo "[dry-run] Would verify repo metadata"; return; }
    [[ "$AUTH_METHOD" != "gh" ]] && return
    local repo_slug="$(_gh_owner_prefix)${REPO_NAME}"
    info "Verifying repo '$repo_slug'..."
    gh repo view "$repo_slug" 2>/dev/null || true
}

open_in_browser() {
    $OPEN_BROWSER || return
    $DRY_RUN && { echo "[dry-run] Would open repo in browser"; return; }

    local repo_slug="$(_gh_owner_prefix)${REPO_NAME}"
    log "Opening repo in browser..."
    if [[ "$AUTH_METHOD" == "gh" ]]; then
        gh repo view "$repo_slug" --web
    elif command -v xdg-open &>/dev/null; then
        xdg-open "https://github.com/${repo_slug}"
    elif command -v open &>/dev/null; then
        open "https://github.com/${repo_slug}"
    else
        warn "Could not open browser. Visit: https://github.com/${repo_slug}"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    [[ -z "$REPO_NAME" ]] && REPO_NAME=$(basename "$(pwd)")
    $DRY_RUN && log "Dry-run mode — no changes will be made."

    check_deps
    detect_auth_method
    ensure_git_config
    init_local_repo
    create_github_repo
    link_remote
    push_to_remote
    verify_repo
    open_in_browser

    log "Done. Repository '$REPO_NAME' is ready."
    [[ -n "$REMOTE_URL" && "$REMOTE_URL" != "<remote-url-would-go-here>" ]] && log "Remote: $REMOTE_URL"
}

main "$@"
