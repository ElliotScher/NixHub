{
  inputs = {
    # ... other inputs
    globalprotect-openconnect.url = "github:yuezk/GlobalProtect-openconnect";
  };

  outputs = { self, nixpkgs, globalprotect-openconnect, ... }:
    let
      system = "x86_64-linux"; # or "aarch64-linux" for ARM64
      hostname = "<your-host>";
    in {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ./configuration.nix
          {
            services.ayatana-indicators.enable = true;

            environment.systemPackages = [
              globalprotect-openconnect.packages.${system}.default
              nixpkgs.legacyPackages.${system}.gnomeExtensions.appindicator
            ];
          }
        ];
      };
    };
}
