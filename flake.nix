{
  description = "wensimehrp.github.io build flake";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };

  outputs = inputs: {
    devShells = builtins.mapAttrs (system: pkgs: {
      default = pkgs.mkShell {
        buildInputs = [
          pkgs.typst
        ];
      };
    }) inputs.nixpkgs.legacyPackages;
  };
}
