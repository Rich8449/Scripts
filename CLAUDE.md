# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

A collection of utility shell scripts for developer environment setup. Each script has a companion `.md` file containing the original AI prompt used to generate it.

| Script | Companion Prompt | Purpose |
|--------|-----------------|---------|
| `git-setup.sh` | `git-setup.md` | Install git, configure globals, generate SSH key, register with GitHub |
| `new-python-project.sh` | `new-python-project.md` | Scaffold a modern Python project (src layout, venv, pytest, black, mypy, pre-commit) |
| *(missing)* | `git-create-repo.md` | Create a GitHub repo via `gh` or REST API — **script not yet generated** |

## Running the Scripts

```bash
# Git environment setup (requires apt-get / sudo)
./git-setup.sh [--type ed25519|rsa] [--key-path PATH] [--force] [--dry-run] [--verbose]

# New Python project scaffold
./new-python-project.sh PROJECT_NAME [-d DESCRIPTION] [-a AUTHOR] [-e EMAIL] \
  [-p PYTHON_VERSION] [-l LICENSE] [--deps "pkg1,pkg2"] [-f]

# Both scripts support --dry-run and --help
./git-setup.sh --help
./new-python-project.sh --help
```

## Conventions

**Script patterns:**
- Both scripts use `set -euo pipefail` (or `set -o errexit/pipefail/nounset`) — errors abort immediately.
- `--dry-run` mode prints intended actions without executing them; `--verbose` adds debug logging.
- Destructive operations (overwriting keys, removing directories) require `--force` and create timestamped backups where applicable.
- Author defaults hardcoded: `user.name="Rich.Taft"`, `user.email="Rich8449@gmail.com"`.

**Companion `.md` files** are AI prompts, not documentation — they record *how* each script was generated so it can be regenerated or extended with the same prompt context.

**`git-create-repo.sh` is pending.** The full spec lives in `git-create-repo.md`. When creating it, prefer `gh` CLI over raw `curl`/`GITHUB_TOKEN`, and implement all flags listed in that spec.

## Generated Python Project Structure

`new-python-project.sh` produces projects with:
- `src/<name>/` package layout (not flat)
- `pyproject.toml` using `hatchling` build backend
- Dev tools: `pytest`, `black`, `isort`, `flake8`, `mypy`, `ruff`, `pre-commit`
- Pre-commit config at `.pre-commit-config.yaml` covering black, isort, flake8, mypy, ruff
- Version defined in `src/<name>/__init__.py`, read by hatch via `[tool.hatch.version]`
