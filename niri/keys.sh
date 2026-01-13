#!/run/current-system/sw/bin/zsh
# buscar atajos de teclado en niri/config.kdl

grep -E "^\s*(Mod|Super|Alt|Shift|Ctrl|Print|XF86)"\
 $HOME/.config/niri/config.kdl |\
 fuzzel --dmenu --prompt " Buscar :>   " --match-mode=exact --no-sort --no-icons -l 30 -w 110 # for version >= 1.11.0-1
