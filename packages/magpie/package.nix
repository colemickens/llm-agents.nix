{
  lib,
  stdenv,
  buildGoModule,
  magpie-cli,
  pkg-config,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  glib-networking,
  xdg-utils,
  desktop-file-utils,
  versionCheckHook,
}:

# The desktop app (menu bar / tray plus every `magpie` CLI command). It is a
# superset of magpie-cli, which exists for hosts that should not pull in
# GTK/WebKit. Version, src and vendorHash are pinned once, in magpie-cli.
buildGoModule (finalAttrs: {
  pname = "magpie";
  inherit (magpie-cli) version src vendorHash;

  subPackages = [ "." ];

  # Linux: GTK 3 + WebKitGTK 4.1, as upstream's release builds (Wails'
  # default would be GTK 4 + WebKitGTK 6).
  tags = [
    "production"
    "packedassets"
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ "gtk3" ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
  ];

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gtk3
    webkitgtk_4_1
    glib-networking
  ];

  # Go's objects target macOS 11 and the linker takes its target from them,
  # while cgo objects and nixpkgs' libraries target the stdenv's minimum.
  env = lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    CGO_LDFLAGS = "-mmacosx-version-min=${stdenv.hostPlatform.darwinMinVersion}";
  };

  postPatch = lib.optionalString stdenv.hostPlatform.isLinux ''
    # The app writes a user desktop entry (magpie:// handler) pointing at its
    # own executable; point it at the wrapper, not .magpie-wrapped.
    substituteInPlace internal/gui/scheme_linux.go \
      --replace-fail 'exe, err := os.Executable()' 'exe, err := "${placeholder "out"}/bin/magpie", error(nil)'
  '';

  preBuild = ''
    go run ./build/assetpack internal/gui/assets internal/gui/assets.zip
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    export GOFLAGS="$GOFLAGS $(sh build/darwin/footprint-overlay.sh "$TMPDIR/overlay")"
  '';

  # Same name and hash as magpie-cli's vendored modules, so they are fetched
  # once; preBuild cannot run in the vendoring derivation.
  overrideModAttrs = _: {
    inherit (magpie-cli.goModules) name;
    preBuild = "";
  };

  # The test suite drives real agent CLIs, the network and the user's home.
  doCheck = false;

  postInstall =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      # Upstream's `make app`: a menu bar app with no Dock icon.
      app=$out/Applications/magpie.app
      mkdir -p $app/Contents/MacOS $app/Contents/Resources
      mv $out/bin/magpie $app/Contents/MacOS/magpie
      install -m444 -t $app/Contents/Resources \
        build/darwin/magpie.icns build/darwin/Assets.car THIRD_PARTY_NOTICES
      # Upstream's 12.0 minimum does not hold for a nixpkgs build.
      sed -e 's/@VERSION@/${finalAttrs.version}/' \
        -e '/LSMinimumSystemVersion/s/12\.0/${stdenv.hostPlatform.darwinMinVersion}/' \
        build/darwin/Info.plist > $app/Contents/Info.plist
      grep -qF '<string>${stdenv.hostPlatform.darwinMinVersion}</string>' $app/Contents/Info.plist
      ln -s ../Applications/magpie.app/Contents/MacOS/magpie $out/bin/magpie
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      install -Dm444 internal/gui/icon-256.png $out/share/icons/hicolor/256x256/apps/magpie.png
      install -Dm444 /dev/stdin $out/share/applications/magpie.desktop <<EOF
      [Desktop Entry]
      Type=Application
      Name=magpie
      Comment=Every agent's model. One place.
      Exec=magpie %u
      Icon=magpie
      StartupWMClass=magpie
      Categories=Development;Utility;
      MimeType=x-scheme-handler/magpie;
      Terminal=false
      EOF
    '';

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    gappsWrapperArgs+=(
      --suffix PATH : ${
        lib.makeBinPath [
          xdg-utils
          desktop-file-utils
        ]
      }
    )
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Utilities";
  # Bumped together with magpie-cli, which owns the version and hashes.
  passthru.skipUpdate = true;

  meta = with lib; {
    description = "Local gateway that routes any coding agent to any model provider, as a menu bar app";
    homepage = "https://usemagpie.ai";
    changelog = "https://github.com/yetone/magpie/releases/tag/v${finalAttrs.version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "magpie";
    platforms = platforms.linux ++ platforms.darwin;
  };
})
