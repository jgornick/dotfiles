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

# Load NVM
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

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

if [ -f "${HOME}/.bash_completions" ]; then
    . "${HOME}/.bash_completions"
fi

export COMP_WORDBREAKS=${COMP_WORDBREAKS//:}