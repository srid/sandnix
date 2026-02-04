{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    landrun-nix.url = "path:../";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      imports = [ inputs.landrun-nix.flakeModule ];

      perSystem = { config, pkgs, ... }:
        let
          testDeps = [ pkgs.bats ] ++ (builtins.attrValues config.packages);
        in
        {
          landrunApps = {
            test-true = {
              program = "${pkgs.coreutils}/bin/true";
            };
            test-ls = {
              program = "${pkgs.coreutils}/bin/ls";
              features.tty = false;
            };
            test-tty = {
              program = "${pkgs.coreutils}/bin/stty";
              features.tty = true;
            };
            test-mktemp = {
              program = "${pkgs.coreutils}/bin/mktemp";
              features.tmp = true;
            };
            test-mktemp-no-tmp = {
              program = "${pkgs.coreutils}/bin/mktemp";
              features.tmp = false;
            };
            test-curl-deny = {
              program = "${pkgs.curl}/bin/curl";
              features.network = false;
            };
            test-curl-allow = {
              program = "${pkgs.curl}/bin/curl";
              features.network = true;
            };
            test-env-var = {
              program = "${pkgs.bash}/bin/bash";
              cli.env = [ "MY_TEST_VAR" ];
            };
            test-read-access = {
              program = "${pkgs.bash}/bin/bash";
              cli.ro = [ "./test_secret" ];
            };
            test-write-access = {
              program = "${pkgs.bash}/bin/bash";
              cli.rw = [ "./test_secret" ];
            };
            test-no-access = {
              program = "${pkgs.bash}/bin/bash";
              # Disable implicit tmp access to prevent unintended read access
              features.tmp = false;
            };
            test-multi-paths = {
              program = "${pkgs.bash}/bin/bash";
              # Disable implicit tmp access to test explicit permissions
              features.tmp = false;
              cli = {
                ro = [ "./ro1" "./ro2" ];
                rw = [ "./rw1" "./rw2" ];
                rox = [ "./rox1" "./rox2" ];
                rwx = [ "./rwx1" "./rwx2" ];
              };
            };
            test-nested-paths = {
              program = "${pkgs.bash}/bin/bash";
              # Disable implicit tmp access to test nested permissions
              features.tmp = false;
              cli = {
                ro = [ "./parent" ];
                rw = [ "./parent/child" ];
              };
            };
            test-multi-env = {
              program = "${pkgs.bash}/bin/bash";
              cli.env = [ "VAR1" "VAR2" ];
            };
            test-special-env = {
              program = "${pkgs.bash}/bin/bash";
              cli.env = [ "SPECIAL_VAR" ];
            };
            test-unrestricted-fs = {
              program = "${pkgs.bash}/bin/bash";
              cli.unrestrictedFilesystem = true;
            };
            test-no-nix-fail = {
              program = "${pkgs.bash}/bin/bash";
              features.nix = false;
            };
            test-no-nix-ldd-ok = {
              program = "${pkgs.bash}/bin/bash";
              features.nix = false;
              cli.extraArgs = [ "--ldd" ];
            };
            test-add-exec-disabled-fail = {
              program = "${pkgs.bash}/bin/bash";
              features.nix = false;
              cli.extraArgs = [ "--ldd" ];
              cli.addExec = false;
            };
            test-add-exec-disabled-ldd-ok =
              let
                bashExe = pkgs.lib.getExe pkgs.bash;
              in
              {
                program = bashExe;
                features.nix = false;
                cli.addExec = false;
                cli.rox = [ bashExe ];
                cli.extraArgs = [ "--ldd" ];
              };
            test-extra-args = {
              program = "${pkgs.bash}/bin/bash";
              # We pass -v (verbose) to landrun via extraArgs
              cli.extraArgs = [ "-v" ];
            };
          };

          devShells.default = pkgs.mkShell {
            packages = testDeps;
          };

          checks.tests = pkgs.runCommand "tests"
            {
              __impure = true;
              nativeBuildInputs =
                [ pkgs.bats ]
                ++ testDeps
                ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.util-linux pkgs.glibc ]
              ;
            } ''
            export HOME=$(realpath ./home)
            mkdir -p $HOME
            mkdir -p $HOME/.cache/nix
            mkdir -p /etc

            export NIX_SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

            # Used to skip some tests which fail in nix sandbox on CI
            export IN_NIX_SANBOX=1

            # Wrap bats in script to fake a TTY, required for test-tty
            ${if pkgs.stdenv.isLinux then ''
              script -qec "bats ${./test.bats}" /dev/null | tee $out
            '' else ''
              bats ${./test.bats} | tee $out
            ''}
          '';
        };
    };
}
