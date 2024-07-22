{
  description = "vcard2org-contacts.py -- Translate vcards into org-contact format.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    mach-nix.url = "github:DavHau/mach-nix";
  };

  outputs = { self, nixpkgs, flake-utils, mach-nix, ... }@inputs:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          requirements-txt = "${self}/requirements.txt";
          requirements-as-text = builtins.readFile requirements-txt;

          # python environment
          mypython =
              mach-nix.lib."${system}".mkPython {
                requirements = builtins.readFile requirements-txt;
              };

          mydevpython =
              mach-nix.lib."${system}".mkPython {
                requirements = requirements-as-text +  ''
pip
python-lsp-server[all]
rich-cli
mypy
'';
              };


          # Utility to run a script easily in the flakes app
          simple_script = name: add_deps: text: let
            exec = pkgs.writeShellApplication {
              inherit name text;
              runtimeInputs = with pkgs; [
                mypython
              ] ++ add_deps;
            };
          in {
            type = "app";
            program = "${exec}/bin/${name}";
          };

          # the python script to wrap as an app
          script-base-name = "vcard2org-contacts";
          script-name = "${script-base-name}.py";
          pyscript = "${self}/${script-name}";

          # package settings
          package-version = "1.0";
          package-name = "${script-base-name}-${package-version}";

        in with pkgs;
          {
            ###################################################################
            #                       package                                   #
            ###################################################################
            packages = {
              currency-exchange = stdenv.mkDerivation {
                name= "${package-name}";
                src = ./.;

                runtimeInputs = [ mypython ];
                buildInputs = [ mypython ];
                nativeBuildInputs = [ makeWrapper ];
                installPhase = ''
                  mkdir -p $out/bin/
                  mkdir -p $out/share/
                  cp ${pyscript} $out/share/${script-name}
                  makeWrapper ${mypython}/bin/python $out/bin/${script-base-name} --add-flags "$out/share/${script-name}"
                '';
              };
            };
            ###################################################################
            #                       running                                   #
            ###################################################################
            apps = {
              default = simple_script "pyscript" [] ''
                ${mypython}/bin/python ${pyscript} "''$@"
              '';
            };

            ###################################################################
            #                       development shell                         #
            ###################################################################
            devShells.default = mkShell
              {
                buildInputs = [
                  mydevpython
                ];
                runtimeInputs = [ mydevpython ];
                shellHook = ''
          rich "[b white on black]Using virtual environment for [/][b white on red] ${package-name} [/][b white on black] with Python[/]

[b]$(python --version)[/]

[b white on black]with packages[/]

$(${mydevpython}/bin/pip list --no-color --disable-pip-version-check)" --print --padding 1 -p -a heavy
                '';
              };
          }
      );
}
