#!/bin/sh
REPO_URL="git@github.com:DanielUlisses/dotfiles"
REPO_NAME="omarchy-overrides"

is_stow_installed() {
    command -v stow >/dev/null 2>&1
}

if ! is_stow_installed; then
    echo "Stow is not installed. Install it first."
    exit 1
fi

cd ~

# check if the repository is already cloned
if [ -d "$REPO_NAME" ]; then
    echo "Repository $REPO_NAME already cloned."
else
    echo "Cloning repository..."
    git clone "$REPO_URL" ".$REPO_NAME"
fi

#check if the clone was successful
if [ $? -eq 0 ]; then
    echo "Repository cloned successfully."

    # a refactory of stow configuration is needed
        
    # rm -rf ~/.config/starship.toml
    
    # cd ".$REPO_NAME" 
    # git checkout arch
    # echo "Applying stow overrides..."
    # stow starship

else
    echo "Failed to clone repository."
    exit 1
fi
