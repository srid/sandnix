{ lib, config, pkgs, ... }:
let
  mkWrappedPackage = { withSandboxArgs ? false }:
    let
      # Helper to generate conditional path argument
      conditionalPathArg = flag: paths:
        lib.concatMapStringsSep "\n"
          (p: ''
            if [ -e "${p}" ]; then
              args+=("${flag}" "${p}")
            fi
          '')
          paths;

      # Static args (non-path related)
      staticArgs = lib.concatStringsSep " \\\n      "
        ([ ]
          ++ (map (p: "--rwx \"${p}\"") config.cli.rwx)
          ++ (map (p: "--rw \"${p}\"") config.cli.rw)
          ++ (map (e: "--env ${e}") config.cli.env)
          ++ (lib.optional config.cli.unrestrictedNetwork "--unrestricted-network")
          ++ (lib.optional config.cli.unrestrictedFilesystem "--unrestricted-filesystem")
          ++ (lib.optional config.cli.addExec "--add-exec")
          ++ config.cli.extraArgs
        );

      scriptName = if withSandboxArgs then "${config.name}-with-args" else config.name;
    in
    (pkgs.writeShellApplication {
      name = scriptName;
      runtimeInputs = [ pkgs.landrun ];
      text = ''
        ${config.preHook}

        args=()

        # Add conditional --rox paths
        ${conditionalPathArg "--rox" config.cli.rox}

        # Add conditional --ro paths
        ${conditionalPathArg "--ro" config.cli.ro}

        ${if withSandboxArgs then ''
          sandbox_args=()
          program_args=()
          seen_dash_dash=0

          for arg in "$@"; do
            if [ "$seen_dash_dash" -eq 1 ]; then
              program_args+=("$arg")
            elif [ "$arg" = "--" ]; then
              seen_dash_dash=1
            else
              sandbox_args+=("$arg")
            fi
          done

          exec landrun \
            "''${args[@]}" \
            ${staticArgs} \
            "''${sandbox_args[@]}" \
            ${config.program} "''${program_args[@]}"
        '' else ''
          exec landrun \
            "''${args[@]}" \
            ${staticArgs} \
            ${config.program} "$@"
        ''}
      '';
    }) // {
      meta = config.meta;
    };
in
{
  config = lib.mkIf (!pkgs.stdenv.isDarwin) {
    wrappedPackage = mkWrappedPackage { withSandboxArgs = false; };
    wrappedPackageWithSandboxArgs = mkWrappedPackage { withSandboxArgs = true; };
  };
}
