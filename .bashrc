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

# Enable some Bash features when possible:
# * `autocd`: `**/qux` will enter `./foo/bar/baz/qux`
# * `cdspell`: Autocorrect typos in path names when using `cd`
# * `checkwinsize`: check the window size after each command and, if necessary,
#   update the values of LINES and COLUMNS.
# * `globstar`: Recursive globbing, e.g. `echo **/*.txt`
# * `histappend`: Append to the Bash history file, rather than overwriting it
# * `nocaseglob`: Case-insensitive globbing (used in pathname expansion)
for option in autocd cdspell checkwinsize globstar histappend nocaseglob; do
    shopt -s "$option" 2> /dev/null
done;

if [ -f "${HOME}/.bash_exports" ]; then
    . "${HOME}/.bash_exports"
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

# Load NVM
[ -s "${NVM_INSTALL_DIR}/nvm.sh" ] && . "${NVM_INSTALL_DIR}/nvm.sh"
nvm alias default "${NODE_VERSION}"

# Load YVM
[ -r "${YVM_INSTALL_DIR}/yvm.sh" ] && . "${YVM_INSTALL_DIR}/yvm.sh"
yvm alias default "${YARN_VERSION}"

# Load rbenv
if which rbenv > /dev/null; then
  eval "$(rbenv init -)";
  rbenv global "${RUBY_VERSION}"
  rbenv local "${RUBY_VERSION}"
  rbenv shell "${RUBY_VERSION}"
fi

# Load pyenv
if which pyenv > /dev/null; then
  eval "$(pyenv init -)";
  pyenv global "${PYTHON_VERSION}"
  pyenv local "${PYTHON_VERSION}"
  pyenv shell "${PYTHON_VERSION}"
fi

if [ -f "${HOME}/.bash_completions" ]; then
  . "${HOME}/.bash_completions"
fi

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="${HOME}/.sdkman"
[[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR}/bin/sdkman-init.sh"
