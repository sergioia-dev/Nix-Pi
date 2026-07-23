{
  description = "Pi agent with declarative configuration";

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

          # ------------------------------------------------------------
          # 1. DECLARE YOUR SETTINGS
          # ------------------------------------------------------------
          settingsJson = pkgs.writeText "settings.json" (
            builtins.toJSON {
              # Model & Thinking[reference:4]
              defaultProvider = "anthropic";
              defaultModel = "claude-sonnet-4-20250514";
              defaultThinkingLevel = "medium";
              hideThinkingBlock = false;

              # UI & Display[reference:5]
              theme = "dark";
              quietStartup = false;
              defaultProjectTrust = "ask";

              # Compaction[reference:6]
              compaction = {
                enabled = true;
                reserveTokens = 16384;
                keepRecentTokens = 20000;
              };

              # Retry[reference:7]
              retry = {
                enabled = true;
                maxRetries = 3;
                baseDelayMs = 2000;
              };

              # Model Cycling[reference:8]
              enabledModels = [
                "claude-*"
                "gpt-4o"
              ];

              # Warnings[reference:9]
              warnings = {
                anthropicExtraUsage = true;
              };

              # Packages (extensions to load)[reference:10]
              packages = [
                "npm:@vigolium/piolium"
              ];
            }
          );

          # ------------------------------------------------------------
          # 2. DECLARE MODELS (providers)
          # ------------------------------------------------------------
          modelsJson = pkgs.writeText "models.json" (
            builtins.toJSON {
              providers = {
                anthropic = {
                  apiKey = "$ANTHROPIC_API_KEY"; # read from environment
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

          # ------------------------------------------------------------
          # 3. DECLARE KEYBINDINGS
          # ------------------------------------------------------------
          keybindingsJson = pkgs.writeText "keybindings.json" (
            builtins.toJSON {
              "mode:main:key:ctrl-p" = [ "goto:chat" ];
              "mode:chat:key:escape" = [ "goto:main" ];
              "mode:main:key:ctrl-k" = [ "kill:buffer" ];
            }
          );

          # ------------------------------------------------------------
          # 4. RUNTIME EXTENSION INSTALLER (avoids sandbox issues)
          # ------------------------------------------------------------
          extensionSpecs = [
            "npm:opencode-pi"
            "npm:pi-vim"
            "npm:pi-nvim"
            "npm:pi-cc-theme"
            "npm:pi-catppuccin-tui"
          ];

          piWrapper = pkgs.writeShellScriptBin "pi" ''
            set -e

            PI_HOME="$HOME/.pi"
            PI_NPM_DIR="$PI_HOME/agent/npm"

            # Install extensions if missing
            for spec in ${pkgs.lib.concatStringsSep " " extensionSpecs}; do
              pkg=''${spec#npm:}
              name=''${pkg%%@*}
              if ! test -d "$PI_NPM_DIR/node_modules/$name"; then
                echo "Installing extension: $spec"
                ${basePi}/bin/pi install "$spec" --no-approve
              fi
            done

            # Run the real pi with all arguments
            exec ${basePi}/bin/pi "$@"
          '';

          # ------------------------------------------------------------
          # 5. WRAP THE BINARY WITH CONFIG FILES
          # ------------------------------------------------------------
          piWithConfig = pkgs.symlinkJoin {
            name = "pi-coding-agent-configured";
            paths = [ basePi ];

            buildInputs = [ pkgs.makeWrapper ];

            postBuild = ''
              # Create config directory inside the package
              mkdir -p $out/share/pi/agent

              # Link the generated config files
              ln -s ${settingsJson} $out/share/pi/agent/settings.json
              ln -s ${modelsJson} $out/share/pi/agent/models.json
              ln -s ${keybindingsJson} $out/share/pi/agent/keybindings.json

              # Override the pi binary with our wrapper
              ln -sf ${piWrapper}/bin/pi $out/bin/pi

              # Wrap the original binary (for when the wrapper calls it)
              wrapProgram $out/bin/pi \
                --set PI_CONFIG_DIR "$out/share/pi/agent" \
                --prefix PATH : ${
                  pkgs.lib.makeBinPath [
                    pkgs.nodejs_latest
                  ]
                } \
                --set PI_SKIP_VERSION_CHECK 1
            '';
          };

        in
        {
          pi = piWithConfig;
        }
      );

      defaultPackage = forEachSystem (system: self.packages.${system}.pi);
    };
}
