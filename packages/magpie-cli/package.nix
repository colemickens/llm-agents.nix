{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

# Terminal-only magpie (upstream's `magpie-cli` release asset): the gateway,
# TUI and web UI without the desktop app, so no GTK/WebKit in the closure.
# packages/magpie builds the desktop app from the same src and vendorHash.
buildGoModule (finalAttrs: {
  pname = "magpie-cli";
  version = "0.1.4501";

  src = fetchFromGitHub {
    owner = "yetone";
    repo = "magpie";
    tag = "v${finalAttrs.version}";
    hash = "sha256-eZsVl1/pzFR2JchsbbdPSyW+IX1R9mkVsUW8SxrkMT8=";
  };

  vendorHash = "sha256-TgMwl324YTy8l9zlkjK/aAqJafP/m3ZbiLLDl1OrffY=";

  subPackages = [ "." ];

  env.CGO_ENABLED = 0;

  tags = [
    "nogui"
    "packedassets"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
  ];

  # As upstream's release targets do: embed the web UI as one zip, and on
  # macOS build with the runtime overlay that returns freed heap to the OS.
  preBuild = ''
    go run ./build/assetpack internal/gui/assets internal/gui/assets.zip
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    export GOFLAGS="$GOFLAGS $(sh build/darwin/footprint-overlay.sh "$TMPDIR/overlay")"
  '';

  # preBuild is inherited by the vendoring derivation, where it cannot run.
  overrideModAttrs = _: { preBuild = ""; };

  # The test suite drives real agent CLIs, the network and the user's home.
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Local gateway that routes any coding agent to any model provider (terminal-only build)";
    homepage = "https://usemagpie.ai";
    changelog = "https://github.com/yetone/magpie/releases/tag/v${finalAttrs.version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "magpie";
    platforms = platforms.linux ++ platforms.darwin;
  };
})
