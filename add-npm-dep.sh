#!/usr/bin/env bash
# add-npm-dep — regenerate extensions/package.json + extensions/package-lock.json
# from the npmExtensionSpecs list in flake.nix.
#
# Usage (from the flake root):
#   nix run .#add-npm-dep
#
# 1. reads `nix eval --json .#npmExtensionSpecs`
# 2. writes extensions/package.json with those specs as dependencies
# 3. runs `npm install --package-lock-only` to refresh extensions/package-lock.json
# 4. pins package.json dependencies to the exact versions from the lockfile

set -euo pipefail

if [ ! -f flake.nix ]; then
  echo "error: add-npm-dep must be run from the flake root (no flake.nix in $(pwd))" >&2
  exit 1
fi

ext_dir="extensions"

echo "==> Reading npmExtensionSpecs from flake.nix ..."
specs_json="$(nix eval --json .#npmExtensionSpecs)"

echo "==> Writing ${ext_dir}/package.json ..."
node - "$ext_dir" "$specs_json" <<'NODE_EOF'
const fs = require("node:fs");
const [extDir, specsJson] = process.argv.slice(2);
const specs = JSON.parse(specsJson);
const dependencies = {};
for (const spec of specs) {
  // "@scope/name@1.0.0" -> name "@scope/name", version "1.0.0"
  // "pi-vim@0.14.1"     -> name "pi-vim", version "0.14.1"
  // "pi-vim"            -> name "pi-vim", version "latest"
  const at = spec.startsWith("@") ? spec.indexOf("@", 1) : spec.indexOf("@");
  if (at === -1) {
    dependencies[spec] = "latest";
  } else {
    dependencies[spec.slice(0, at)] = spec.slice(at + 1);
  }
}
const pkg = {
  name: "pi-extensions",
  version: "0.0.0",
  private: true,
  dependencies,
};
fs.writeFileSync(`${extDir}/package.json`, `${JSON.stringify(pkg, null, 2)}\n`);
NODE_EOF

echo "==> Refreshing ${ext_dir}/package-lock.json (npm install --package-lock-only) ..."
(
  cd "${ext_dir}"
  npm install --package-lock-only --legacy-peer-deps --ignore-scripts
)

echo "==> Pinning package.json versions to the locked versions ..."
node - "$ext_dir" <<'NODE_EOF'
const fs = require("node:fs");
const extDir = process.argv[2];
const lock = JSON.parse(fs.readFileSync(`${extDir}/package-lock.json`, "utf8"));
const rootDeps = lock.packages?.[""]?.dependencies ?? {};
const pkg = JSON.parse(fs.readFileSync(`${extDir}/package.json`, "utf8"));
pkg.dependencies = {};
for (const name of Object.keys(rootDeps)) {
  // Use the concrete installed version from the lockfile (root entries can
  // keep "latest" or ranges for versionless specs).
  const concrete = lock.packages?.[`node_modules/${name}`]?.version;
  pkg.dependencies[name] = concrete ?? rootDeps[name];
}
fs.writeFileSync(`${extDir}/package.json`, `${JSON.stringify(pkg, null, 2)}\n`);
NODE_EOF

echo "==> Re-syncing lockfile root with the pinned package.json ..."
(
  cd "${ext_dir}"
  npm install --package-lock-only --legacy-peer-deps --ignore-scripts
)

echo
echo "Done. extensions/package.json + package-lock.json are in sync with flake.nix."
echo "Next step: Running 'nix build .' for check"
nix build .
