{
  lib,
  fetchFromGitHub,
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
    hash = "sha256-pIm403jrG5r+WF+36F/bTt3ZijdQVm3XlkLcWTtDOGQ=";
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
    # nixpkgs' cargoSetupHook sets ZSTD_SYS_USE_PKG_CONFIG, so zstd-sys
    # links the system zstd instead of compiling its vendored copy.
    pkg-config
  ];

  buildInputs = [ zstd ];

  dontUseCmakeConfigure = true;

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
