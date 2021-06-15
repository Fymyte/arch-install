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
echo $real_user

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
  "

AUR_PACKAGES="\
  polybar \
  nerd-fonts-mononoki \
  lightdm-webkit-theme-aether \
  brave-bin \
  "

as_user() {
  sudo -u $real_user "$@"
}

ask_confirmation() {
  read -p "Do you want to continue ? [y/n] " -n 1 -r
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
    echo_warning "Stopping"
    exit 1
    return
  fi
}

echo_info() {
  echo -e -n "\e[1;32m"
  echo -n $@
  echo -e "\e[0m"
}

echo_warning() {
  echo -e -n "\e[38;5;214m"
  echo -n $@
  echo -e "\e[0m"
}

echo_error() {
  echo -e -n "\e[38;5;160m"
  echo -n $@
  echo -e "\e[0m"
}

install_packages() {
  cd $INSTALL_DIR
  echo_info "The following packages will be installed:"
  for package in $PACKAGES; do 
    echo $package
  done

  ask_exit

  echo 'pacman --noconfirm -S $PACKAGES > /dev/null'
}

install_aur_packages() {
  cd $INSTALL_DIR
  echo_info "Paru will be installed"

  ask_exit

  as_user git clone https://aur.archlinux.org/paru.git
  cd paru
  # build with all cpu cores
  export MAKEFLAGS="-j$(nproc)"
  echo as_user makepkg -si

  echo_info "The following packages will be installed:"
  for package in $AUR_PACKAGES; do 
    echo $package
  done

  ask_confirmation
  [ $RETURN = 0 ] && echo as_user paru -p -S $AUR_PACKAGES
}

# Here is the description of the function
install_lightdm() {
  systemctl enable lightdm

  echo_info "Modify lightdm config now ?"

  ask_confirmation
  [ $RETURN = 0 ] && nvim /etc/lightdm/lightdm.conf 
}

install_oh_my_zsh() {
  cd $INSTALL_DIR
  echo_info "Oh-my-zsh will be installed"
  
  ask_confirmation
  if [ $RETURN = 0 ]; then
    [[ ! -d oh-my-zsh ]] && as_user mkdir oh-my-zsh

    as_user echo "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >> oh-my-zsh/install.sh

    cd oh-my-zsh
    as_user chmod +x install.sh
    as_user RUNZSH=no bash ./install.sh

    echo_info "Installing own config"
    as_user git clone git@github.com:Fymyte/zsh-config.git
    cd zsh-config
    as_user bash install.sh
  fi
}

install_ssh() {
  echo_info "Creating ssh key-pair"

  ask_confirmation
  [ $RETURN = 0 ] && ssh-keygen -b 4096
}

main() {
  echo_info "Installing packages ..."
  install_packages
  install_aur_packages

  echo_info "Installing lightdm ..."
  install_lightdm

  echo_info "Installing configuration files ..."
  install_oh_my_zsh
  
  install_ssh
}

main
  
