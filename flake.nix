{
  description = "openjowelsofts/huenicorn, packaged for usage on Nixos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    openjowelsofts-huenicorn = {
      url = "gitlab:openjowelsofts/huenicorn?ref=26b7794b28dd5d19f976e0a0910509c509ecc9b3";
      flake = false;
    };
    # httplib = {
    #   url = "github:yhirose/cpp-httplib?ref=v0.46.0";
    #   flake = false;
    # };
    # nlohmann_json = {
    #   url = "github:nlohmann/json?tag=v3.12.0";
    #   flake = false;
    # };
    # cpp_httplib = {
    #   url = "github:yhirose/cpp-httplib?tag=v0.46.0";
    #   flake = false;
    # };
    # glm = {
    #   url = "github:g-truc/glm?tag=1.0.3";
    #   flake = false;
    # };
  };

  outputs =
    inputs@{
      flake-utils,
      nixpkgs,
      openjowelsofts-huenicorn,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (import nixpkgs) {
          inherit system;
          # to allow for rust-rover to be installed
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (pkgs.lib.getName pkg) [
              "rust-rover"
            ];
        };
        # httpLib = pkgs.httplib.overrideAttrs (old: {
        #   version = "0.46.0";
        #   src = inputs.cpp_httplib;
        # });
        # nlohmann_json = pkgs.nlohmann_json.overrideAttrs (old: {
        #   version = "v3.12.0";
        #   src = inputs.nlohmann_json;
        # });
        # glm = pkgs.glm.overrideAttrs (old: {
        #   version = "1.0.3";
        #   src = inputs.glm;
        # });

        toCMakeFlag =
          { name, pkg }:
          "-DFETCHCONTENT_SOURCE_DIR_${name}=${pkg}";

        getFetchContentFlags =
          file:
          let
            inherit (builtins) head elemAt match;
            parse = match "(.*)\nFetchContent_Declare\\(\n  ([^\n]*)\n([^)]*)\\).*" file;
            name = elemAt parse 1;
            content = elemAt parse 2;
            getKey =
              key: if (content == null) then [ ] else elemAt (match "(.*\n)?  ${key} ([^\n]*)(\n.*)?" content) 1;
            repo = getKey "GIT_REPOSITORY";
            pkg =
              if (repo == null) then
                pkgs.fetchurl {
                  url = getKey "URL";
                  hash = "";
                }
              else
                pkgs.fetchFromGitHub {
                  owner = head (match ".*github.com/([^/]*)/.*" repo);
                  repo = head (match ".*/([^/]*)\\.git" repo);
                  rev = getKey "GIT_TAG";
                  # hash = getKey "# hash:";
                  hash = "";
                };
          in
          if (parse == null) then
            [ ]
          else
            (
              [ "-DFETCHCONTENT_SOURCE_DIR_${pkgs.lib.toLower name}=${pkg}" ] ++ getFetchContentFlags (head parse)
            );

        # https://gitlab.com/openjowelsofts/huenicorn/-/tree/0c3910ab43a64b87755ab500fbae9378376efb46/#dependencies-intallation
        buildDependencies = with pkgs; [
          cmake
          curl
          gcc
          glib
          glm
          gnumake
          httplib
          libX11
          libXcursor
          libXi
          libXrandr
          mbedtls
          nlohmann_json
          opencv
          pipewire
          pkg-config
        ];

        built = pkgs.stdenv.mkDerivation {
          name = "huenicorn";

          nativeBuildInputs = buildDependencies;

          # cmakeFlags = getFetchContentFlags (builtins.readFile "${openjowelsofts-huenicorn}/CMakeLists.txt");
          cmakeFlags = [ "-DCMAKE_INSTALL_LIBDIR=lib" ];
          # cmakeFlags = builtins.map toCMakeFlag [
          #   {
          #     name = "nlohmann_json";
          #     pkg = pkgs.nlohmann_json;
          #   }
          #   {
          #     name = "cpp_httplib";
          #     pkg = pkgs.httplib;
          #   }
          #   {
          #     name = "glm";
          #     pkg = pkgs.glm;
          #   }
          # ];

          src = openjowelsofts-huenicorn;

          buildPhase = ''
            cp -r $src ./src
            chmod +w src
            mkdir -p ./src/build
            cd ./src/build
            cmake ..
            make
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp huenicorn $out/bin/
          '';
        };
      in
      {
        packages = {
          default = built;
        };

        formatter = pkgs.nixfmt-tree;

        devShells = {
          default = pkgs.mkShell {
            name = "huenicorn build dev shell";

            nativeBuildInputs = [
              # dev environment
              pkgs.jetbrains.clion
              pkgs.nixd
            ]
            ++ buildDependencies;

            shellHook = ''
              cp -r "${openjowelsofts-huenicorn}" ./src;
              chmod +w src
              mkdir -p ./src/build
              cd ./src/build
            '';
          };
        };

        checks = {
          builds-an-executable = pkgs.stdenv.mkDerivation {
            name = "can run php with the extension loaded";

            src = ./.;

            doCheck = true;

            checkPhase = ''
               if [[ -f "${built}/bin/huenicorn" && -r "${built}/bin/huenicorn" && -x "${built}/bin/huenicorn" ]]; then
                 echo "OK" >> $out;
               else
                 echo "KO" >> $out;
                 exit 1;
              fi
            '';
          };
        };
      }
    );
}
