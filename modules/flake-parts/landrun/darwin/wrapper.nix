{ lib, config, pkgs, name, ... }:
let
  pkg = pkgs.writeShellApplication {
    name = name;
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      user=''${USER:-nobody}
      PROFILE_FILE=$(mktemp "/tmp/sandbox-profile-$user-XXXXXX.sb")
      trap 'rm -f "$PROFILE_FILE"' EXIT

      cat > "$PROFILE_FILE" <<EOF
      ;; Sandbox Profile Language (SBPL) version 1
      (version 1)

      ;; Default deny policy: Everything is denied unless explicitly allowed
      (deny default)

      ;; Allow forking child processes (essential for shell wrappers and most apps)
      (allow process-fork)

      ;; Allow sending signals to processes
      (allow signal)

      ;; Import standard system profile
      ;; This is required for basic system functionality:
      ;; - Dynamic linker (dyld) operation
      ;; - System frameworks and libraries (libc, libSystem, etc.)
      ;; - Basic kernel interactions (mach lookups, sysctls)
      ;; Without this, almost no binary can execute on macOS.
      (import "system.sb")

      ;; Allow broad metadata access
      ;; 'file-read-metadata' is needed for:
      ;; - 'ls' (directory listing implies metadata read)
      ;; - 'getcwd' path resolution
      ;; - 'realpath' and symlink resolution
      ;; 'file-test-existence' is needed for:
      ;; - Library probing (dyld checking potential paths)
      ;; - Applications checking for optional config files
      ;; Note: This allows seeing *if* files exist, but not reading their content.
      (allow file-read-metadata)
      (allow file-test-existence)

      ;; Standard POSIX device nodes
      ;; Most applications expect these to be available.
      (allow file-read*
        (literal "/dev/null")
        (literal "/dev/zero")
        (literal "/dev/random")
        (literal "/dev/urandom"))

      ${lib.optionalString config.features.tty ''
      ;; Allow PTY ioctls (enabled by features.tty)
      ;; Necessary for interactive applications (stty, shells, REPLs) to control the terminal.
      (allow file-ioctl (regex #"^/dev/ttys[0-9]+"))
      ''}

      ;; Network Access Control
      ;; Based on 'features.network' or 'cli.unrestrictedNetwork'
      ${if config.cli.unrestrictedNetwork then "(allow network*)" else "(deny network*)"}

      ;; Filesystem Access Control
      ;; Based on 'cli.unrestrictedFilesystem'
      ${if config.cli.unrestrictedFilesystem then "(allow file*)" else ""}

      EOF

      # Isolation of environment variables
      # We save allowed variables, unset all, then restore allowed.
      ALLOWED_VARS=(${lib.concatStringsSep " " (map (e: "\"${e}\"") config.cli.env)})

      # Create a temp file to store allowed env values
      ENV_STORE=$(mktemp "/tmp/sandbox-env-$user-XXXXXX")
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
            p_real=$(${lib.getExe pkgs.perl} -e 'use Cwd "abs_path"; print abs_path(shift)' "$p_expanded")

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
                echo "(allow file-ioctl (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                ;;
              rwx)
                echo "(allow file-read* (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                echo "(allow file-write* (subpath \"$p_real\"))" >> "$PROFILE_FILE"
                echo "(allow file-ioctl (subpath \"$p_real\"))" >> "$PROFILE_FILE"
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
    '';
  };
in
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    wrappedPackage =
      if config.cli.extraArgs != [ ] then
        lib.warn "landrun-nix: extraArgs are ignored on Darwin as sandbox-exec does not support them." pkg
      else
        pkg;
  };
}
