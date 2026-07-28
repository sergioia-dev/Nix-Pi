{ pkgs, lib }:
{
  # ==================================================================
  # Extract a user-visible package name from an extension spec.
  #
  #   extName "npm:hello@1.2.3"              → "hello"
  #   extName "npm:@scope/name@1.0.0"        → "@scope/name"
  #   extName "git:github.com/owner/repo@r"  → "repo"
  # ==================================================================
  extName =
    spec:
    let
      noPrefix = lib.removePrefix "npm:" (lib.removePrefix "git:github.com/" spec);
    in
    if lib.hasPrefix "@" noPrefix then
      lib.concatStringsSep "@" (lib.take 2 (lib.splitString "@" noPrefix))
    else
      let
        parts = lib.splitString "/" noPrefix;
      in
      if builtins.length parts == 1 then
        lib.elemAt (lib.splitString "@" noPrefix) 0
      else
        lib.elemAt (lib.splitString "@" (lib.elemAt parts 1)) 0;

  # ==================================================================
  # Parse "git:github.com/owner/repo@rev" and call fetchFromGitHub.
  # ==================================================================
  fetchGitExt =
    spec: hash:
    let
      rest = lib.removePrefix "git:" spec;
      pathParts = lib.splitString "/" rest;
      owner = lib.elemAt pathParts 1;
      repoRev = lib.elemAt pathParts 2;
      rev = lib.elemAt (lib.splitString "@" repoRev) 1;
      repo = lib.elemAt (lib.splitString "@" repoRev) 0;
    in
    pkgs.fetchFromGitHub {
      inherit
        owner
        repo
        rev
        hash
        ;
    };
}
