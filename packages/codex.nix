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
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-6YwejgKOgTf6LSQVyC7Fjns3AaYn41VKrOWzyjFFSvI=";
      codeModeHostHash = "sha256-NRb5uLvmvAbue9uSspOhfqsZSz8QubnqEMW4Oely1/w=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-TGscF8HF/Q1PspUbdIGGe5Xqcysf6rJpyYWIsV2xYlM=";
      codeModeHostHash = "sha256-6DdCgG2pjpp3rSQwnr0WKegid1WjQa0LQo+IXJe7MY4=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
  releaseAsset =
    name: hash:
    fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/${name}-${source.target}.tar.gz";
      inherit hash;
    };
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  srcs = [
    (releaseAsset "codex" source.hash)
    # Code mode, which image generation runs through, spawns this helper from
    # the directory holding the codex executable and fails closed without it.
    (releaseAsset "codex-code-mode-host" source.codeModeHostHash)
  ];

  nativeBuildInputs = [ makeWrapper ];

  # Each tarball holds a single binary named after the target triple, and the
  # binaries are statically linked against musl, so there is nothing to patch;
  # installing and wrapping them is enough.
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 "codex-${source.target}" "$out/bin/codex"
    install -Dm755 "codex-code-mode-host-${source.target}" "$out/bin/codex-code-mode-host"
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
