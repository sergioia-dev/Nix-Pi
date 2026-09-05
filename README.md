# Nix-Pi

A fully reproducible, Nix-managed build of the [Pi coding agent](https://pi.dev).
All dependencies (Node.js, npm extensions, git extensions) are pinned and
pre-built at Nix build time — **no runtime network access**, **no config drift**,
**no `npm install` at startup**.

## Quick start

```bash
# Build everything → ./result/bin/pi
nix build .

# Launch Pi with all pre-built extensions
./result/bin/pi

# Dev shell with Node.js + nixfmt
nix develop
```

## How to use

**`flake.nix` is the only file you need to edit for configuration.**
It exposes every Pi setting as a Nix attribute — un-comment any option to
override its default. The defaults live in `nix/default.nix` as Nix function
arguments with `? default` syntax.

### Adding an npm extension

1. Add the package to `extensions/package.json` and update
   `extensions/package-lock.json` (run `npm install` inside `extensions/`).
2. Update `npmDepsHash` in `flake.nix` with the new lockfile hash:

```bash
# Use lib.fakeHash first, then capture the real hash:
nix build . 2>&1 | grep 'got:' | head -1
# Paste the hash into npmDepsHash and rebuild
```

### Adding a git extension

Add an entry to the `gitExtensions` attrset in `flake.nix`:

```nix
gitExtensions = {
  "git:github.com/bwks/pi-planner@f8b0495d28f8bbb39bcb9efa5879a8b71f52bc30" =
    "sha256-fcWsItMAEAonxtJfN2FU/9/TCtYBfeyiMJq0XEW9+to=";
  # Add more below:
  "git:github.com/owner/repo@commit-rev" = "sha256-...";
};
```

To resolve the hash for a new git extension, use `pkgs.lib.fakeHash` for the
initial build and capture the real hash from the error message.

## Module structure

Everything lives under `nix/` — the flake delegates all logic to these modules:

| File | Responsibility |
|------|---------------|
| `flake.nix` | **User tunables only** — provider, model, theme, extensions, hashes |
| `nix/default.nix` | Main entry — wires config values, calls sub-modules, returns `packages` + `devShells` |
| `nix/utils.nix` | Shared helpers: `extName` (parse spec → package name), `fetchGitExt` (parse git spec → `fetchFromGitHub`) |
| `nix/extensions.nix` | Builds npm + git extensions into a single combined tree with install markers |
| `nix/wrapper.nix` | The `pi` wrapper shell script — stamp check, symlinks, GC-resilient fallbacks |

## All settings

## Extensions (required)

| Setting | Type | Description |

|---------|------|-------------|

| gitExtensions | attrset | Git extension specs: "git:github.com/owner/repo@rev" = "sha256-..." |

| npmExtensionSrc | path | Path to extensions/ directory containing package.json + package-lock.json |

| npmExtensionPkgJson | string (content) | builtins.readFile ./extensions/package.json |

| modelsJsonContent | string (content) | builtins.readFile ./models.json |

| keybindingsJsonContent | string (content) | builtins.readFile ./keybindings.json |

| extraExtensions | array | Additional local extension paths or directories |

| extraSkills | array | Additional local skill paths or directories |

| enableSkillCommands | boolean | Register skills as /skill:name commands |



Every Pi setting from the [official documentation](https://pi.dev/docs/latest/settings)
is available as a tunable in `flake.nix`. Commented-out values represent the
defaults.

### Model & Thinking

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `defaultProvider` | string | `"opencode"` | Default provider |
| `defaultModel` | string | `"deepseek-v4-flash-free"` | Default model ID |
| `defaultThinkingLevel` | string | `null` (pi default `"off"`) | `"off"`, `"minimal"`, `"low"`, `"medium"`, `"high"`, `"xhigh"`, `"max"` |
| `hideThinkingBlock` | boolean | `false` | Hide thinking blocks in output |
| `showCacheMissNotices` | boolean | `false` | Show notices for prompt-cache misses |
| `thinkingBudgets` | object | `null` (pi defaults) | Custom token budgets per thinking level |

### UI & Display

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `theme` | string | `"catppuccin-mocha"` | Theme name |
| `externalEditor` | string | `null` (pi default) | Command for Ctrl+G external editor |
| `quietStartup` | boolean | `false` | Hide startup header |
| `defaultProjectTrust` | string | `"always"` | `"ask"`, `"always"`, or `"never"` |
| `collapseChangelog` | boolean | `false` | Condensed changelog after updates |
| `enableInstallTelemetry` | boolean | `true` | Anonymous install/update ping |
| `enableAnalytics` | boolean | `false` | Opt-in analytics |
| `trackingId` | string | `null` | Analytics tracking identifier |
| `doubleEscapeAction` | string | `"tree"` | `"tree"`, `"fork"`, or `"none"` |
| `treeFilterMode` | string | `"default"` | Default `/tree` filter mode |
| `editorPaddingX` | number | `0` | Horizontal input padding (0–3) |
| `outputPad` | number | `1` | Horizontal padding for messages/thinking |
| `autocompleteMaxVisible` | number | `5` | Max autocomplete items (3–20) |
| `showHardwareCursor` | boolean | `false` | Show terminal cursor for IME support |

### Network

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `httpProxy` | string | `null` | HTTP proxy URL (e.g. `"http://127.0.0.1:7890"`) |

### Warnings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `warningsAnthropicExtraUsage` | boolean | `true` | Show warning when Anthropic subscription may use paid extra usage |

### Compaction

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `compactionEnabled` | boolean | `true` | Enable auto-compaction |
| `compactionReserveTokens` | number | `16384` | Tokens reserved for LLM response |
| `compactionKeepRecentTokens` | number | `20000` | Recent tokens to keep (not summarized) |

### Branch Summary

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `branchSummaryReserveTokens` | number | `16384` | Tokens reserved for branch summarization |
| `branchSummarySkipPrompt` | boolean | `false` | Skip "Summarize branch?" prompt on `/tree` navigation |

### Retry

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `retryEnabled` | boolean | `true` | Enable automatic agent-level retry |
| `retryMaxRetries` | number | `10` | Maximum agent-level retry attempts |
| `retryBaseDelayMs` | number | `2000` | Base delay for exponential backoff |
| `retryProviderTimeoutMs` | number | `86400000` | Provider/SDK request timeout (ms) |
| `retryProviderMaxRetries` | number | `10` | Provider/SDK retry attempts |
| `retryProviderMaxRetryDelayMs` | number | `300000` | Max server-requested delay before failing |

### Message Delivery

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `steeringMode` | string | `"one-at-a-time"` | `"all"` or `"one-at-a-time"` |
| `followUpMode` | string | `"one-at-a-time"` | `"all"` or `"one-at-a-time"` |
| `transport` | string | `"auto"` | `"auto"`, `"sse"`, `"websocket"`, `"websocket-cached"` |
| `httpIdleTimeoutMs` | number | `300000` | HTTP header/body idle timeout (ms); 0 = disable |
| `websocketConnectTimeoutMs` | number | `15000` | WebSocket connect timeout (ms); 0 = disable |

### Terminal & Images

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `terminalShowImages` | boolean | `true` | Show images in terminal (if supported) |
| `terminalImageWidthCells` | number | `60` | Preferred inline image width in cells |
| `terminalClearOnShrink` | boolean | `false` | Clear empty rows when content shrinks |
| `imagesAutoResize` | boolean | `true` | Resize images to 2000×2000 max |
| `imagesBlockImages` | boolean | `false` | Block all images from being sent to LLM |

### Shell

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `shellPath` | string | `null` | Custom shell path (supports `~`) |
| `shellCommandPrefix` | string | `null` | Prefix for every bash command |
| `npmCommand` | array | `null` | Command argv for npm operations (e.g. `["mise", "exec", "node@20", "--", "npm"]`) |

### Sessions

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `sessionDir` | string | `null` | Directory for session files (supports `~`, absolute, or relative) |

### Model Cycling

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `enabledModels` | array | `null` | Model patterns for Ctrl+P cycling (e.g. `["claude-*", "gpt-4o"]`) |

### Markdown

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `markdownCodeBlockIndent` | string | `"  "` | Indentation for code blocks |

### Resources

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `enableSkillCommands` | boolean | `true` | Register skills as `/skill:name` commands |
| `extraExtensions` | array | `[]` | Additional local extension paths or directories |
| `extraSkills` | array | `[]` | Additional local skill paths or directories |
| `extraPrompts` | array | `[]` | Additional local prompt template paths or directories |
| `extraThemes` | array | `[]` | Additional local theme paths or directories |

### Extensions (required)

| Setting | Type | Description |
|---------|------|-------------|
| `gitExtensions` | attrset | Git extension specs: `"git:github.com/owner/repo@rev" = "sha256-..."` |
| `npmExtensionSrc` | path | Path to `extensions/` directory containing `package.json` + `package-lock.json` |
| `npmDepsHash` | string | SRI hash of the npm dependency lockfile |
| `npmExtensionPkgJson` | string (content) | `builtins.readFile ./extensions/package.json` |
| `modelsJsonContent` | string (content) | `builtins.readFile ./models.json` |
| `keybindingsJsonContent` | string (content) | `builtins.readFile ./keybindings.json` |

## GC resilience

The wrapper script handles Nix store garbage-collection gracefully:
- If `nix store gc` removes the store paths that config symlinks point to,
  the wrapper detects the broken symlinks and re-creates them from the
  current build.
- The stamp file is invalidated when any config value changes.
- Extension symlinks (`node_modules`, git extension dirs) are checked
  for target existence and re-created if necessary.

## Build commands

```bash
nix build .              # Build the pi wrapper and all extensions
nix build . --no-link    # Evaluate without placing a result symlink
nix build .#devShells."$(nix eval --raw nixpkgs#system)".default  # Enter dev shell
nix flake check          # Check flake validity
nix fmt                  # Format all .nix files with nixfmt
```

## License

Same as the Pi coding agent itself. See the [Pi repository](https://github.com/pi-coding-agent/pi) for details.
