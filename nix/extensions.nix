{ pkgs, lib, npmExtensions, gitExtensions, gitExtFetched, extensionPackageNames }:

let
  npmExtensionsDir = "${npmExtensions}/lib/node_modules";

  markerNamesFile = pkgs.writeText "marker-names" (
    builtins.concatStringsSep "\n" extensionPackageNames
  );

  gitCopyCommands = builtins.concatStringsSep "\n" (
    builtins.attrValues (
      builtins.mapAttrs (spec: drv:
        let
          rest = lib.removePrefix "git:" spec;
          parts = lib.splitString "/" rest;
          owner = lib.elemAt parts 1;
          repoRev = lib.elemAt parts 2;
          repo = lib.elemAt (lib.splitString "@" repoRev) 0;
        in
        ''
          mkdir -p $out/git/github.com/${owner}/${repo}
          cp -r ${drv}/* $out/git/github.com/${owner}/${repo}/
          mkdir -p $out/git/github.com/${owner}/${repo}/node_modules
          for d in $(ls -1 ${npmExtensionsDir}/ | sort); do
            cp -r ${npmExtensionsDir}/"$d" $out/git/github.com/${owner}/${repo}/node_modules/
          done
          mkdir -p $out/node_modules/${repo}
          cp -r ${drv}/* $out/node_modules/${repo}/
        ''
      ) gitExtFetched
    )
  );
in

pkgs.runCommand "pi-all-extensions"
  {
    nativeBuildInputs = [ pkgs.coreutils ];
    preferLocalBuild = true;
  }
  ''
    export LC_ALL=C

    # ---- 1. npm extensions into node_modules/ ----
    mkdir -p $out/node_modules
    if [ -d "${npmExtensionsDir}" ]; then
      for d in $(ls -1 ${npmExtensionsDir}/ | sort); do
        cp -r ${npmExtensionsDir}/"$d" $out/node_modules/
      done
    else
      echo "ERROR: ${npmExtensionsDir} not found" >&2
      exit 1
    fi

    # ---- 2. Git extensions into $out/git/github.com/<owner>/<repo>/ ----
    ${gitCopyCommands}

    # ---- 3. Install markers so pi thinks they are already installed ----
    mkdir -p $out/node_modules/.pi-package-installed
    while IFS= read -r pkg; do
      marker="$out/node_modules/.pi-package-installed/$pkg"
      mkdir -p "$(dirname "$marker")"
      echo '{"spec":"'"$pkg"'","version":"0.0.0"}' > "$marker"
    done < ${markerNamesFile}
  ''
