# Add ~/bin to PATH
export PATH="$HOME/bin:$PATH"

ZSH_THEME="robbyrussell"
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#888888'


if [ -n "${commands[fzf-share]}" ]; then
  source "$(fzf-share)/key-bindings.zsh"
  source "$(fzf-share)/completion.zsh"
fi

alias cat='bat -pp'
alias vi='nvim'
alias vim='nvim'
alias ls='eza --long --header'
alias top='btop'
alias ctop='docker run --rm -ti  --name=ctop  --volume /var/run/docker.sock:/var/run/docker.sock:ro  quay.io/vektorlab/ctop:latest'
alias youtube="yt-dlp -x --audio-format mp3 --audio-quality 0" 


# wifi
# nmcli device wifi rescan
# nmcli device wifi list
# nmcli device wifi connect RED password "PASSSS"
# nmcli device wifi connect RED --ask

## HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# Función para descomprimir archivos
# Uso: extract archivo.zip [contraseña]
extract() {
  if [[ -z "$1" ]]; then
    echo "Uso: extract <archivo> [contraseña]"
    return 1
  fi

  if [[ ! -f "$1" ]]; then
    echo "Error: '$1' no existe"
    return 1
  fi

  local pass_arg=""
  [[ -n "$2" ]] && pass_arg="-p$2"

  # Intentar con 7z primero
  if 7z x $pass_arg "$1" 2>/dev/null; then
    return 0
  fi

  # Si falla y es RAR, usar unrar con nix-shell
  if [[ "$1" == *.rar || "$1" == *.RAR ]]; then
    echo "7z falló, usando unrar..."
    if [[ -n "$2" ]]; then
      NIXPKGS_ALLOW_UNFREE=1 nix-shell -p unrar --run "unrar x -p$2 '$1'"
    else
      NIXPKGS_ALLOW_UNFREE=1 nix-shell -p unrar --run "unrar x '$1'"
    fi
  else
    echo "Error: No se pudo extraer '$1'"
    return 1
  fi
}

nitch
