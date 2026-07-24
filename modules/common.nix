{ config, pkgs, lib, inputs, ... }:

##############################################################################
## COMÚN a todas las máquinas (server, portátil, máquinas de un solo uso).
## Nada de escritorio ni de servicios de server aquí.
##############################################################################
let
  # Color del hostname en el prompt según la máquina, para distinguir de un
  # vistazo dónde estás (útil al saltar por SSH entre hades y korriban).
  # Para una máquina nueva sin entrada aquí, cae en el color por defecto.
  promptHostColor =
    if config.networking.hostName == "Korriban" then "red"
    else if config.networking.hostName == "hades" then "green"
    else "cyan";
in
{
  ##########################################################################
  ## Boot
  ##########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;  # Limita generaciones en el menú de boot
  boot.loader.efi.canTouchEfiVariables = true;

  # Cross-compile para Raspberry Pi 3 (aarch64): permite construir la imagen SD
  # de la rpi desde cualquier equipo x86.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Módulos para lector de tarjetas SD
  boot.kernelModules = [
    "sdhci"
    "sdhci_pci"
  ];

  ##########################################################################
  ## Networking (base)
  ##########################################################################
  networking = {
    networkmanager.enable = true;
    extraHosts = ''
      192.168.1.153 myoboku-mostoles
      192.168.1.180 korriban
    '';
    # Firewall activo en todas las máquinas; cada host/módulo añade sus puertos.
    firewall.enable = true;
  };

  ##########################################################################
  ## Locale / Time
  ##########################################################################
  time.timeZone = "Europe/Madrid";

  i18n.defaultLocale = "es_ES.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_ES.UTF-8";
    LC_IDENTIFICATION = "es_ES.UTF-8";
    LC_MEASUREMENT = "es_ES.UTF-8";
    LC_MONETARY = "es_ES.UTF-8";
    LC_NAME = "es_ES.UTF-8";
    LC_NUMERIC = "es_ES.UTF-8";
    LC_PAPER = "es_ES.UTF-8";
    LC_TELEPHONE = "es_ES.UTF-8";
    LC_TIME = "es_ES.UTF-8";
  };

  console.keyMap = "es";

  ##########################################################################
  ## SSH (acceso remoto a todas las máquinas)
  ##########################################################################
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  ##########################################################################
  ## Users
  ##########################################################################
  users.groups.media = {};  # Grupo compartido para servicios multimedia (usado en server.nix)

  users.users.wizord = {
    isNormalUser = true;
    description = "David López";
    shell = pkgs.zsh;
    homeMode = "711";  # Permite a otros atravesar el directorio home
    # Grupos base; desktop.nix añade los de escritorio (input, video, seat).
    extraGroups = [
      "wheel"
      "networkmanager"
      "storage"
      "plugdev"
      "media"
    ];
  };

  ##########################################################################
  ## Shell (Zsh)
  ##########################################################################
  environment.shells = with pkgs; [ zsh ];

  programs.zsh = {
    enable = true;
    autosuggestions = {
      enable = true;
      # Color explícito a propósito: el default de zsh-autosuggestions es `fg=8`,
      # y en la paleta de kitty color8 = #002b36 (azul oscuro de Solarized), que
      # sobre el fondo #1e1e1e es prácticamente invisible.
      highlightStyle = "fg=#b0b0b0,bold";
    };
    syntaxHighlighting.enable = true;

    shellAliases = {
      cat = "bat -pp";
      vi = "nvim";
      vim = "nvim";
      ls = "eza --long --header";
      top = "btop";
      ".." = "cd ..";
      "..." = "cd ../..";
      df = "dysk";
      ports = "ss -tulnp";
      pbcopy = "wl-copy";
      pbpaste = "wl-paste";
      youtube = "yt-dlp -x --audio-format mp3 --audio-quality 0";
      flakenv = ''echo "use flake" > .envrc && direnv allow'';
      ctop = "docker run --rm -ti --name=ctop --volume /var/run/docker.sock:/var/run/docker.sock:ro quay.io/vektorlab/ctop:latest";
      # Enlaza (o re-enlaza, tras añadir ficheros) los dotfiles con stow
      dots-apply = "cd ~/nix-os/dotfiles && for d in */; do stow -v -t ~ \"$d\"; done && cd -";
      dots-restore = "cd ~/nix-os/dotfiles && for d in */; do stow -v -R -t ~ \"$d\"; done && cd -";
      # wifi-scan → rescan + list
      # wifi-connect RED password "PASSSS"
      # wifi-connect RED --ask
      wifi-scan = "nmcli device wifi rescan && nmcli device wifi list";
      wifi-connect = "nmcli device wifi connect";
    };

    promptInit = ''
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
    '';

    interactiveShellInit = ''
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:*' switch-group ',' '.'
      zstyle ':fzf-tab:*' fzf-bindings 'ctrl-/:toggle-preview'
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=auto $realpath'
      zstyle ':fzf-tab:complete:(nvim|vim|cat|bat|less):*' fzf-preview 'bat --color=always --style=numbers --line-range=:200 $realpath 2>/dev/null || eza -1 --color=always $realpath'
      zstyle ':fzf-tab:complete:git-(add|diff|restore|checkout):*' fzf-preview 'git diff --color=always -- $word | head -200'
      zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
      zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps -p $word -o cmd --no-headers -w -w'

      setopt HIST_EXPIRE_DUPS_FIRST
      setopt HIST_IGNORE_DUPS
      setopt HIST_IGNORE_ALL_DUPS
      setopt HIST_IGNORE_SPACE
      setopt HIST_FIND_NO_DUPS
      setopt HIST_SAVE_NO_DUPS

      # El repo se asume en ~/nix-os del usuario que ejecuta nrs.
      # El atributo del flake es el hostname en minúsculas (Korriban → korriban).
      # sudo -v primero: pide la contraseña ANTES del pipe, para que el
      # prompt no se pierda entre el output de nom.
      nrs() { sudo -v && sudo nixos-rebuild switch --flake ~/nix-os#$(hostname | tr 'A-Z' 'a-z') |& nom; }

      # Igual que nrs, pero avisa al terminar con notificación + sonido.
      # Útil para rebuilds largos (cambio de release, kernel, NVIDIA...).
      nrs-notify() {
        sudo -v || return 1
        sudo nixos-rebuild switch --flake ~/nix-os#$(hostname | tr 'A-Z' 'a-z') |& nom

        # $pipestatus[1] y no $? : con `|& nom` el estado de salida de la
        # función sería el de nom, que siempre es 0 aunque el rebuild falle.
        local estado=$pipestatus[1]
        local sonidos=${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo
        local urgencia icono sonido cuerpo

        if (( estado == 0 )); then
          urgencia=normal;   icono=software-update-available; sonido=complete.oga
          cuerpo="Rebuild completado"
        else
          urgencia=critical; icono=dialog-error;              sonido=dialog-error.oga
          cuerpo="Rebuild FALLÓ (código $estado)"
        fi

        # Solo en máquinas con escritorio: korriban es headless y no tiene
        # libnotify ni pipewire (viven en desktop.nix).
        if [[ -n "$WAYLAND_DISPLAY$DISPLAY" ]] && command -v notify-send >/dev/null; then
          notify-send -u $urgencia -i $icono "NixOS · $(hostname)" "$cuerpo"
          command -v paplay >/dev/null && (paplay $sonidos/$sonido &>/dev/null &)
        fi

        return $estado
      }
      RPROMPT='%F{yellow}%*%f %B%F{${promptHostColor}}%m%f%b'

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
        if 7z x $pass_arg "$1" 2>/dev/null; then
          return 0
        fi
        if [[ "$1" == *.rar || "$1" == *.RAR ]]; then
          echo "7z falló, usando unrar..."
          NIXPKGS_ALLOW_UNFREE=1 nix-shell -p unrar --run "unrar x $pass_arg $1"
        else
          echo "Error: No se pudo extraer '$1'"
          return 1
        fi
      }

      # Resumen del sistema al abrir una shell interactiva
      nitch
    '';

    ohMyZsh = {
      enable = true;
      theme = "agnoster";
      plugins = [
        "git"
        "sudo"
        "colored-man-pages"
      ];
    };
  };

  ##########################################################################
  ## Git (config de sistema → /etc/gitconfig)
  ## Lo personal (user.name / user.email) se queda en ~/.gitconfig
  ##########################################################################
  programs.git = {
    enable = true;
    config = {
      core.pager = "delta";              # diffs/log/show bonitos con delta
      interactive.diffFilter = "delta --color-only";
      delta.navigate = true;             # n / N para saltar entre ficheros
      delta.line-numbers = true;
      pager.branch = false;              # git branch -v sin pager
      pager.tag = false;
    };
  };

  # PATH para scripts gestionados con stow (~/bin)
  environment.shellInit = ''
    export PATH="$HOME/bin:$PATH"
    export DIRENV_CONFIG="/etc/direnv"
  '';

  ##########################################################################
  ## Ratón en la consola de texto
  ##
  ## Permite seleccionar con el ratón y pegar con el botón central en un TTY,
  ## sin depender de tmux. Junto con tmux, hace usable el TTY cuando el
  ## escritorio no arranca — que es justo cuando hace falta.
  ##########################################################################
  services.gpm.enable = true;

  ##########################################################################
  ## direnv (auto-activa flake.nix / shell.nix al hacer cd)
  ##########################################################################
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = false;
  };

  # Oculta el listado de variables que direnv exporta al cargar el entorno
  environment.etc."direnv/direnv.toml".text = ''
    [global]
    hide_env_diff = true
  '';

  ##########################################################################
  ## Fonts
  ##########################################################################
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];

  ##########################################################################
  ## System Packages (CLI base, útil en cualquier máquina)
  ##########################################################################
  environment.systemPackages = with pkgs; [
    ## CLI / Utils
    git
    wget
    curl
    ripgrep
    fd
    eza
    bat
    fzf
    procs
    btop
    htop
    lsof
    stow

    # Archivos y datos
    tree
    jq
    zip
    unzip
    p7zip

    # Git / CLI extra
    gitui
    tig
    delta
    httpie
    xh
    dysk
    nitch
    fastfetch

    # Spellcheck
    hunspell
    hunspellDicts.es_ES

    # Editor
    neovim

    ## System
    nix-output-monitor

    # Rescate: si el escritorio se cae acabas en un TTY pelado, sin paneles ni
    # copiar-pegar. Y una sesión dentro de tmux SOBREVIVE a que muera el
    # compositor (o a un corte de SSH en korriban): se recupera con `tmux
    # attach` en vez de perderla.
    tmux

    ## Desde unstable para tener siempre la última versión
    unstable.claude-code
  ];

  ##########################################################################
  ## Nix
  ##########################################################################
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Sin channels, `nix-shell -p foo` y `nix shell nixpkgs#foo` usan el pin
  # del flake.lock en vez de <nixpkgs> del canal (que ya no existe).
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  programs.nix-ld.enable = true;

  # Garbage collection automático
  # Deduplicación del store: sustituye ficheros idénticos por hardlinks.
  # Vía temporizador systemd y no `auto-optimise-store`, que lo hace durante
  # cada build y las ralentiza. Solo toca /nix/store; jamás /home.
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  # Y además incremental: deduplica cada ruta nueva al crearla, sin escanear
  # el resto del store. Añade algo de latencia a cada build, pero así lo nuevo
  # nunca espera al repaso semanal. Las dos se complementan.
  nix.settings.auto-optimise-store = true;

  # GC por presión de disco: si bajan de 5 GiB libres, el daemon libera
  # hasta llegar a 20 GiB en vez de esperar al GC semanal.
  nix.settings.min-free = 5 * 1024 * 1024 * 1024;
  nix.settings.max-free = 20 * 1024 * 1024 * 1024;

  ##########################################################################
  ## Coredumps acotados
  ##
  ## Un crash de waybar durante el switch a 26.05 escribió 23 GB y consumió
  ## 5,7 GB de RAM antes de que systemd lo matara por timeout. Con estos
  ## topes un proceso grande deja de poder llenar el disco.
  ##########################################################################
  systemd.coredump.settings.Coredump = {
    ProcessSizeMax = "2G";
    ExternalSizeMax = "2G";
    MaxUse = "4G";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  # Overlay para paquetes de unstable, pineado en flake.lock (antes era un
  # fetchTarball sin pin que se movía solo). `system` explícito: en eval pura
  # no existe builtins.currentSystem.
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        inherit (final.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    })
  ];

  ##########################################################################
  ## State version
  ##########################################################################
  system.stateVersion = "25.05";
}
