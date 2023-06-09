{
  description = "Example nixified monorepo";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    n2c.url = "github:nlewo/nix2container";
  };

  outputs = inputs@{ self, nixpkgs, n2c, flake-parts, dream2nix }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      # Add additional systems to make output for here
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
      imports = [ dream2nix.flakeModuleBeta ];
      perSystem = {inputs', self', pkgs, config, system, ...}: {

        # define an input for dream2nix to generate outputs for
        dream2nix = {
          inputs."self" = {
            source = inputs.self;
            packageOverrides = {
              tridev-nix = {
                method.installMethod = "symlink";
                add-yarn.nativeBuildInputs = [
                  # Yarn needed to be available in the nix sandbox for lerna to use
                  pkgs.yarn
                ];
              };
              pkg1.method.installMethod = "symlink";
              pkg2.method.installMethod = "symlink";
            };
          };
        };
        devShells = config.dream2nix.outputs.self.devShells;
        # Take theh outputs of dream2nix, and // add some more (meaning add sets {} in nix-lang)
        packages = config.dream2nix.outputs.self.packages // {
          oci-image-tridev-nix = inputs.n2c.packages.${system}.nix2container.buildImage {
            name = "oci-image-tridev-nix";
            config = {
              entrypoint = [
                "${pkgs.nodejs}/bin/nodejs"
                "${self'.packages.pkg2}/lib/node_modules/pkg2/index.js"
              ];
            };
            # Just add some packages to /bin of the image, including the Rust program
            copyToRoot = pkgs.buildEnv {
              name = "root";
              paths = [ pkgs.bashInteractive self'.packages.backend ];
              pathsToLink = [ "/bin" ];
            };

          };
        };
      };
    };
}
