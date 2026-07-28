{ system, pkgs

# ==================================================================
# All tunable settings from flake.nix — each has a documented default
# matching the pi upstream default.
# ==================================================================

# --- Model & Thinking ---
, defaultProvider            ? "opencode"
, defaultModel               ? "deepseek-v4-flash-free"
, defaultThinkingLevel       ? null          # null = pi default ("off")
, hideThinkingBlock          ? false
, showCacheMissNotices       ? false
, thinkingBudgets            ? null          # null = pi default levels

# --- UI & Display ---
, theme                      ? "catppuccin-mocha"
, externalEditor             ? null          # null = pi default ($VISUAL/$EDITOR/nano)
, quietStartup               ? false
, defaultProjectTrust        ? "always"
, collapseChangelog          ? false
, enableInstallTelemetry     ? true
, enableAnalytics            ? false
, trackingId                 ? null
, doubleEscapeAction         ? "tree"       # "tree", "fork", or "none"
, treeFilterMode             ? "default"    # "default", "no-tools", "user-only", "labeled-only", "all"
, editorPaddingX             ? 0
, outputPad                  ? 1
, autocompleteMaxVisible     ? 5
, showHardwareCursor         ? false

# --- Network ---
, httpProxy                  ? null          # null = no proxy

# --- Warnings ---
, warningsAnthropicExtraUsage ? true

# --- Compaction ---
, compactionEnabled           ? true
, compactionReserveTokens     ? 16384
, compactionKeepRecentTokens  ? 20000

# --- Branch Summary ---
, branchSummaryReserveTokens  ? 16384
, branchSummarySkipPrompt     ? false

# --- Retry ---
, retryEnabled                ? true
, retryMaxRetries             ? 10
, retryBaseDelayMs            ? 2000
, retryProviderTimeoutMs      ? 86400000
, retryProviderMaxRetries     ? 10
, retryProviderMaxRetryDelayMs ? 300000

# --- Message Delivery ---
, steeringMode                ? "one-at-a-time"
, followUpMode                ? "one-at-a-time"
, transport                   ? "auto"       # "auto", "sse", "websocket", "websocket-cached"
, httpIdleTimeoutMs           ? 300000
, websocketConnectTimeoutMs   ? 15000

# --- Terminal & Images ---
, terminalShowImages          ? true
, terminalImageWidthCells     ? 60
, terminalClearOnShrink       ? false
, imagesAutoResize            ? true
, imagesBlockImages           ? false

# --- Shell ---
, shellPath                   ? null
, shellCommandPrefix          ? null
, npmCommand                  ? null

# --- Sessions ---
, sessionDir                  ? null

# --- Model Cycling ---
, enabledModels               ? null

# --- Markdown ---
, markdownCodeBlockIndent     ? "  "

# --- Resources ---
, enableSkillCommands         ? true
, extraExtensions             ? [ ]
, extraSkills                 ? [ ]
, extraPrompts                ? [ ]
, extraThemes                 ? [ ]

# --- Extensions (required) ---
, gitExtensions
, npmExtensionSrc
, npmExtensionPkgJson
, npmDepsHash
, modelsJsonContent
, keybindingsJsonContent
}:

