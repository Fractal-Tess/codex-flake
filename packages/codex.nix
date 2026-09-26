{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  ripgrep,
  bubblewrap,
}:

let
  version = "0.157.1";
  sources = {
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-musl.tar.gz";
      binary = "codex-x86_64-unknown-linux-musl";
      hash = "sha256-6YwejgKOgTf6LSQVyC7Fjns3AaYn41VKrOWzyjFFSvI=";
    };
    aarch64-linux = {
      asset = "codex-aarch64-unknown-linux-musl.tar.gz";
      binary = "codex-aarch64-unknown-linux-musl";
      hash = "sha256-TGscF8HF/Q1PspUbdIGGe5Xqcysf6rJpyYWIsV2xYlM=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/${source.asset}";
    inherit (source) hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  # The tarball holds a single binary named after the target triple, and the
  # binary is statically linked against musl, so there is nothing to patch;
  # installing and wrapping it is enough.
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 "${source.binary}" "$out/bin/codex"
    runHook postInstall
  '';

  # Codex shells out to ripgrep for search and to bubblewrap for its Linux
  # sandbox, so both are supplied declaratively rather than left to the host.
  postFixup = ''
    wrapProgram "$out/bin/codex" \
      --prefix PATH : ${
        lib.makeBinPath [
          ripgrep
          bubblewrap
        ]
      }
  '';

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
