#!/bin/bash

clear
echo -e "\n   ************************************************"
echo -e "\n\tWELCOME TO NASHVILLE SOFTWARE SCHOOL\n"
echo -e "   ************************************************"
echo -e "\nWe are going to try to install as much software, and make as many"
echo -e "configurations as we possibly can in an automated script. If this"
echo -e "If this stops at any point, and you don't see a 'SUCCESS' message"
echo -e "please notify an instructor for assistance.\n\n"
echo "Enter your full name exactly as you entered it on Github settings:"
read -p "> " STUDENT_NAME
echo -e "\nEnter email address you used for Github:"
read -p "> " EMAIL_ADDRESS
echo -e "\nEnter your Github account name:"
read -p "> " GH_USERNAME
echo -e "\nEnter personal access token for Github (it will be invisible because security):"
read -s -p "> " GH_PWD


# Set up standard directories
echo -e "\n\nCreating some directories that you will need..."
DIRS=("$HOME/workspace" "$HOME/.ssh" "$HOME/.config" "$HOME/.npm-packages")
for DIR in "${DIRS[@]}"; do
  if [ -d "$DIR" ]; then
    echo "$DIR already exists"
  else
    mkdir -p $DIR
  fi
done

function installxcode() {
  # Install XCode Command line tools - May take awhile so run this one last
  echo -e "\n\nMaking sure you have Command line tools installed"
  xcode-select --install >>/dev/null
}

function installbrew() {
  if ! type brew &>/dev/null; then
    echo -e "\n\n\n\n Installing Homebrew..."

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    echo 'eval $(/opt/homebrew/bin/brew shellenv)' >>/Users/$USER/.zprofile
    eval $(/opt/homebrew/bin/brew shellenv)
  fi

  echo -e "\n\nInstalling git and terminal customization tools..."
  brew install -q git tig zsh zsh-completions >>/dev/null
}

function setupgit() {
  # Set up git and github - Needs to be below the brew install
  PUBLIC_KEY=$HOME/.ssh/id_nss.pub
  if [ ! -f "$PUBLIC_KEY" ]; then
    echo -e "\n\nGenerating an SSH key so you can backup your code to Github..."
    echo "yes" | ssh-keygen -t ed25519 -f ~/.ssh/id_nss -N "" -b 4096 -C $EMAIL_ADDRESS
    eval $(ssh-agent)
    ssh-add ~/.ssh/id_nss
    echo -e "Host *\n\tAddKeysToAgent yes\n\tIdentityFile ~/.ssh/id_nss" >>~/.ssh/config
  fi

  echo -e "\n\nAdding your SSH key to your Github account..."
  PUBLIC_KEY_CONTENT=$(cat $HOME/.ssh/id_nss.pub)

  STATUS_CODE=$(curl \
    -s \
    --write-out %{http_code} \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GH_PWD" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/user/keys \
    -d "{\"key\":\"$PUBLIC_KEY_CONTENT\",\"title\":\"NSS Automated Key\"}" >>/dev/null)

  if [ ! $STATUS_CODE == 200 ]; then
    echo -e "POST for SSH key returned status code $STATUS_CODE" >>progress.log
  fi

  git config --global user.name "$STUDENT_NAME" >>/dev/null
  git config --global user.email "$EMAIL_ADDRESS" >>/dev/null
  # End Git set up

}

function showhidden() {
  echo -e "\n\nConfiguring the Finder application to show hidden files..."
  defaults write com.apple.finder AppleShowAllFiles YES
  killall Finder >>/dev/null
}

function setupzsh() {
  # Set up Zsh
  current_shell=$(echo $SHELL)
  if [ $current_shell == "/bin/bash" ]; then
    echo -e "\n\n\n"
    echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    echo "@@                                                        @@"
    echo "@@   Change Needed: Switch to zsh                         @@"
    echo "@@   This change might require your computer password.    @@"
    echo "@@                                                        @@"
    echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    ZSH_PATH=$(which zsh >>/dev/null)
    if [ $? != 0 ]; then
      echo "FAILED: zsh not found. Skipping chsh" >>error.log
    else
      SWITCHED=$(chsh -s $ZSH_PATH >>/dev/null)
      if [ $? != 0 ]; then
        echo "FAILED: Could not chsh to zsh" >>error.log
      else
        new_shell=$(echo $SHELL)
        if [ $new_shell != "$ZSH_PATH" ]; then
          # The rest of the installs will not work if zsh is not the default shell
          echo "FAILED: Shell did not change to zsh." >>error.log
          exit 1
        fi
      fi
    fi

  else
    echo "Already using zsh as default shell"
  fi

  ZSH_FOLDER=$HOME/.oh-my-zsh
  if [ ! -d "$FOLDER" ]; then
    sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" >>/dev/null
  fi

  if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  fi
  if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  fi

  if grep -q "(zsh-autosuggestions zsh-syntax-highlighting" ~/.zshrc; then
    echo "Text already exists"
  else
    sed -i'.original' 's#^plugins=(#plugins=(zsh-autosuggestions zsh-syntax-highlighting #' $HOME/.zshrc
  fi

}

function installnode() {
  # Install Node - Needs to be below zsh set up because of the shell environment
  if ! type nvm &>/dev/null; then
    echo -e "Installing Node Version Manager..."

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash >>/dev/null
    source ~/.zshrc &>zsh-reload.log
  fi

  nvm install --lts >>/dev/null
  nvm use --lts >>/dev/null

  echo -e "\n\nInstalling a web server and a simple API server..."
  npm config set prefix $HOME/.npm-packages
  echo 'export PATH="$PATH:$HOME/.npm-packages/bin"' >>~/.zshrc
  source ~/.zshrc &>zsh-reload.log
  npm i -g serve json-server json >>/dev/null
}


spinner="/-\|"

installbrew
installnode

showhidden &
setupgit &
setupzsh &

installxcode &
while ps -p $! > /dev/null; do
    # Print the next character in the spinner sequence
    printf "\b${spinner:0:1} Installing Xcode..."
    # Rotate the spinner sequence
    spinner="${spinner:1}${spinner:0:1}"
    # Wait for a short time
    sleep 0.5
done

wait

# BEGIN verification
echo -e "\n\n\n\n"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@                                                             @@"
echo "@@                   VERIFYING INSTALLS                        @@"
echo "@@                                                             @@"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo ""

VERIFIED=1

if ! type brew &>/dev/null; then
  echo "Brew not installed"
  VERIFIED=0
else
  echo "Brew installed"
fi

if ! type node &>/dev/null; then
  echo "Node not installed"
  VERIFIED=0
else
  echo "Node installed"
fi

if ! type nvm &>/dev/null; then
  echo "nvm not installed"
  VERIFIED=0
else
  echo "nvm installed"
fi

if ! type serve &>/dev/null; then
  echo "serve not installed"
  VERIFIED=0
else
  echo "serve installed"
fi

if ! type json-server &>/dev/null; then
  echo "json-server not installed"
  VERIFIED=0
else
  echo "json-server installed"
fi
#END verification

echo -e "\n\n\n\n"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@                                                             @@"
echo "@@                   S U C C E S S !!!                         @@"
echo "@@                                                             @@"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "\n\nRun the following command to finalize the installation"
echo -e "\nsource ~/.zshrc"
