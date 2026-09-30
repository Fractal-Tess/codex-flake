{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "0.159.2";
  sources = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-ni0ppxO5RHiyQN7C8Q4RMkzQX6123EPnxjm9+KEzems=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-BaUkpGPK334+Isf5I1OcDQt0w+eLH18fq1LlDm+zMS8=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${source.target}.tar.gz";
    inherit (source) hash;
  };

  # The package bundle is the layout the standalone installer ships: the codex
  # executable and its code-mode host under bin/, bundled ripgrep and
  # bubblewrap under codex-path/ and codex-resources/, and a codex-package.json
  # manifest at the root. Codex resolves its helpers relative to that manifest,
  # and the app-server daemon behind the interactive CLI refuses to start
  # without it, so the bundle is installed verbatim as the output.
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r bin codex-package.json codex-path codex-resources "$out/"
    runHook postInstall
  '';

  # The executables are statically linked against musl and the voice host
  # carries its own libraries, so the bundle is kept byte-for-byte as shipped.
  dontFixup = true;

  meta = {
    description = "OpenAI's coding agent that runs locally in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
