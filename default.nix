{
  cctools,
  fetchPnpmDeps,
  lib,
  makeWrapper,
  nodejs_26,
  pnpm_10,
  pnpmBuildHook,
  pnpmConfigHook,
  python3,
  stdenv,
}:
let
  # We need the full nodejs package because we run `npm` to build.
  nodejs = nodejs_26;
  pnpm = pnpm_10.override { nodejs-slim = nodejs; };
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  pname = "chiasmus";
  version = "0.1.26";
  src = ./.;

  env.npm_config_nodedir = nodejs.outPath;

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    pnpmBuildHook
    python3 # for node-gyp (better-sqlite3 native build)
    makeWrapper
  ]
  # Provides libtool for Darwin, which is needed to build better-sqlite3's native addon.
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ cctools.libtool ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-AX2/rKAwgabk4xNQTAmjCfk8dVKAiN7zLYxtulEXDqg=";
  };

  # pnpmConfigHook installs with --ignore-scripts, and the sandbox
  # blocks better-sqlite3's prebuild-install download, so its native
  # addon is never produced. Compile it from source against the local
  # node headers.
  preBuild = ''
    pushd node_modules/.pnpm/better-sqlite3@*/node_modules/better-sqlite3
    "${lib.getExe' nodejs "npm"}" run build-release
    popd
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/chiasmus"
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