let
  inherit (pkgs) lib;
  basePi = pkgs.pi-coding-agent;

  # ---- Helpers ----
  utils = import ./utils.nix { inherit pkgs lib; };

  # ---- Npm extension metadata ----
  extensionPkg = builtins.fromJSON npmExtensionPkgJson;
  npmExtSpecs = builtins.map (name: "npm:${name}@${extensionPkg.dependencies.${name}}") (
    builtins.attrNames extensionPkg.dependencies
  );

  # ---- Git extension metadata ----
  gitExtSpecs = builtins.attrNames gitExtensions;
  gitExtFetched = builtins.mapAttrs (spec: hash: utils.fetchGitExt spec hash) gitExtensions;

  # ---- Combined specs ----
  extensionSpecs = npmExtSpecs ++ gitExtSpecs;
  extensionPackageNames = builtins.map utils.extName extensionSpecs;

  # ---- Build npm packages ----
  npmExtensions = pkgs.buildNpmPackage {
    pname = "pi-npm-extensions";
    version = "0.0.0";
    src = npmExtensionSrc;
    npmDepsHash = npmDepsHash;
    npmFlags = [ "--legacy-peer-deps" "--ignore-scripts" ];
    npmrc = "legacy-peer-deps=true\nignore-scripts=true\n";
    npmInstallFlags = [ "--frozen-lockfile" ];
    dontNpmBuild = true;
  };

  # ---- Combined extensions tree ----
  allExtensions = import ./extensions.nix {
    inherit pkgs lib npmExtensions gitExtensions gitExtFetched extensionPackageNames;
  };

  # ---- Build settings JSON from all the tunables ----
  settingsJson = pkgs.writeText "settings.json" (
    builtins.toJSON (
      # Remove nulls so we don't write "null" into the JSON
      lib.filterAttrsRecursive (_: v: v != null) {
        inherit defaultProvider defaultModel theme;
        defaultProjectTrust = defaultProjectTrust;
        hideThinkingBlock = hideThinkingBlock;
        showCacheMissNotices = showCacheMissNotices;
        quietStartup = quietStartup;
        collapseChangelog = collapseChangelog;
        enableInstallTelemetry = enableInstallTelemetry;
        enableAnalytics = enableAnalytics;
        doubleEscapeAction = doubleEscapeAction;
        treeFilterMode = treeFilterMode;
        editorPaddingX = editorPaddingX;
        outputPad = outputPad;
        autocompleteMaxVisible = autocompleteMaxVisible;
        showHardwareCursor = showHardwareCursor;
        terminal = {
          showImages = terminalShowImages;
          imageWidthCells = terminalImageWidthCells;
          clearOnShrink = terminalClearOnShrink;
        };
        images = {
          autoResize = imagesAutoResize;
          blockImages = imagesBlockImages;
        };
        markdown = {
          codeBlockIndent = markdownCodeBlockIndent;
        };
        warnings = {
          anthropicExtraUsage = warningsAnthropicExtraUsage;
        };
        compaction = {
          enabled = compactionEnabled;
          reserveTokens = compactionReserveTokens;
          keepRecentTokens = compactionKeepRecentTokens;
        };
        branchSummary = {
          reserveTokens = branchSummaryReserveTokens;
          skipPrompt = branchSummarySkipPrompt;
        };
        retry = {
          enabled = retryEnabled;
          maxRetries = retryMaxRetries;
          baseDelayMs = retryBaseDelayMs;
          provider = {
            timeoutMs = retryProviderTimeoutMs;
            maxRetries = retryProviderMaxRetries;
            maxRetryDelayMs = retryProviderMaxRetryDelayMs;
          };
        };
        inherit steeringMode followUpMode transport;
        httpIdleTimeoutMs = httpIdleTimeoutMs;
        websocketConnectTimeoutMs = websocketConnectTimeoutMs;
        inherit enableSkillCommands;
        packages = extensionSpecs;
      }
      // lib.optionalAttrs (defaultThinkingLevel != null) { inherit defaultThinkingLevel; }
      // lib.optionalAttrs (thinkingBudgets != null) { inherit thinkingBudgets; }
      // lib.optionalAttrs (externalEditor != null) { inherit externalEditor; }
      // lib.optionalAttrs (httpProxy != null) { inherit httpProxy; }
      // lib.optionalAttrs (shellPath != null) { inherit shellPath; }
      // lib.optionalAttrs (shellCommandPrefix != null) { inherit shellCommandPrefix; }
      // lib.optionalAttrs (npmCommand != null) { inherit npmCommand; }
      // lib.optionalAttrs (sessionDir != null) { inherit sessionDir; }
      // lib.optionalAttrs (enabledModels != null) { inherit enabledModels; }
      // lib.optionalAttrs (trackingId != null) { inherit trackingId; }
      // lib.optionalAttrs (extraExtensions != [ ]) { extensions = extraExtensions; }
      // lib.optionalAttrs (extraSkills != [ ]) { skills = extraSkills; }
      // lib.optionalAttrs (extraPrompts != [ ]) { prompts = extraPrompts; }
      // lib.optionalAttrs (extraThemes != [ ]) { themes = extraThemes; }
    )
  );

  # ---- Config stamp ----
  configStampValue = builtins.hashString "sha256" (
    modelsJsonContent
    + keybindingsJsonContent
    + builtins.concatStringsSep "\n" extensionSpecs
    + builtins.toJSON defaultProvider
    + builtins.toJSON defaultModel
    + builtins.toJSON theme
    + builtins.toJSON defaultProjectTrust
  );

  # ---- Wrapper script ----
  piWrapper = import ./wrapper.nix {
    inherit pkgs basePi settingsJson allExtensions configStampValue
            modelsJsonContent keybindingsJsonContent;
  };

in
{
  packages = {
    default = piWrapper;
    pi = piWrapper;
  };
  devShells = {
    default = pkgs.mkShell {
      packages = [ pkgs.nodejs pkgs.nixfmt ];
      shellHook = ''
        echo "Nix-Pi devShell — Node.js $(node --version) ready"
      '';
    };
  };
  formatter = pkgs.nixfmt;
}
