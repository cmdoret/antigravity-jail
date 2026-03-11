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
      
      # Determine browser at eval time (Requires --impure)
      hostBrowser = let 
        envBrowser = builtins.getEnv "BROWSER";
      in if envBrowser != "" then envBrowser else "xdg-open";

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
          xdg-utils 
        ];
      };

    in {
      packages.${system}.default = jail "antigravity" "${antigravity}/bin/antigravity" [
        cs.gui
        cs.xwayland
        cs.gpu
        cs.network
        
        # --- URL Forwarding ---
        cs.open-urls-in-browser
        (cs.set-env "BROWSER" hostBrowser)

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
        # Force the sandbox to use our custom toolset as the primary system bin
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

        (cs.rw-bind (cs.noescape "~/.config/Antigravity") (cs.noescape "~/.config/Antigravity"))
        (cs.rw-bind (cs.noescape "~/.antigravity") (cs.noescape "~/.antigravity"))
        (cs.rw-bind (cs.noescape "~/.gemini") (cs.noescape "~/.gemini"))

        # --- Dynamic Arguments ---
        (cs.add-runtime ''
          for arg in "$@"; do
            if [ -e "$arg" ]; then
              full_path=$(readlink -f "$arg")
              RUNTIME_ARGS+=(--bind "$full_path" "$full_path")
            fi
          done
        '')

        (cs.set-env "XDG_CONFIG_HOME" (cs.noescape "~/.config"))
        (cs.set-env "NIXOS_OZONE_WL" "1")
      ];

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/antigravity";
      };
    };
}
