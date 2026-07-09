{
  description = "System configurations and development environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-cli-nix.url = "github:bigFin/antigravity-cli-nix";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    frc-nix.url = "github:frc4451/frc-nix";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

      hostNames = builtins.attrNames (
        lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ./hosts)
      );

      mkHost = name:
        let
          hostUsers = import ./hosts/${name}/users.nix;
          hostUserHome = user: ./hosts/${name}/home/${user}.nix;
        in
        lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs; };
          modules = [
            ./common/configuration.nix
            { networking.hostName = name; }
            ./hosts/${name}/configuration.nix
            ./hosts/${name}/hardware-configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users = lib.genAttrs hostUsers (user: {
                imports = [ ./users/${user}/home.nix ]
                  ++ lib.optional (builtins.pathExists (hostUserHome user)) (hostUserHome user);
              });
            }
          ] ++ map (user: ./users/${user}/account.nix) hostUsers;
        };
    in
    {
      nixosConfigurations = lib.genAttrs hostNames mkHost;

      packages.${system}.bootstrap = pkgs.writeShellApplication {
        name = "bootstrap";
        runtimeInputs = [ pkgs.git pkgs.nixos-install-tools ];
        text = builtins.readFile ./bootstrap.sh;
      };

      apps.${system} = {
        bootstrap = {
          type = "app";
          program = "${self.packages.${system}.bootstrap}/bin/bootstrap";
          meta.description = "Set up a new machine: clone NixHub, assign the next hostname, generate hardware config, and scaffold the host";
        };
        default = self.apps.${system}.bootstrap;
      };

      checks.${system} =
        # Full system closure for every host - catches build failures that
        # plain evaluation won't (e.g. a package that fails to build).
        (lib.listToAttrs (
          map (
            name:
            lib.nameValuePair "system-${name}" self.nixosConfigurations.${name}.config.system.build.toplevel
          ) hostNames
        ))
        // {
          # Pure, sandboxable test of bootstrap.sh's hostname-picking logic.
          pick-hostname-logic = pkgs.runCommand "pick-hostname-tests" { } ''
            cp ${./scripts/pick-hostname.sh} pick-hostname.sh
            cp ${./scripts/test-pick-hostname.sh} test-pick-hostname.sh
            ${pkgs.bash}/bin/bash test-pick-hostname.sh
            touch $out
          '';

          # NixOS VM smoke test of the shared config (common/ + home-manager),
          # independent of any single host's real hardware.
          vm-smoke-test = import ./tests/vm-test.nix { inherit nixpkgs system inputs home-manager; };
        };
    };
}
