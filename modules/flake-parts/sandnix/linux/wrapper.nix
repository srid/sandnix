{ lib, config, pkgs, ... }:
{
  config = lib.mkIf (!pkgs.stdenv.isDarwin) {
    wrappedPackage = pkgs.writeShellApplication {
      name = config.name;
      runtimeInputs = [ pkgs.landrun ];
      text = ''
        ${config.preHook}

        args=()

        # Add conditional --rox paths
        ${
          lib.concatMapStringsSep "\n"
            (p: ''
              if [ -e "${p}" ]; then
                args+=("--rox" "${p}")
              fi
            '')
            config.cli.rox
        }

        # Add conditional --ro paths
        ${
          lib.concatMapStringsSep "\n"
            (p: ''
              if [ -e "${p}" ]; then
                args+=("--ro" "${p}")
              fi
            '')
            config.cli.ro
        }

        exec landrun \
          "''${args[@]}" \
          ${
            lib.concatStringsSep " \\\n    "
              ([ ]
                ++ (map (p: "--rwx \"${p}\"") config.cli.rwx)
                ++ (map (p: "--rw \"${p}\"") config.cli.rw)
                ++ (map (e: "--env ${e}") config.cli.env)
                ++ (lib.optional config.cli.unrestrictedNetwork "--unrestricted-network")
                ++ (lib.optional config.cli.unrestrictedFilesystem "--unrestricted-filesystem")
                ++ (lib.optional config.cli.addExec "--add-exec")
                ++ config.cli.extraArgs
              )
          } \
          ${config.program} "$@"
      '';
    } // {
      meta = config.meta;
    };

    wrappedPackageWithSandboxArgs =
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
        name = "${config.name}-with-args";
        runtimeInputs = [ pkgs.landrun ];
        text = ''
          ${config.preHook}

          args=()

          # Add conditional --rox paths
          ${conditionalPathArg "--rox" config.cli.rox}

          # Add conditional --ro paths
          ${conditionalPathArg "--ro" config.cli.ro}

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

          if [ "$seen_dash_dash" -eq 0 ]; then
            # If no -- was found, all args go to program
            program_args=("''${sandbox_args[@]}")
            sandbox_args=()
          fi

          exec landrun \
            "''${args[@]}" \
            ${staticArgs} \
            "''${sandbox_args[@]}" \
            ${config.program} "''${program_args[@]}"
        '';
      }) // {
        meta = config.meta;
      };
  };
}
