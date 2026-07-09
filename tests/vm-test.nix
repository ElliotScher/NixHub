{ nixpkgs, system, inputs, home-manager }:

let
  pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
in
pkgs.testers.nixosTest {
  name = "nixhub-common-smoke-test";

  nodes.machine =
    { ... }:
    {
      _module.args.inputs = inputs;

      imports = [
        ../common/configuration.nix
        home-manager.nixosModules.home-manager
      ];

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";
      home-manager.extraSpecialArgs = { inherit inputs; };
      home-manager.users.elliotscher = import ../home/elliotscher.nix;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("id elliotscher")
    machine.succeed("su - elliotscher -c 'command -v git'")
    machine.wait_for_unit("home-manager-elliotscher.service")
    machine.succeed("test -f /home/elliotscher/.config/git/config")
    machine.wait_for_unit("display-manager.service")
    machine.wait_for_unit("graphical.target")
  '';
}
