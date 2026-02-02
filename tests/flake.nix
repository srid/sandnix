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
            };
          };

          devShells.default = pkgs.mkShell {
            packages = testDeps;
          };

          checks.tests = pkgs.runCommand "tests"
            {
              __impure = true;
              nativeBuildInputs = [ pkgs.bats ] ++ testDeps;
            } ''
            export HOME=home
            mkdir -p $HOME
            mkdir -p $HOME/.cache/nix

            export NIX_SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

            bats ${./test.bats} > $out
          '';
        };
    };
}
