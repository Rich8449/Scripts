Write a robust, well-documented POSIX/Bash script named git-create-repo.sh that performs the following tasks safely and idempotently. Provide usage examples, clear logging, and a --dry-run mode. Use the following defaults: user.name="Rich.Taft", user.email="Rich8449@gmail.com", default branch "main".

Invocation and flags

Flags to implement:
--name NAME (repo name; default: basename of current directory)
--description TEXT (repository description)
--private|--public (visibility; default: private unless --public specified)
--gitignore TEMPLATE (use a gitignore template name; optional)
--license SPDX (e.g., MIT, Apache-2.0; optional)
--remote-name NAME (default: origin)
--branch NAME (default: main)
--push (push the initial commit and set upstream)
--org ORGNAME (create repo under an organization)
--force (overwrite local remote link or replace remote repo if explicitly requested)
--dry-run (show actions but don't perform changes)
--verbose (extra logs)
--open (open the created repo in the browser after creation)
--non-interactive (fail on prompts)
-h|--help (usage)
Environment & auth

Prefer the GitHub CLI gh if available. If not, use the GitHub REST API via curl.
For the API approach, require a token in the environment variable GITHUB_TOKEN (scopes: repo) or exit with a clear message describing how to create one.
Do NOT hardcode credentials in the script. If gh is available and not authenticated, instruct user to run gh auth login.
Validate that git is installed. If not found, print a clear error and exit.
Local repo initialization & config

If there's no git repo in the current directory:
Initialize a git repo (git init) and set the first branch to the --branch value (use git checkout -b or git switch -c depending on availability).
Create a basic README.md with the repo name and optional description.
If --gitignore supplied, fetch or create a .gitignore for the template (try gh repo create --gitignore with gh; otherwise copy from a local templates folder or skip with a warning).
If --license supplied, create a LICENSE file using gh when possible; otherwise include a placeholder instructing the user to add a license.
Run git add and git commit -m "Initial commit" (unless --dry-run).
If git global user.name/email are not set, set them to the provided defaults (Rich.Taft, Rich8449@gmail.com) and inform the user; allow overriding via environment variables or flags.
If there already is a git repo, detect and inform the user. With --force, allow re-initialization or continue to link remote.
Create GitHub repo

Prefer gh repo create with appropriate flags (--public/--private, --description, --source=. --remote=NAME --push when pushing).
Fallback to REST API:
For user repos: POST to https://api.github.com/user/repos with JSON {name, description, private}.
For org repos: POST to https://api.github.com/orgs/ORG/repos.
Use GITHUB_TOKEN from environment; check that it exists and has required scopes.
Handle API errors (401/403, validation errors) and present actionable messages.
If repo already exists on GitHub:
If --force and user confirms (or --non-interactive with --force), optionally delete+recreate (warn prominently), otherwise link to the existing remote and exit or prompt to rename.
Remote linking, pushing, and verification

Add remote git remote add <remote-name> <repo-ssh-or-https-url> (choose SSH if SSH keys exist and agent loaded, else HTTPS).
If --push requested, run git push --set-upstream <remote-name> <branch>.
Validate push succeeded and print remote URL.
Optionally run gh repo view <repo> or curl to verify repo metadata.
UX, logging, and safety

Implement --dry-run and --verbose.
Provide clear help text and usage examples.
Prompt before destructive operations (deleting remote repo), allow --force to skip prompts.
Exit with non-zero codes for failures and return helpful error messages.
Keep the script idempotent by checking states before acting.
Examples

Create a public repo named mytool with initial commit and push:
./git-create-repo.sh --name mytool --description 'My tool' --push --gitignore Python --license MIT
Create a private org repo non-interactively:
GITHUB_TOKEN=xxx ./git-create-repo.sh --name confidential --private --org myorg --push --non-interactive --force
Deliverables

A single executable script git-create-repo.sh with inline comments and a header describing usage and flags.
A short README snippet included at the top explaining how to set GITHUB_TOKEN or use gh auth.
Minimal internal tests (optional): simple dry-run examples or assertions.
Security note: instruct the implementer not to echo sensitive tokens and to prefer using the GitHub CLI or reading tokens from the environment. If using curl, recommend temporary environment variables and clearing them after use.

C — Short one-liner (for quick generator tools)
Generate a POSIX/Bash script git-create-repo.sh that sets git user.name="Rich.Taft" and user.email="Rich8449@gmail.com" if unset, initializes a local repo (README, .gitignore, LICENSE optional), creates the repo on GitHub using gh if present or the REST API via GITHUB_TOKEN, adds remote, pushes initial commit (optional), supports flags for name/description/private/gitignore/license/branch/push/force/dry-run/verbose/non-interactive, is idempotent, and prints instructions when interactive steps are needed.
