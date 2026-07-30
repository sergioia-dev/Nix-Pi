{
  description = "Nix-Pi — Declarative Pi Coding Agent flake (fully isolated, reproducible)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      import ./nix rec {
        inherit system;
        pkgs = nixpkgs.legacyPackages.${system};

        # ================================================================
        # USER TUNABLES — edit these to customise your pi install
        # ================================================================

        # --- Model & Thinking ---
        # defaultProvider = "opencode";
        # defaultModel = "deepseek-v4-flash-free";
        # defaultThinkingLevel = null;    # null = pi default ("off")
        # hideThinkingBlock = false;
        # showCacheMissNotices = false;
        # thinkingBudgets = null;          # null = pi default levels

        # --- UI & Display ---
        theme = "catppuccin-mocha";
        externalEditor = null; # null = $VISUAL/$EDITOR/nano
        # quietStartup = false;
        defaultProjectTrust = "always";
        # collapseChangelog = false;
        # enableInstallTelemetry = true;
        # enableAnalytics = false;
        # trackingId = null;
        # doubleEscapeAction = "tree";
        # treeFilterMode = "default";
        # editorPaddingX = 0;
        # outputPad = 1;
        # autocompleteMaxVisible = 5;
        # showHardwareCursor = false;

        # --- Network ---
        # httpProxy = null;                # e.g. "http://127.0.0.1:7890"

        # --- Warnings ---
        # warningsAnthropicExtraUsage = true;

        # --- Compaction ---
        # compactionEnabled = true;
        # compactionReserveTokens = 16384;
        # compactionKeepRecentTokens = 20000;

        # --- Branch Summary ---
        # branchSummaryReserveTokens = 16384;
        # branchSummarySkipPrompt = false;

        # --- Retry ---
        retryEnabled = true;
        retryMaxRetries = 10;
        retryBaseDelayMs = 2000;
        retryProviderTimeoutMs = 86400000;
        retryProviderMaxRetries = 10;
        retryProviderMaxRetryDelayMs = 300000;

        # --- Message Delivery ---
        # steeringMode = "one-at-a-time";
        # followUpMode = "one-at-a-time";
        # transport = "auto";
        # httpIdleTimeoutMs = 300000;
        # websocketConnectTimeoutMs = 15000;

        # --- Terminal & Images ---
        # terminalShowImages = true;
        # terminalImageWidthCells = 60;
        # terminalClearOnShrink = false;
        # imagesAutoResize = true;
        # imagesBlockImages = false;

        # --- Shell ---
        # shellPath = null;
        # shellCommandPrefix = null;
        # npmCommand = null;               # e.g. ["mise", "exec", "node@20", "--", "npm"]

        # --- Sessions ---
        # sessionDir = null;

        # --- Model Cycling ---
        # enabledModels = null;             # e.g. ["claude-*", "gpt-4o"]

        # --- Markdown ---
        # markdownCodeBlockIndent = "  ";

        # --- Resources ---
        # enableSkillCommands = true;
        # extraExtensions = [ ];
        # extraSkills = [ ];
        # extraPrompts = [ ];
        # extraThemes = [ ];

        # --- Git extensions ---
        #   format: "git:github.com/owner/repo@rev" = "sha256-...";
        gitExtensions = {
          "git:github.com/bwks/pi-planner@f8b0495d28f8bbb39bcb9efa5879a8b71f52bc30" =
            "sha256-fcWsItMAEAonxtJfN2FU/9/TCtYBfeyiMJq0XEW9+to=";
        };

        # --- Npm extension source (must contain package.json + package-lock.json) ---
        npmExtensionSrc = ./extensions;
        npmDepsHash = "sha256-yXoBuX1jxEtDBpc7wCzpIkKEu7N0cvHq+3VnGaFL9rE=";

        # --- Config file contents (read at eval time) ---
        npmExtensionPkgJson = builtins.readFile ./extensions/package.json;
        modelsJsonContent = builtins.readFile ./models.json;
        keybindingsJsonContent = builtins.readFile ./keybindings.json;
      }
    );
}
