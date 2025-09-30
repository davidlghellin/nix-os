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
alias top='bpytop'
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

nitch
