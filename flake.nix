{
  description = "Sandboxed Antigravity editor - Final Corrected PATH";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    antigravity-src.url = "github:fdiblen/antigravity-nix";
    jail-nix.url = "github:MohrJonas/jail.nix";
  };

  outputs = { self, nixpkgs, antigravity-src, jail-nix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      jail = jail-nix.lib.init pkgs;
      cs = jail.combinators;

      antigravity = antigravity-src.packages.${system}.default;
      
      # Consolidated toolset for agents and CLI utilities
      agentEnv = pkgs.buildEnv {
        name = "antigravity-agent-tools";
        paths = with pkgs; [
          bashInteractive
          git
          coreutils
          curl
          gnugrep
          gnused
          nix
        ];
      };

      antigravity-wrapped = pkgs.writeShellScriptBin "antigravity-wrapped" ''
              ${antigravity}/bin/antigravity --no-sandbox "$@"
            '';

    in {
      packages.${system}.default = jail "antigravity" "${antigravity-wrapped}/bin/antigravity-wrapped" [
        cs.gui
        cs.xwayland
        cs.gpu
        cs.network
        
        # --- URL Forwarding ---
        cs.open-urls-in-browser
        (cs.set-env "BROWSER" "browserchannel")

        # --- D-Bus Access ---
        (cs.dbus {
          talk = [ 
            "org.freedesktop.DBus" 
            "org.freedesktop.Notifications" 
            "org.freedesktop.secrets"
            "org.freedesktop.portal.Desktop"
          ];
        })

        # --- PATH/Tooling Fix ---
        (cs.bind-pkg "/app-tools" agentEnv)
        (cs.add-path "/app-tools/bin")
        (cs.set-env "SHELL" "/app-tools/bin/bash")

        # --- System/Profile Persistence ---
        (cs.ro-bind "/etc/profiles/per-user/cmdoret" "/etc/profiles/per-user/cmdoret")

        (cs.add-runtime ''
          mkdir -p ~/.config/Antigravity
          mkdir -p ~/.antigravity
          mkdir -p ~/.gemini
        '')

        # --- Antigravity Data Persistence ---
        (cs.rw-bind (cs.noescape "~/.config/Antigravity") (cs.noescape "~/.config/Antigravity"))
        (cs.rw-bind (cs.noescape "~/.antigravity") (cs.noescape "~/.antigravity"))
        (cs.rw-bind (cs.noescape "~/.gemini") (cs.noescape "~/.gemini"))

        # --- Bind mounts based on arguments ---
        (cs.add-runtime ''
          for arg in "$@"; do
            if [ -e "$arg" ]; then
              full_path=$(readlink -f "$arg")
              RUNTIME_ARGS+=(--bind "$full_path" "$full_path")
              # Shadow .env and other sensitive files
              RUNTIME_ARGS+=(--bind /dev/null "$full_path/.env")
            fi
          done
        '')

        (cs.set-env "XDG_CONFIG_HOME" (cs.noescape "~/.config"))
        (cs.set-env "NIXOS_OZONE_WL" "1")
      ];

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/antigravity";
        env = {
          BROWSER = "firefox";
        };
      };
    };
}
