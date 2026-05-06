# git-setup.sh

## Prompt

I would like to create a shell script that can be used to setup Git on a linux machine.

- Install Git
- Set the global user.name to "Rich8449"
- Set the global user.email to "Rich8449@gmail.com"
- Set the global core.editor to "code --wait"
- Set the global init.defaultBranch to "main"
- Set the global diff and difftool command to "code --wait --diff $LOCAL $REMOTE"
- Generate a SSH key and copy the .pub key to the clipboard
- Open the default browser and go to "https://github.com/settings/keys"
- Prompt the user to add the new SSH key to github
- Use `"$@"` directly in `run_cmd` rather than `eval` to avoid command injection
- All filesystem operations (including `mkdir -p`) must be routed through `run_cmd` so `--dry-run` suppresses them
- The SSH test should capture output once and grep against the variable — do not run the SSH command twice
- Guard `xdg-open` on both command availability and a non-empty `$DISPLAY` variable; use `${DISPLAY:-}` to handle the unset case under `nounset`

## Usage

```bash
./git-setup.sh [options]
```

Options:

| Flag | Description | Default |
|------|-------------|---------|
| `--type ed25519\|rsa` | SSH key type | `ed25519` |
| `--bits N` | RSA key bits | `4096` |
| `--passphrase 'p'` | Key passphrase (visible in process list) | none |
| `--key-path PATH` | Path to private key | `~/.ssh/id_ed25519` |
| `--force` | Overwrite existing key/config (backups made) | off |
| `--dry-run` | Print intended actions without executing | off |
| `--verbose` | Print extra debug output | off |
| `-h, --help` | Show help | |

Examples:

```bash
# Default setup (ed25519 key, all defaults)
./git-setup.sh

# RSA key at a custom path, dry run first
./git-setup.sh --type rsa --key-path ~/.ssh/id_github --dry-run

# Force regenerate existing key with a passphrase
./git-setup.sh --force --passphrase 'my passphrase'
```
