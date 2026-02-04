{ lib, config, pkgs, name, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;

  # Helper to generate conditional path argument for Linux/landrun
  conditionalPathArg = flag: paths:
    lib.concatMapStringsSep "\n"
      (p: ''
        if [ -e "${p}" ]; then
          args+=("${flag}" "${p}")
        fi
      '')
      paths;

  # Static args for Linux/landrun
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
{
  config = {
    wrappedPackage =
      let
        pkg = pkgs.writeShellApplication {
          name = name;
          runtimeInputs = lib.optional (!isDarwin) pkgs.landrun;
          text =
            if isDarwin then ''
                          PROFILE_FILE=$(mktemp "/tmp/landrun-$USER-XXXXXX.sb")
                          trap 'rm -f "$PROFILE_FILE"' EXIT

                          cat > "$PROFILE_FILE" <<EOF
              (version 1)
              (deny default)
              (allow process-fork)
              (allow signal)

              (import "system.sb")

              ;; Allow broad metadata access for getcwd and traversal
              (allow file-read-metadata)
              (allow file-test-existence)

              ;; Standard system locations (read-only essentials)
              (allow file-read* (subpath "/dev"))
              (allow file-read* (subpath "/private/var/folders"))

              ;; Specifically allow some essentials
              (allow file-read-data (literal "/etc/resolv.conf"))
              (allow file-read-data (literal "/private/etc/resolv.conf"))
              (allow file-read-data (literal "/etc/hosts"))
              (allow file-read-data (literal "/private/etc/hosts"))
              (allow file-read-data (subpath "/etc/ssl"))
              (allow file-read-data (subpath "/private/etc/ssl"))

              ${if config.cli.unrestrictedNetwork then "(allow network*)" else "(deny network*)"}
              ${if config.cli.unrestrictedFilesystem then "(allow file*)" else ""}

              EOF

                          # Isolation of environment variables (like landrun does)
                          # We save allowed variables, unset all, then restore allowed.
                          ALLOWED_VARS=(${lib.concatStringsSep " " (map (e: "\"${e}\"") config.cli.env)})
            
                          # Create a temp file to store allowed env values
                          ENV_STORE=$(mktemp "/tmp/landrun-env-$USER-XXXXXX")
                          trap 'rm -f "$PROFILE_FILE" "$ENV_STORE"' EXIT

                          for var in "''${ALLOWED_VARS[@]}"; do
                             # Check if variable is set
                             if eval "[[ -v $var ]]"; then
                                # Use declare -p to safely serialize variable
                                declare -p "$var" >> "$ENV_STORE"
                             fi
                          done

                          # Clear environment (mostly)
                          # We keep some basic ones that are usually expected
                          KEEP_VARS=("HOME" "USER" "LOGNAME" "PATH" "TERM" "SHELL" "LANG" "LC_ALL" "DISPLAY")
                          for var in $(env | cut -d= -f1); do
                            keep=0
                            for k in "''${KEEP_VARS[@]}"; do [[ "$var" == "$k" ]] && keep=1 && break; done
                            if [[ $keep -eq 0 ]]; then
                              unset "$var"
                            fi
                          done

                          # Restore allowed vars
                          if [ -s "$ENV_STORE" ]; then
                            # shellcheck disable=SC1090
                            source "$ENV_STORE"
                          fi

                          # Function to add paths to SBPL profile
                          add_paths() {
                            local op=$1
                            shift
                            for p in "$@"; do
                              # Expand $HOME and $UID if present in path
                              p_expanded=''${p//\$HOME/$HOME}
                              p_expanded=''${p_expanded//\$UID/$(id -u)}

                              # Make path absolute if it's relative
                              if [[ "$p_expanded" != /* ]]; then
                                p_expanded="$(pwd -P)/$p_expanded"
                              fi

                              if [ -e "$p_expanded" ]; then
                                # Resolve to real path for macOS sandbox
                                p_real=$(perl -e 'use Cwd "abs_path"; print abs_path(shift)' "$p_expanded")
                  
                                case "$op" in
                                  rox)
                                    echo "(allow file-read* (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                                    echo "(allow process-exec (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                                    ;;
                                  ro)
                                    echo "(allow file-read* (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                                    ;;
                                  rw)
                                    echo "(allow file-read* (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                                    echo "(allow file-write* (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                                    ;;
                                  rwx)
                                    echo "(allow file-read* (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                                    echo "(allow file-write* (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                                    echo "(allow process-exec (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                                    ;;
                                esac
                              fi
                            done
                          }

                          # Fix getcwd by allowing traversal of parents
                          # Use physical path for CURR_PATH
                          CURR_PATH="$(pwd -P)"
                          while [ "$CURR_PATH" != "/" ]; do
                            echo "(allow file-read* (literal \"$CURR_PATH\"))" >> "$PROFILE_FILE"
                            CURR_PATH=$(dirname "$CURR_PATH")
                          done

                          ${lib.optionalString config.cli.addExec ''
                            echo "(allow file-read* (literal \"${config.program}\"))" >> "$PROFILE_FILE"
                            echo "(allow process-exec (literal \"${config.program}\"))" >> "$PROFILE_FILE"
                          ''}

                          # shellcheck disable=SC2016
                          ${lib.optionalString (config.cli.rox != []) "add_paths rox ${lib.escapeShellArgs config.cli.rox}\n"}
                          # shellcheck disable=SC2016
                          ${lib.optionalString (config.cli.ro != []) "add_paths ro ${lib.escapeShellArgs config.cli.ro}\n"}
                          # shellcheck disable=SC2016
                          ${lib.optionalString (config.cli.rw != []) "add_paths rw ${lib.escapeShellArgs config.cli.rw}\n"}
                          # shellcheck disable=SC2016
                          ${lib.optionalString (config.cli.rwx != []) "add_paths rwx ${lib.escapeShellArgs config.cli.rwx}\n"}

                          # Set up environment variables
                          ${lib.concatMapStrings (e: "export ${e}\n") config.cli.env}

                          exec sandbox-exec -f "$PROFILE_FILE" ${config.program} "$@"
            '' else ''
              # Linux implementation using landrun
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
        };
      in
      if isDarwin && config.cli.extraArgs != [ ] then
        lib.warn "landrun-nix: extraArgs are ignored on Darwin as sandbox-exec does not support them." pkg
      else
        pkg;
  };
}
