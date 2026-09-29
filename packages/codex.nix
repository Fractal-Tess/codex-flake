{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  ripgrep,
  bubblewrap,
}:

let
  version = "0.159.1";
  sources = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-R6+LtBsA6vOoCcJ9X4NXdAkQNzpqXe21T57nSM7daFE=";
      codeModeHostHash = "sha256-O4ZEvbOdvu0atVKTZy3Q/OHzuPvdkXUwjXRotK8NVLw=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-hOe+fFjvm24WCdnF8UqOklBvvydtw1x2qPEh6DYgr5U=";
      codeModeHostHash = "sha256-qpa37Nxp5oiemnRWX1NEtoeDyD2k/MPcnaqsKP2Omwg=";
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
