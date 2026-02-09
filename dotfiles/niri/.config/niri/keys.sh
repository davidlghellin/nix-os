#!/run/current-system/sw/bin/zsh
# buscar atajos de teclado en niri/config.kdl

grep -E "^\s*(Mod|Super|Alt|Shift|Ctrl|Print|XF86)"\
 $HOME/.config/niri/config.kdl |\
 rofi -dmenu -i -p "Buscar tecla"
