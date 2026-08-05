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
    let
      # ================================================================
      # USER TUNABLES — edit these to customise your pi install
      # ================================================================

      # --- npm extensions (single source of truth) ---
      # Each entry is "name" or "name@version". After editing, run
      #   nix run .#add-npm-dep
      # to regenerate extensions/package.json + extensions/package-lock.json.
      npmExtensionSpecs = [
        "pi-vim@0.14.1"
        "pi-nvim@0.2.4"
        "pi-catppuccin-tui@0.1.3"
        "@nguyenquangthai/pi-todo@0.6.0"
        "pi-pixel-header@1.0.2"
        "pi-web-access@0.13.0"
        "@gotgenes/pi-permission-system@24.0.0"
        "pi-loop-police@1.13.0"
        "pi-adaptive-thinking@0.1.1"
        "pi-open-agents@0.1.12"
        "@firstpick/pi-extension-nixos-wiki-local@0.1.6"
        "pi-env-probe@0.1.3"
        "pi-kilocode@0.1.2"
        "pi-all-tools@1.0.5"
        "pi-hashline-edit-pro@1.0.7"
        "pi-simplify@0.2.3"
        "pi-hermes-memory@0.9.2"
        "@narumitw/pi-plan-mode@0.49.3"
      ];
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      import ./nix rec {
        inherit system;
        pkgs = nixpkgs.legacyPackages.${system};
        inherit npmExtensionSpecs;

        # --- Model & Thinking ---
        defaultProvider = "opencode";
        defaultModel = "deepseek-v4-flash-free";
        defaultThinkingLevel = null; # null = pi default ("off")
        hideThinkingBlock = true;
        showCacheMissNotices = false;
        thinkingBudgets = null; # null = pi default levels

        # --- UI & Display ---
        theme = "catppuccin-tui-mocha";
        externalEditor = null; # null = $VISUAL/$EDITOR/nano
        quietStartup = false;
        defaultProjectTrust = "always";
        collapseChangelog = false;
        enableInstallTelemetry = false;
        enableAnalytics = false;
        trackingId = null;
        doubleEscapeAction = "tree";
        treeFilterMode = "default";
        editorPaddingX = 3;
        outputPad = 1;
        autocompleteMaxVisible = 5;
        showHardwareCursor = false;

        # --- Network ---
        httpProxy = null; # e.g. "http://127.0.0.1:7890"

        # --- Warnings ---
        warningsAnthropicExtraUsage = true;

        # --- Compaction ---
        compactionEnabled = true;
        compactionReserveTokens = 16384;
        compactionKeepRecentTokens = 20000;

        # --- Branch Summary ---
        branchSummaryReserveTokens = 16384;
        branchSummarySkipPrompt = false;

        # --- Retry ---
        retryEnabled = true;
        retryMaxRetries = 10;
        retryBaseDelayMs = 2000;
        retryProviderTimeoutMs = 86400000;
        retryProviderMaxRetries = 10;
        retryProviderMaxRetryDelayMs = 300000;

        # --- Message Delivery ---
        steeringMode = "one-at-a-time";
        followUpMode = "one-at-a-time";
        transport = "auto";
        httpIdleTimeoutMs = 300000;
        websocketConnectTimeoutMs = 15000;

        # --- Terminal & Images ---
        terminalShowImages = true;
        terminalImageWidthCells = 60;
        terminalClearOnShrink = false;
        imagesAutoResize = true;
        imagesBlockImages = false;

        # --- Shell ---
        shellPath = null;
        shellCommandPrefix = null;
        npmCommand = null; # e.g. ["mise", "exec", "node@20", "--", "npm"]

        # --- Sessions ---
        sessionDir = null;

        # --- Model Cycling ---
        enabledModels = null; # e.g. ["claude-*", "gpt-4o"]

        # --- Markdown ---
        markdownCodeBlockIndent = "  ";

        # --- Resources ---
        enableSkillCommands = true;
        extraExtensions = [ ];
        extraSkills = [ ];
        extraPrompts = [ ];
        extraThemes = [ ];

        # --- Git extensions ---
        #   format: "git:github.com/owner/repo@rev" = "sha256-...";
        gitExtensions = {
          # "git:github.com/bwks/pi-planner@f8b0495d28f8bbb39bcb9efa5879a8b71f52bc30" =
          #   "sha256-fcWsItMAEAonxtJfN2FU/9/TCtYBfeyiMJq0XEW9+to=";
        };

        # --- Npm extension source (must contain package-lock.json; package.json
        #     is regenerated from npmExtensionSpecs by `nix run .#add-npm-dep`) ---
        npmExtensionSrc = ./extensions;

        # --- Config file contents (read at eval time) ---
        modelsJsonContent = builtins.readFile ./models.json;
        keybindingsJsonContent = builtins.readFile ./keybindings.json;
      }
    )
    // {
      # Expose the specs as a top-level output so the add-npm-dep script can
      # read them with `nix eval --json .#npmExtensionSpecs` (no build needed).
      inherit npmExtensionSpecs;
    };
}
