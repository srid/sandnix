{ lib, config, pkgs, name, ... }:
{
  config = {
    wrappedPackage =
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
      in
      (pkgs.writeShellApplication {
        name = name;
        runtimeInputs = [ pkgs.landrun ];
        text = ''
          args=()

          # Add conditional --rox paths
          ${conditionalPathArg "--rox" config.cli.rox}

          # Add conditional --ro paths
          ${conditionalPathArg "--ro" config.cli.ro}

          exec landrun \
            "''${args[@]}" \
            ${staticArgs} \
            ${config.program} "$@"
        '';
      }) // {
        meta = config.meta;
      };
  };
}
