{
  description = "Dart compiled with Zig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default-linux";
    flake-utils.url = "github:numtide/flake-utils";
    zig = {
      url = "github:ziglang/zig?ref=pull/20511/head";
      flake = false;
    };
    zon2nix = {
      url = "github:MidstallSoftware/zon2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      flake-utils,
      zon2nix,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      defaultOverlay =
        pkgs: prev: with pkgs; {
          zig =
            (prev.zig.overrideAttrs (
              finalAttrs: p: {
                version = "0.14.0-git+${inputs.zig.shortRev or "dirty"}";
                src = inputs.zig;

                doInstallCheck = false;

                postBuild = "";
                postInstall = "";

                outputs = [ "out" ];
              }
            )).override
              {
                llvmPackages = llvmPackages_19;
              };

          dart-zig = stdenv.mkDerivation (finalAttrs: {
            pname = "dart-zig";
            version = self.shortRev or "dirty";

            dartVersion = "3.7.0-204.0.dev";
            dartChannel = "dev";

            dart = dart.override {
              version = finalAttrs.dartVersion;
              sources = {
                "${finalAttrs.dartVersion}-x86_64-linux" = fetchzip {
                  url = "https://storage.googleapis.com/dart-archive/channels/${finalAttrs.dartChannel}/release/${finalAttrs.dartVersion}/sdk/dartsdk-linux-x64-release.zip";
                  sha256 = finalAttrs.passthru.dartHash.x86_64-linux;
                };
                "${finalAttrs.dartVersion}-aarch64-linux" = fetchzip {
                  url = "https://storage.googleapis.com/dart-archive/channels/${finalAttrs.dartChannel}/release/${finalAttrs.dartVersion}/sdk/dartsdk-linux-arm64-release.zip";
                  sha256 = finalAttrs.passthru.dartHash.aarch64-linux;
                };
                "${finalAttrs.dartVersion}-x86_64-darwin" = fetchzip {
                  url = "https://storage.googleapis.com/dart-archive/channels/${finalAttrs.dartChannel}/release/${finalAttrs.dartVersion}/sdk/dartsdk-macos-x64-release.zip";
                  sha256 = finalAttrs.passthru.dartHash.x86_64-darwin;
                };
                "${finalAttrs.dartVersion}-aarch64-darwin" = fetchzip {
                  url = "https://storage.googleapis.com/dart-archive/channels/${finalAttrs.dartChannel}/release/${finalAttrs.dartVersion}/sdk/dartsdk-macos-arm64-release.zip";
                  sha256 = finalAttrs.passthru.dartHash.aarch64-darwin;
                };
              };
            };

            src = lib.cleanSource self;

            nativeBuildInputs = [
              pkgs.zig
              pkgs.zig.hook
              finalAttrs.dart
            ];

            postPatch = ''
              ln -s ${callPackage ./deps.nix { }} $ZIG_GLOBAL_CACHE_DIR/p
            '';

            postInstall = ''
              patchelf --set-rpath $out/lib $out/bin/*
            '';

            passthru.dartHash = {
              aarch64-linux = "sha256-u/LyW0Ti4SL6lUnrbAhZmm8GxpgliBhchjQMtBVehXI=";
              aarch64-darwin = lib.fakeHash;
              x86_64-linux = lib.fakeHash;
              x86_64-darwin = lib.fakeHash;
            };
          });

          zon2nix = stdenv.mkDerivation {
            pname = "zon2nix";
            version = "0.1.2";

            src = lib.cleanSource inputs.zon2nix;

            nativeBuildInputs = [
              pkgs.zig
              pkgs.zig.hook
            ];

            zigBuildFlags = [
              "-Dnix=${lib.getExe nix}"
            ];

            zigCheckFlags = [
              "-Dnix=${lib.getExe nix}"
            ];
          };
        };
    in
    flake-utils.lib.eachSystem (import systems) (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
          defaultOverlay
        ];
      in
      {
        packages = {
          default = pkgs.dart-zig;
        };

        devShells = {
          default = pkgs.dart-zig.overrideAttrs (
            finalAttrs: p: {
              nativeBuildInputs = p.nativeBuildInputs ++ [
                pkgs.zon2nix
              ];
            }
          );
        };

        legacyPackages = pkgs;
      }
    )
    // {
      overlays = {
        default = defaultOverlay;
        dart-zig = defaultOverlay;
      };
    };
}
