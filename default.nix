{
  fetchPnpmDeps,
  lib,
  makeWrapper,
  nodejs,
  pnpm,
  pnpmBuildHook,
  pnpmConfigHook,
  python3,
  stdenv,
}:
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  pname = "chiasmus";
  version = "0.1.26";
  src = ./.;

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    pnpmBuildHook
    python3 # for node-gyp (better-sqlite3 native build)
    makeWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-p6MW2LpBnkw/KhKoHXKXozI/PRUPpblUl8wrUVos7Dw=";
  };

  # pnpmConfigHook installs with --ignore-scripts, and the sandbox
  # blocks better-sqlite3's prebuild-install download, so its native
  # addon is never produced. Compile it from source against the local
  # node headers.
  preBuild = ''
    export npm_config_nodedir=${nodejs}
    pushd node_modules/.pnpm/better-sqlite3@*/node_modules/better-sqlite3
    "${lib.getExe' nodejs "npm"}" run build-release
    popd
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/chiasmus
    cp -r dist node_modules package.json "$out/lib/chiasmus"/
    makeWrapper "${lib.getExe' nodejs "node"}" "$out/bin/chiasmus" \
      --add-flags "$out/lib/chiasmus/dist/mcp-server.js"
    runHook postInstall
  '';

  meta = {
    description = "MCP server for Z3/Prolog formal verification";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
})
