{
  description = "Pi agent with declarative configuration (fully isolated) – performance-optimised";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          basePi = pkgs.pi-coding-agent;

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
          # 1. Extension node_modules placeholder
          #    (extensions installed at runtime because Nix build sandbox
          #     blocks network access to npm registry)
          # ------------------------------------------------------------------
          extensionNodeModules = pkgs.emptyDirectory;

          # ------------------------------------------------------------------
          # 2. Config files – use builtins.path to avoid readFile eval overhead
          # ------------------------------------------------------------------
          settingsJson = pkgs.writeText "settings.json" (
            builtins.toJSON {
              # ---- Model Defaults ----
              defaultProvider = "opencode";
              defaultModel = "deepseek-v4-flash-free";

              # ---- Thinking Budgets ----
              thinkingBudgets = {
                minimal = 4096;
                low = 32768;
                medium = 65536;
                high = 200000;
              };

              # ---- UI / Behavior ----
              hideThinkingBlock = false;
              theme = "catppuccin-mocha";
              quietStartup = false;
              defaultProjectTrust = "always";
              editorPaddingX = 3;

              # ---- Retry & Timeout ----
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

              # ---- Extensions ----
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
          # 3. Combined stamp: a single hash of all inputs, so the wrapper can
          #    do ONE comparison instead of checking each file separately
          # ------------------------------------------------------------------
          configStampValue = builtins.hashString "sha256" (
            "${settingsJson}" + "${modelsJsonSrc}" + "${keybindingsJsonSrc}"
          );

          # ------------------------------------------------------------------
          # 4. Wrapper script – stamp-based, symlinks everywhere, no rm+cp
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
              ln -sfn ${settingsJson}          "$PI_AGENT_DIR/settings.json"
              ln -sfn ${modelsJsonSrc}         "$PI_AGENT_DIR/models.json"
              ln -sfn ${keybindingsJsonSrc}    "$PI_AGENT_DIR/keybindings.json"
              echo "$DESIRED_STAMP" > "$INSTALL_STAMP"
            fi

            # ---- Install missing extensions at runtime (network required) ----
            PI_NPM_DIR="$PI_AGENT_DIR/npm"
            mkdir -p "$PI_NPM_DIR"
            for spec in ${pkgs.lib.concatStringsSep " " extensionSpecs}; do
              pkg=''${spec#npm:}
              name=''${pkg%%@*}
              if ! test -d "$PI_NPM_DIR/node_modules/$name"; then
                echo "Installing extension: $spec"
                ${basePi}/bin/pi install "$spec" --no-approve
              fi
            done

            exec ${basePi}/bin/pi "$@"
          '';

        in
        {
          # No symlinkJoin needed – piWrapper already has all dependencies
          # (basePi is in its closure via the exec reference)
          pi = piWrapper;
        }
      );

      defaultPackage = forEachSystem (system: self.packages.${system}.pi);
    };
}
