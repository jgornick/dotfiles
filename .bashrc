# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

if [ -z "$STARTED_SCREEN" ] && [ -n "$SSH_TTY" ]
then
  case $- in
    (*i*)
      STARTED_SCREEN=1; export STARTED_SCREEN
      screen -D -R -S default  ||
        echo "Screen failed! continuing with normal bash startup"
  esac
fi

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# Append to the Bash history file, rather than overwriting it
shopt -s histappend

# Autocorrect typos in path names when using `cd`
shopt -s cdspell

# Enable some Bash 4 features when possible:
# * `autocd`, e.g. `**/qux` will enter `./foo/bar/baz/qux`
# * Recursive globbing, e.g. `echo **/*.txt`
for option in autocd globstar; do
    shopt -s "$option" 2> /dev/null
done;

if [ -f "${HOME}/.bash_exports" ]; then
    . "${HOME}/.bash_exports"
fi

if [ -f "${BASH_IT}/bash_it.sh" ]; then
  . "${BASH_IT}/bash_it.sh"
fi

if [ -f "${HOME}/.bash_prompt" ]; then
    . "${HOME}/.bash_prompt"
fi

if [ -f "${HOME}/.bash_aliases" ]; then
    . "${HOME}/.bash_aliases"
fi

if [ -f "${HOME}/.bash_functions" ]; then
    . "${HOME}/.bash_functions"
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if [ -f "${HOME}/.bash_completions" ]; then
    . "${HOME}/.bash_completions"
fi


# Load NVM
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[[ -r $NVM_DIR/bash_completion ]] && . $NVM_DIR/bash_completion

# Load GVM
[[ -s "${HOME}/.gvm/scripts/gvm" ]] && source "${HOME}/.gvm/scripts/gvm"

# Load rbenv
if which rbenv > /dev/null; then
  eval "$(rbenv init -)";
  rbenv global 2.5.0
  rbenv local 2.5.0
  rbenv shell 2.5.0
fi

# Load pyenv
if which pyenv > /dev/null; then
  eval "$(pyenv init -)";
  pyenv global 3.5.2
  pyenv local 3.5.2
  pyenv shell 3.5.2 2.7.14
fi

# Load Homebrew Bash Completions
if [ -f $(brew --prefix)/etc/bash_completion ]; then
    . $(brew --prefix)/etc/bash_completion
fi

# Lunchy Completion
LUNCHY_DIR=$(dirname `gem which lunchy`)/../extras
if [ -f $LUNCHY_DIR/lunchy-completion.bash ]; then
 . $LUNCHY_DIR/lunchy-completion.bash
fi

# AWS CLI Completion
complete -C aws_completer aws

# NPM Completion
npm completion > /usr/local/etc/bash_completion.d/npm
