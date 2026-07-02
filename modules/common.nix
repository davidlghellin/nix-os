{ config, pkgs, lib, ... }:

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
  boot.kernelModules = [ "sdhci" "sdhci_pci" ];

  ##########################################################################
  ## Networking (base)
  ##########################################################################
  networking = {
    networkmanager.enable = true;
    extraHosts = ''
      192.168.1.153 myoboku-mostoles
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

      nrs() { sudo nixos-rebuild switch --upgrade |& nom; }
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
    '';

    ohMyZsh = {
      enable = true;
      theme = "agnoster";
      plugins = [ "git" "sudo" "colored-man-pages" ];
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
    git wget curl
    ripgrep fd eza bat
    fzf procs btop htop
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

    ## Desde unstable para tener siempre la última versión
    unstable.claude-code
  ];

  ##########################################################################
  ## Nix
  ##########################################################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.nix-ld.enable = true;

  # Garbage collection automático
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  # Overlay para paquetes de unstable
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
        config.allowUnfree = true;
      };
    })
  ];

  ##########################################################################
  ## State version
  ##########################################################################
  system.stateVersion = "25.05";
}
