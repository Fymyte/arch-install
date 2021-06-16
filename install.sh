#!/bin/bash

if ! [ $(id -u) = 0 ]; then
  echo "The script needs to be run as root." >&2
  exit 1
fi
if [ $SUDO_USER ]; then
  real_user=$SUDO_USER
else
  real_user=$(whoami)
fi

HOME_DIR=$(runuser - fymyte -c 'echo $HOME')

INSTALL_DIR=$(pwd)

PACKAGES=" \
  base-devel \
  alacritty \
  neovim \
  firefox \
  git \
  i3-gaps \
  networkmanager \
  openssh \
  pulseaudio \
  rofi \
  sudo \
  tree \
  xorg \
  zsh \
  htop \
  grub \
  nitrogen \
  npm \
  picom \
  bat \
  exa \
  xclip \
  lightdm \
  lightdm-webkit2-greeter \
  xautolock \
  pavucontrol \
  bc \
  imagemagick \
  "

AUR_PACKAGES="\
  polybar \
  nerd-fonts-mononoki \
  lightdm-webkit-theme-aether \
  brave-bin \
  i3lock-color \
  "

as_user() {
  sudo -u $real_user "$@"
}

ask_confirmation() {
  read -p "$1 [y/n] " -n 1 -r
  echo
  if ! [[ $REPLY =~ [Yy]$ ]]; then
    RETURN=1
    return
  fi
  RETURN=0
}

ask_exit() {
  read -p "Do you want to continue ? [y/n] " -n 1 -r
  echo
  if ! [[ $REPLY =~ [Yy]$ ]]; then
    echof act "Stopping"
    exit 1
    return
  fi
}

echof() {
	local prefix="$1"
	local message="$2"

  local flags="-e"

	case "$prefix" in
		header) msgpfx="[\e[1;95mm\e[m]";;
		info) msgpfx="[\e[1;97m=\e[m]";;
		act) flags="-en";msgpfx="[\e[1;92m*\e[m]";;
		ok) msgpfx="[\e[1;93m+\e[m]";;
		error) msgpfx="[\e[1;91m!\e[m]";;
		*) msgpfx="";;
	esac
	echo $flags "$msgpfx $message "
}

install_packages() {
  cd $INSTALL_DIR
  echof act "Installing packages from arch repo ..."
  echo pacman --noconfirm -S $PACKAGES > /dev/null
  echo Done
}

install_aur_packages() {
  cd $INSTALL_DIR
  echof act "Installing paru ..."

  as_user git clone --quiet https://aur.archlinux.org/paru.git
  cd paru
  # build with all cpu cores
  export MAKEFLAGS="-j$(nproc)"
  echo as_user makepkg -si
  echo Done

  echof act "Installing packages from AUR ..."

  echo as_user paru --useask --noconfirm -S $AUR_PACKAGES >/dev/null
  echo Done
}

# Here is the description of the function
install_lightdm() {
  systemctl enable lightdm

  ask_confirmation "Edit lightdm config now ?"
  [ $RETURN = 0 ] && nvim /etc/lightdm/lightdm.conf 
}

install_oh_my_zsh() {
  cd $INSTALL_DIR
  
  ask_confirmation "Install Oh-my-zsh now ?"
  if [ $RETURN = 0 ]; then
    [[ ! -d oh-my-zsh ]] && as_user mkdir oh-my-zsh

    as_user echo "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >> oh-my-zsh/install.sh

    cd oh-my-zsh
    as_user chmod +x install.sh
    as_user RUNZSH=no bash ./install.sh > /dev/null

    echof info "Installing own config"
    as_user git clone git@github.com:Fymyte/zsh-config.git
    cd zsh-config
    as_user bash install.sh
  fi
}

install_config_files() {
  echof act "Fetching config files from github ..."
  cd $HOME_DIR/.config
  [[ ! -d .git ]] && as_user git init
  [[ $(git remote | grep origin) ]] || as_user git remote add origin git@github.com:Fymyte/configs.git
  as_user git pull --quiet origin main --recurse-submodules
  echo Done

  echof act "Updating remote from submodules ..."

  for dir in *; do
    [[ ! -d $dir ]] && continue
    pushd $dir > /dev/null
    if [[ -d .git ]]; then
      as_user git pull --quiet origin main
    fi
    popd > /dev/null
  done
  echo Done
}

install_ssh() {
  echof info "Creating ssh key-pair"

  ask_confirmation
  [ $RETURN = 0 ] && ssh-keygen -b 4096
}

main() {
  echof info "Installing packages ..."
  install_packages
  install_aur_packages

  echof info "Installing lightdm ..."
  install_lightdm

  echof info "Installing configuration files ..."
  install_oh_my_zsh
  install_config_files

  install_ssh
}

main
  
