{
  description = "Development shell for operating Talos clusters";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              age
              jq
              kubectl
              sops
              talhelper
              talosctl
              yq-go
            ];

            shellHook = ''
              export MISTSHIP_SECRETS_DIR="''${MISTSHIP_SECRETS_DIR:-$HOME/secure/mistship}"
              export TALOSCONFIG="''${TALOSCONFIG:-$MISTSHIP_SECRETS_DIR/talosconfig}"
              export KUBECONFIG="''${KUBECONFIG:-$MISTSHIP_SECRETS_DIR/kubeconfig}"

              echo "mistship Talos shell"
              echo "  MISTSHIP_SECRETS_DIR=$MISTSHIP_SECRETS_DIR"
              echo "  TALOSCONFIG=$TALOSCONFIG"
              echo "  KUBECONFIG=$KUBECONFIG"
            '';
          };
        });

      formatter = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.nixpkgs-fmt);
    };
}
