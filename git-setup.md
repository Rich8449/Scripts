I would like to create a shell script that can be used to setup Git on a linux machine. 

- Install Git
- Set the global user.name to "Rich.Taft"
- Set the global user.email to "Rich8449@gmail.com"
- Set the global core.editor to "code --wait"
- Set the global init.defaultBranch to "main"
- Set the global diff and difftool command to "code --wait --diff $LOCAL $REMOTE"
- Generate a SSH key and copy the .pub key to the clipboard
- Open the default browser and go to "https://github.com/settings/keys"
- Prompt the user to add the new SSH key to github 