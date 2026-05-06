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

Generate a robust POSIX-compatible Bash script named git-setup.sh for Linux that:
- Installs Git (use apt-get install git; requires sudo if needed).
- Sets global git config: user.name "Rich.Taft", user.email "Rich8449@gmail.com", core.editor "code --wait", init.defaultBranch "main".
- Sets global difftool and diff commands to use VS Code: "code --wait --diff $LOCAL $REMOTE".
- Creates an SSH key (default ed25519) at ~/.ssh/id_ed25519 unless one exists; supports --type (ed25519|rsa), --bits for rsa, and optional --passphrase.
- Copies the public key to clipboard using available tool (try wl-copy, then xclip, then xsel) and, if none available, prints the key to stdout.
- Opens the GitHub SSH keys page (https://github.com/settings/keys) with xdg-open (or prints the URL if no GUI).
- Prompts the user to add the key to GitHub and offers to test SSH with ssh -T git@github.com (optional confirmation).
- Is idempotent: it checks existing git config and existing SSH keys and avoids overwriting unless --force is provided.
- Provides --dry-run and --verbose modes, prints helpful messages, enforces SSH private key permissions (600), and exits with non-zero on errors.
- Include usage/help output and short inline comments.