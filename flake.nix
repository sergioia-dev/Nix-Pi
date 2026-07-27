{
  description = "Pi agent with declarative configuration (fully isolated) – performance-optimised";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        basePi = pkgs.pi-coding-agent;

        # ------------------------------------------------------------------
        # User-tunable defaults (edit these, not the JSON blocks below)
        # ------------------------------------------------------------------
        defaultProvider = "opencode";
        defaultModel = "deepseek-v4-flash-free";
        theme = "catppuccin-mocha";
        defaultTrust = "always";

        # ------------------------------------------------------------------
        # Extension specs
        # ------------------------------------------------------------------
        extensionSpecs = [
          "npm:opencode-pi@1.1.2"
          "npm:pi-vim@0.14.1"
          "npm:pi-nvim@0.2.4"
          "npm:pi-pixel-header@1.0.2"
          "npm:@sherif-fanous/pi-catppuccin@0.2.0"
          "git:github.com/bwks/pi-planner"
          "npm:pi-web-access@0.13.0"
          "npm:@juicesharp/rpiv-todo@2.1.0"
          "npm:pi-protected-paths@0.1.1"
          "npm:pi-loop-police@1.13.0"
          "npm:pi-adaptive-thinking@0.1.1"
          "npm:pi-open-agents@0.1.12"
          "npm:@tmustier/pi-usage-extension"
          "npm:@firstpick/pi-extension-nixos-wiki-local@0.1.6"
          "npm:pi-env-probe"
        ];

        # ------------------------------------------------------------------
        # npm extensions (built via buildNpmPackage for reproducibility)
        # Requires extensions/package.json and extensions/package-lock.json
        # ------------------------------------------------------------------
        npmExtensions = pkgs.buildNpmPackage {
          pname = "pi-npm-extensions";
          version = "0.0.0";
          src = ./extensions;
          npmDepsHash = "sha256-I+LPNiPW9XgKNcMasq3pkrzwQGitGHda4qwVN+VNpZk=";
          npmFlags = [ "--legacy-peer-deps" ];
          dontNpmBuild = true; # extensions are plain JS, no build step needed
        };

        # ------------------------------------------------------------------
        # git extension: pi-planner (pinned commit for reproducibility)
        # ------------------------------------------------------------------
        gitPiPlanner = pkgs.fetchFromGitHub {
          owner = "bwks";
          repo = "pi-planner";
          rev = "f8b0495d28f8bbb39bcb9efa5879a8b71f52bc30";
          hash = "sha256-fcWsItMAEAonxtJfN2FU/9/TCtYBfeyiMJq0XEW9+to=";
        };

        # ------------------------------------------------------------------
        # Combined: all extensions merged into a single node_modules tree
        # ------------------------------------------------------------------
        allExtensions = pkgs.runCommand "pi-all-extensions" { } ''
          mkdir -p $out/node_modules
          # Copy npm extensions (handle both dirs and files)
          for d in ${npmExtensions}/node_modules/*; do
            cp -r "$d" $out/node_modules/
          done
          # Copy git extension into node_modules structure
          mkdir -p $out/node_modules/pi-planner
          cp -r ${gitPiPlanner}/* $out/node_modules/pi-planner/
        '';

        # ------------------------------------------------------------------
        # Config files – tunables pulled from variables above
        # ------------------------------------------------------------------
        settingsJson = pkgs.writeText "settings.json" (
          builtins.toJSON {
            inherit defaultProvider defaultModel theme;
            defaultProjectTrust = defaultTrust;

            thinkingBudgets = {
              minimal = 4096;
              low = 32768;
              medium = 65536;
              high = 200000;
            };

            hideThinkingBlock = false;
            quietStartup = false;
            editorPaddingX = 3;

            retry = {
              enabled = true;
              maxRetries = 10;
              baseDelayMs = 2000;
              provider = {
                timeoutMs = 86400000;
                maxRetries = 10;
                maxRetryDelayMs = 300000;
              };
            };

            packages = extensionSpecs;
          }
        );

        modelsJsonSrc = builtins.path {
          path = ./models.json;
          name = "models.json";
        };

        keybindingsJsonSrc = builtins.path {
          path = ./keybindings.json;
          name = "keybindings.json";
        };

        # ------------------------------------------------------------------
        # Combined stamp: hash file CONTENTS, not store-path strings
        # ------------------------------------------------------------------
        configStampValue = builtins.hashString "sha256" (
          builtins.readFile settingsJson
          + builtins.readFile modelsJsonSrc
          + builtins.readFile keybindingsJsonSrc
        );

        # ------------------------------------------------------------------
        # Wrapper script – stamp-based, symlinks everywhere, no rm+cp
        # ------------------------------------------------------------------
        piWrapper = pkgs.writeShellScriptBin "pi" ''
          set -e

          PI_PARENT="$HOME/.local/share/pi-nix"
          PI_AGENT_DIR="$PI_PARENT/agent"
          export PI_CODING_AGENT_DIR="$PI_AGENT_DIR"
          export PI_HOME="$PI_AGENT_DIR"
          export PI_SKIP_VERSION_CHECK=1
          export PATH="${pkgs.lib.makeBinPath [ pkgs.nodejs_latest ]}:$PATH"

          mkdir -p "$PI_AGENT_DIR"

          # Ensure ~/.pi symlink points to parent
          if ! test -L "$HOME/.pi" || test "$(readlink "$HOME/.pi")" != "$PI_PARENT"; then
            if test -e "$HOME/.pi"; then
              mv "$HOME/.pi" "$HOME/.pi.bak.$(date +%s)"
            fi
            ln -s "$PI_PARENT" "$HOME/.pi"
          fi

          # ---- Single stamp check: if configs changed, update symlinks ----
          INSTALL_STAMP="$PI_AGENT_DIR/.install-stamp"
          DESIRED_STAMP="${configStampValue}"

          if ! test -f "$INSTALL_STAMP" || test "$(cat "$INSTALL_STAMP")" != "$DESIRED_STAMP"; then
            ln -sfn ${settingsJson}       "$PI_AGENT_DIR/settings.json"
            ln -sfn ${modelsJsonSrc}      "$PI_AGENT_DIR/models.json"
            ln -sfn ${keybindingsJsonSrc} "$PI_AGENT_DIR/keybindings.json"
            echo "$DESIRED_STAMP" > "$INSTALL_STAMP"
          fi

          # ---- Symlink pre-built extensions (no runtime install needed) ----
          PI_NPM_DIR="$PI_AGENT_DIR/npm"
          mkdir -p "$PI_NPM_DIR"
          if ! test -L "$PI_NPM_DIR/node_modules" || ! test -d "$(readlink "$PI_NPM_DIR/node_modules")"; then
            ln -sfn ${allExtensions}/node_modules "$PI_NPM_DIR/node_modules"
          fi

          exec ${basePi}/bin/pi "$@"
        '';

      in
      {
        packages = {
          default = piWrapper;
          pi = piWrapper;
        };
      }
    );
}
