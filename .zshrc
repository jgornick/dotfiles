# zmodload zsh/zprof

# *******************************************************************************
# Development Environment Configuration
# *******************************************************************************
# Copy and paste this entire block into your ~/.(bash|zsh)rc file.
# If you need to update it later, simply replace the entire block with a new one.
# *******************************************************************************

# Initialize (home)brew
if [ -z ${HOMEBREW_PREFIX+x} ]; then
  export HOMEBREW_PREFIX=$([[ -d "/opt/homebrew" ]] && echo "/opt/homebrew" || echo "/usr/local")
  eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
fi

#
# Set Development Tooling Environment Variables
#

# Set the nvm/node/npm version and paths
export NVM_DIR="${NVM_DIR:-"${HOME}/.nvm"}"
export NVM_INSTALL_DIR="${NVM_INSTALL_DIR:-"${HOMEBREW_PREFIX}/opt/nvm"}"
export NODE_OPTIONS="${NODE_OPTIONS} --max_old_space_size=4096"

# Set then npm/yarn auth ident
export NODE_AUTH_TOKEN="$(cat ${HOME}/.npmrc 2>/dev/null | grep -o '_authToken=.*' -m 1 | sed 's/_authToken=//g')"
export YARN_NPM_AUTH_IDENT="${NODE_AUTH_TOKEN}"
# For classic version of yarn as npm9_ doesn't support _auth in npmrc
export npm_config__auth="${NODE_AUTH_TOKEN}"

# Set the rbenv/ruby version and paths
export RBENV_ROOT="${RBENV_ROOT:-"${HOME}/.rbenv"}"

# Set the pyenv/python version and paths
export PYENV_ROOT="${PYENV_ROOT:-"${HOME}/.pyenv"}"

# Set sdkman dir
export SDKMAN_DIR="${SDKMAN_DIR:-"${HOME}/.sdkman"}"

# Set Android paths
export ANDROID_HOME="${ANDROID_HOME:-"${HOME}/Library/Android/sdk"}"
export ANDROID_SDK_ROOT="${ANDROID_HOME}"
export PATH="${ANDROID_HOME}/platform-tools/:${PATH}"
export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin/:${PATH}"
export PATH="${ANDROID_HOME}/emulator:${PATH}"

# Set the gradle path
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-"${HOME}/.gradle"}"

# Set the default iOS simulator name
export IOS_SIMULATOR_NAME="iPhone 16 - iOS 18.6"

# Set the default Android emulator name
export ANDROID_AVD_NAME="--pixel_7_api_34"

#
# Initialize Development Tooling
#

# Initialize nvm
if ! which nvm > /dev/null; then
  if [ -s "${NVM_INSTALL_DIR}/nvm.sh" ]; then
    source "${NVM_INSTALL_DIR}/nvm.sh" --no-use
    nvm use default > /dev/null
  fi
fi

# Initialize rbenv
if which rbenv > /dev/null; then
  eval "$(rbenv init -)"
fi

# Initialize pyenv
if which pyenv > /dev/null; then
  eval "$(pyenv init -)"
fi

# Initialize sdkman
if [[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]]; then
  source "${SDKMAN_DIR}/bin/sdkman-init.sh"
fi

# *******************************************************************************
# END OF Development Environment Configuration
# *******************************************************************************
# Remember: To update this configuration in the future, simply replace this
# entire block (from the top comment to this bottom comment) with the new one.
# *******************************************************************************

# User configuration

[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"

export EDITOR="code --wait"

export XDG_CONFIG_HOME="${HOME}/.config"

export LS_COLORS=$(vivid generate catppuccin-mocha)

export AUTOENV_ENV_FILENAME=.autoenv
export AUTOENV_ENV_LEAVE_FILENAME=.autoenv.leave
export AUTOENV_ENABLE_LEAVE=yes
export AUTOENV_ASSUME_YES=yes

# initialize antidote plugins statically with ${ZDOTDIR:-~}/.zsh_plugins.txt
source /opt/homebrew/opt/antidote/share/antidote/antidote.zsh
antidote load

source $(brew --prefix autoenv)/activate.sh

alias ..='cd ../'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv}'
alias ls='ls -lAh --color'

eval "$(starship init zsh)"

# zprof