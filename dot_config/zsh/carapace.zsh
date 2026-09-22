# Targeted Carapace canary: use it for selected slow completers only.
if (( ! $+commands[carapace] )); then
  return 0
fi

typeset binary="${commands[carapace]}"
typeset -a carapace_commands=(npm docker)
for command_name in "${carapace_commands[@]}"; do
  typeset cache="${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/carapace-${command_name}.zsh"
  if [[ ! -r "${cache}" || "${binary}" -nt "${cache}" ]]; then
    typeset cache_tmp="${cache}.new.$$"
    if mkdir -p -- "${cache:h}" &&
       command carapace "${command_name}" zsh >| "${cache_tmp}" &&
       [[ -s "${cache_tmp}" ]] &&
       mv -f -- "${cache_tmp}" "${cache}"; then
      :
    else
      rm -f -- "${cache_tmp}"
      print -ru2 -- "zsh: failed to generate Carapace ${command_name} completion"
      return 1
    fi
  fi

  source "${cache}" || return 1
done
unset binary carapace_commands command_name cache cache_tmp
