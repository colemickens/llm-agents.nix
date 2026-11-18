{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs,
  npmHooks,
  rustPlatform,
  cmake,
  git,
  pkg-config,
  zstd,
  versionCheckHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cliproxy-rs";
  version = "0.4.4";

  src = fetchFromGitHub {
    owner = "vayungodara";
    repo = "cliproxy-rs";
    tag = "v${finalAttrs.version}";
    # Upstream commits the built dashboard; drop it so the embedded copy can
    # only come from the ui/ sources built below.
    postFetch = ''
      rm -r $out/ui/dist $out/ui/dist-panel
    '';
    hash = "sha256-11F//XnpRO0AJdmxRex8Vbd523iJrQd9UvqyCpHtf3M=";
  };

  npmRoot = "ui";
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    src = "${finalAttrs.src}/ui";
    hash = "sha256-wTHSAyxEMcCFUtoDOJ8qASiPOemWo8pIiijA7Do8bKY=";
  };

  cargoHash = "sha256-VUH6AtTAHXhgnEGtRzvOEUf0jXhq63/FMYztJy6a/Jc=";

  cargoBuildFlags = [
    "--package"
    "cliproxy"
  ];
  cargoTestFlags = finalAttrs.cargoBuildFlags;

  # Relies on the process-wide tracing subscriber, which other tests in the
  # same binary race to install; times out in the build sandbox.
  checkFlags = [ "--skip=home::tests::process_log_lines_reach_home_while_published" ];

  nativeBuildInputs = [
    # btls-sys (wreq's TLS stack) compiles its bundled BoringSSL with cmake
    # and generates bindings with bindgen; its build script applies patches
    # to the BoringSSL tree with git.
    cmake
    git
    rustPlatform.bindgenHook
    nodejs
    npmHooks.npmConfigHook
    # nixpkgs' cargoSetupHook sets ZSTD_SYS_USE_PKG_CONFIG, so zstd-sys
    # links the system zstd instead of compiling its vendored copy.
    pkg-config
  ];

  buildInputs = [ zstd ];

  dontUseCmakeConfigure = true;

  # cpa-server's build.rs embeds ui/dist (via the crates/cpa-server/dashboard
  # symlink) into the binary.
  preBuild = ''
    npm --prefix ui run build
  '';

  env = {
    CPA_COMMIT = "v${finalAttrs.version}";
    CPA_BUILD_DATE = "1970-01-01T00:00:00Z";
  };

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Utilities";

  meta = {
    description = "Local proxy exposing DeepSeek, GLM, Kimi, OpenRouter and more to Codex CLI and Claude Code, CLIProxyAPI-compatible";
    homepage = "https://github.com/vayungodara/cliproxy-rs";
    changelog = "https://github.com/vayungodara/cliproxy-rs/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ colemickens ];
    mainProgram = "cliproxy";
    platforms = lib.platforms.unix;
  };
})
