{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  patchelf,
  bintools,
  binutils,

  # Runtime deps (same set as google-chrome)
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  bzip2,
  cairo,
  coreutils,
  cups,
  curl,
  dbus,
  expat,
  flac,
  fontconfig,
  freetype,
  gcc-unwrapped,
  gdk-pixbuf,
  glib,
  harfbuzz,
  icu,
  libcap,
  libdrm,
  liberation_ttf,
  libexif,
  libglvnd,
  libkrb5,
  libpng,
  libX11,
  libxcb,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libxkbcommon,
  libXrandr,
  libXrender,
  libXScrnSaver,
  libxshmfence,
  libXtst,
  libgbm,
  nspr,
  nss,
  libopus,
  pango,
  pciutils,
  pipewire,
  snappy,
  speechd-minimal,
  systemd,
  util-linux,
  vulkan-loader,
  wayland,
  wget,
  libpulseaudio,
  libva,
  gtk3,
  gtk4,
  xdg-utils,
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  addDriverRunpath,

  commandLineArgs ? "",
}:

let
  version = "25.12.1.1217-1";
  opusWithCustomModes = libopus.override { withCustomModes = true; };

  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    bzip2
    cairo
    coreutils
    cups
    curl
    dbus
    expat
    flac
    fontconfig
    freetype
    gcc-unwrapped.lib
    gdk-pixbuf
    glib
    harfbuzz
    icu
    libcap
    libdrm
    liberation_ttf
    libexif
    libglvnd
    libkrb5
    libpng
    libX11
    libxcb
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libxkbcommon
    libXrandr
    libXrender
    libXScrnSaver
    libxshmfence
    libXtst
    libgbm
    nspr
    nss
    opusWithCustomModes
    pango
    pciutils
    pipewire
    snappy
    speechd-minimal
    systemd
    util-linux
    vulkan-loader
    wayland
    wget
    libpulseaudio
    libva
    gtk3
    gtk4
  ];

  rpath = lib.makeLibraryPath deps + ":" + lib.makeSearchPathOutput "lib" "lib64" deps;
  binpath = lib.makeBinPath deps;

in
stdenvNoCC.mkDerivation {
  pname = "yandex-browser-stable";
  inherit version;

  src = fetchurl {
    url = "http://repo.yandex.ru/yandex-browser/deb/pool/main/y/yandex-browser-stable/yandex-browser-stable_${version}_amd64.deb";
    hash = "sha256-qNy6vbZDsyiXKNCiaigSoYRnmR7BCCrf9tkunOWbfO0=";
  };

  nativeBuildInputs = [ makeWrapper patchelf binutils ];

  buildInputs = [
    adwaita-icon-theme
    glib
    gtk3
    gtk4
    gsettings-desktop-schemas
  ];

  unpackPhase = ''
    ar x $src
    tar xf data.tar.xz
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share

    cp -a opt/* $out/share/
    cp -a usr/share/* $out/share/

    # The browser lives under $out/share/yandex/browser/
    local browserDir="$out/share/yandex/browser"
    local exe="$out/bin/yandex-browser-stable"

    # Patch ELF binaries
    for elf in $browserDir/{yandex_browser,yandex_browser-sandbox,chrome_crashpad_handler,chrome-management-service,find_ffmpeg,update_codecs,user_setup}; do
      if [ -f "$elf" ]; then
        patchelf --set-rpath ${rpath} "$elf"
        patchelf --set-interpreter ${bintools.dynamicLinker} "$elf"
      fi
    done

    # Patch ANGLE/GL libraries
    for lib in $browserDir/lib*GL*; do
      if [ -f "$lib" ]; then
        patchelf --set-rpath ${rpath} "$lib"
      fi
    done

    # Replace bundled libvulkan with symlink to nixpkgs version
    rm -f $browserDir/libvulkan.so.1
    ln -s "${lib.getLib vulkan-loader}/lib/libvulkan.so.1" "$browserDir/libvulkan.so.1"

    # Fix wrapper script — prevent upstream script from conflicting with Nix makeWrapper
    substituteInPlace $browserDir/yandex-browser \
      --replace-quiet 'CHROME_WRAPPER' 'WRAPPER'

    # Fix desktop files
    for f in $out/share/applications/*.desktop; do
      substituteInPlace "$f" \
        --replace-quiet /usr/bin/yandex-browser-stable "$exe" \
        --replace-quiet /usr/bin/yandex-browser "$exe"
    done

    # Fix GNOME default apps XML if present
    for f in $out/share/gnome-control-center/default-apps/*.xml; do
      if [ -f "$f" ]; then
        substituteInPlace "$f" \
          --replace-quiet /opt/yandex/browser/yandex-browser "$exe"
      fi
    done

    # Install icons into hicolor theme
    for icon_file in $browserDir/product_logo_[0-9]*.png; do
      num_and_suffix="''${icon_file##*logo_}"
      icon_size="''${num_and_suffix%.*}"
      logo_output_path="$out/share/icons/hicolor/''${icon_size}x''${icon_size}/apps"
      mkdir -p "$logo_output_path"
      mv "$icon_file" "$logo_output_path/yandex-browser.png"
    done

    # Create the wrapper
    makeWrapper "$browserDir/yandex-browser" "$exe" \
      --prefix LD_LIBRARY_PATH : "${rpath}" \
      --prefix PATH            : "${binpath}" \
      --suffix PATH            : "${lib.makeBinPath [ xdg-utils ]}" \
      --prefix XDG_DATA_DIRS   : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH:${addDriverRunpath.driverLink}/share" \
      --set CHROME_WRAPPER  "yandex-browser-stable" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --add-flags "--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'" \
      --add-flags ${lib.escapeShellArg commandLineArgs}

    # Convenience symlink
    ln -s $out/bin/yandex-browser-stable $out/bin/yandex-browser

    runHook postInstall
  '';

  meta = with lib; {
    description = "Yandex Browser — a fast and secure web browser";
    homepage = "https://browser.yandex.ru/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "yandex-browser-stable";
  };
}
