{
  description = "Pi agent with declarative configuration (fully isolated)";

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
            "npm:opencode-pi"
            "npm:pi-vim"
            "npm:pi-nvim"
            "npm:pi-cc-theme"
            "npm:pi-catppuccin-tui"
          ];

          settingsJson = pkgs.writeText "settings.json" (
            builtins.toJSON {
              defaultProvider = "anthropic";
              defaultModel = "claude-sonnet-4-20250514";
              defaultThinkingLevel = "medium";
              hideThinkingBlock = false;
              theme = "dark";
              quietStartup = false;
              defaultProjectTrust = "ask";
              compaction = {
                enabled = true;
                reserveTokens = 16384;
                keepRecentTokens = 20000;
              };
              retry = {
                enabled = true;
                maxRetries = 3;
                baseDelayMs = 2000;
              };
              enabledModels = [
                "claude-sonnet-4-20250514"
                "gpt-4o"
              ];
              warnings = {
                anthropicExtraUsage = true;
              };
              packages = extensionSpecs;
            }
          );

          modelsJson = pkgs.writeText "models.json" (
            builtins.toJSON {
              providers = {
                anthropic = {
                  apiKey = "$ANTHROPIC_API_KEY";
                };
                openai = {
                  apiKey = "$OPENAI_API_KEY";
                };
                ollama = {
                  baseUrl = "http://127.0.0.1:11434";
                };
              };
              models = {
                "claude-sonnet-4-20250514" = {
                  provider = "anthropic";
                  model = "claude-3-5-sonnet-20241022";
                };
                "gpt-4o" = {
                  provider = "openai";
                  model = "gpt-4o";
                };
                "codellama" = {
                  provider = "ollama";
                  model = "codellama";
                };
              };
            }
          );

          keybindingsJson = pkgs.writeText "keybindings.json" (
            builtins.toJSON {
              "mode:main:key:ctrl-p" = [ "goto:chat" ];
              "mode:chat:key:escape" = [ "goto:main" ];
              "mode:main:key:ctrl-k" = [ "kill:buffer" ];
            }
          );

          configDir = pkgs.runCommand "pi-config" { } ''
            mkdir -p $out
            ln -s ${settingsJson} $out/settings.json
            ln -s ${modelsJson} $out/models.json
            ln -s ${keybindingsJson} $out/keybindings.json
          '';

          piWrapper = pkgs.writeShellScriptBin "pi" ''
            set -e

            PI_PARENT="$HOME/.local/share/pi-nix"
            PI_AGENT_DIR="$PI_PARENT/agent"
            export PI_CODING_AGENT_DIR="$PI_AGENT_DIR"
            export PI_HOME="$PI_AGENT_DIR"

            mkdir -p "$PI_AGENT_DIR"

            # Ensure ~/.pi symlink points to parent
            if ! test -L "$HOME/.pi" || test "$(readlink "$HOME/.pi")" != "$PI_PARENT"; then
              if test -e "$HOME/.pi"; then
                mv "$HOME/.pi" "$HOME/.pi.bak.$(date +%s)"
              fi
              ln -s "$PI_PARENT" "$HOME/.pi"
            fi

            # ---- Overwrite config files safely ----
            for file in settings.json models.json keybindings.json; do
              rm -f "$PI_AGENT_DIR/$file"              # remove if exists
              cp ${configDir}/$file "$PI_AGENT_DIR/"   # copy fresh from store
              chmod 644 "$PI_AGENT_DIR/$file"          # make writable
            done

            # ---- Install missing extensions ----
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

          piWithIsolation = pkgs.symlinkJoin {
            name = "pi-isolated";
            paths = [ basePi ];

            buildInputs = [ pkgs.makeWrapper ];

            postBuild = ''
              ln -sf ${piWrapper}/bin/pi $out/bin/pi
              wrapProgram $out/bin/pi \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs_latest ]} \
                --set PI_SKIP_VERSION_CHECK 1
            '';
          };

        in
        {
          pi = piWithIsolation;
        }
      );

      defaultPackage = forEachSystem (system: self.packages.${system}.pi);
    };
}
